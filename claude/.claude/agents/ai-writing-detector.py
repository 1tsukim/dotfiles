#!/usr/bin/env python3
"""AI 臭検出エンジン (日本語ビジネス文書向け / 依存ゼロ・stdlib のみ)

`avoid-ai-writing` (conorbronsdon/avoid-ai-writing, MIT) の `detector/patterns.js`
を日本語向けに移植した決定論エンジン。`ai-writing-auditor` agent が LLM 判断に入る
前の「決定論的プレパス」として使う。

── スリム設計 (敵対的レビューを受けた方針) ──
機械が本当に強いのは「LLM が"文脈で許容"と合理化して見逃しがちな客観的証拠」を
確実に押さえること。曖昧な語彙判定は LLM に任せる。したがって:

- **中核 = 客観 P0 検出 (権威)**: AI ツール指紋 (utm_source 等)・引用マークアップ漏れ・
  未置換プレースホルダ・cutoff disclaimer・チャットボット痕跡。ほぼ FP ゼロ・高深刻度。
- **語彙リコール = P2 助言 (候補列挙)**: vocab.md の Tier1/2/テンプレ/冗長/語尾。
  最終判断は LLM。誤検知を抑えるため (a) script 境界マッチで部分文字列 FP を防ぎ
  (「ミッション」を「パーミッション」内で拾わない)、(b) vocab の「備考」列 (技術文脈は
  許容 等) を issue に添えて LLM が除外判断できるようにする。
- **削除した機能**: 接尾辞密度 (性/化/的) と文長均一さ (uniformity)。日本語での誤検知率が
  高く、経験的な校正根拠を欠くため。ユーザー原則「統計的・経験的根拠を持つパターンのみ採用」
  に反する。

語彙の単一情報源は vocab.md。表に 1 行足すだけでエンジンにも反映される。
type ↔ セクション対応は末尾 `CATEGORY_MAP` を参照 (ドリフト防止契約。test で検証)。

使い方:
    python3 ai-writing-detector.py <file>          # JSON を stdout へ
    python3 ai-writing-detector.py --pretty <file> # 人間可読サマリ
    cat draft.md | python3 ai-writing-detector.py   # stdin
    from ai_writing_detector import analyze; analyze(text)  # import
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

VOCAB_FILENAME = "ai-writing-auditor.vocab.md"

# ── カテゴリ別スコア重み ──
# 客観 P0 を重く、曖昧な語彙リコールは軽く (助言)。
ISSUE_WEIGHTS = {
    # 客観 P0 (権威)
    "ai-fingerprint": 12,
    "cutoff-disclaimer": 10,
    "chatbot": 8,
    "unfilled-placeholder": 6,
    # 準客観 (フォーマット)
    "template": 4,
    "em-dash": 4,
    "header-emoji": 3,
    # 語彙リコール (P2 助言)
    "tier1": 2,
    "tier2": 2,
    "redundant": 2,
    "sentence-ending": 1,
    "bold-overuse": 2,
    "bullet-overuse": 2,
}

SEVERITY = {
    "ai-fingerprint": "P0",
    "cutoff-disclaimer": "P0",
    "chatbot": "P0",
    "unfilled-placeholder": "P0",
    "template": "P1",
    "em-dash": "P1",
    "header-emoji": "P1",
    "tier1": "P2",
    "tier2": "P2",
    "redundant": "P2",
    "sentence-ending": "P2",
    "bold-overuse": "P2",
    "bullet-overuse": "P2",
}

# vocab.md 見出し (em dash に依存しない安定トークンで部分一致) → (type, 備考列 index or None)
# 備考列がある表は last col を note として拾う。
VOCAB_SECTIONS = [
    ("カタカナ・バズワード", "tier1", -1),
    ("抽象動詞・形容詞", "tier1", -1),
    ("冒頭", "template", None),
    ("締め", "template", None),
    ("強調", "template", None),
    ("誘導", "template", None),
    ("Tier 2", "tier2", -1),
    ("主観評価が入る語", "tier2", -1),
    ("冗長表現", "redundant", None),
    ("文末の癖", "sentence-ending", None),
]

# 語彙表のヘッダ行 (1 列目) を除外
VOCAB_HEADER_CELLS = {"単語", "パターン", "冗長", "癖", "語句"}

# ── 客観 P0 (言語非依存 / vocab 外内蔵。存在自体が痕跡) ──
FINGERPRINT_RE = re.compile(
    r"utm_source=(?:chatgpt\.com|openai(?:\.com)?|chat\.openai|claude\.ai|"
    r"copilot(?:\.microsoft)?\.com|perplexity\.ai|gemini(?:\.google)?)"
    r"|referrer=grok\.com"
    r"|citeturn\d|:?contentReference|oaicite|\[oai_citation",
    re.IGNORECASE,
)
PLACEHOLDER_RE = re.compile(
    r"\[(?:ここに|挿入|記入|入力|あなたの|氏名|会社名|担当者名|日付|URL|"
    r"INSERT|YOUR|ADD|ENTER|DESCRIBE|SPECIFY|TODO|TBD)[^\]]*\]"
    r"|20XX年|〇〇年〇〇月|\d{4}-XX-XX",
    re.IGNORECASE,
)
CUTOFF_PATTERNS = [
    "私の知識は", "最新の情報にアクセス", "トレーニングデータ", "学習データに基づ",
    "学習データの範囲", "リアルタイムの情報を持", "リアルタイムのデータにアクセス",
    "現時点の情報では",
]
CHATBOT_PATTERNS = [
    "お役に立てれば幸いです", "お気軽にご相談ください", "何なりとお申し付けください",
    "何かご不明な点がございましたら", "もちろんです！", "承知いたしました！",
    "喜んでお手伝いします",
]

EMOJI_RE = re.compile(
    r"[\U0001F000-\U0001FAFF\U00002600-\U000027BF\U0001F1E6-\U0001F1FF❤⭐✅❌]"
)

# script 判定用の文字クラス
_KATA = r"ァ-ヶーｦ-ﾟ"
_KANJI = r"一-龥々〆ヵヶ"
_LATIN = r"A-Za-z"

MAX_CHARS = 200_000  # これ超は regex を走らせず即 too long (DoS/浪費保護)
MIN_UNITS = 40       # units 未満は採点不能
MAX_UNITS = 40_000   # units 超は採点しない
LENGTH_BASE = 120    # 長さ正規化の基準 (日本語は英語 50 語より密)

_LABEL_RANK = ["クリーン", "軽微", "やや AI 臭", "中程度の AI 臭", "強い AI 臭", "濃厚な AI 臭"]


def _count_units(text: str) -> int:
    """日本語の「語数相当」。かな・漢字の文字数 + ラテン語トークン数。"""
    cjk = len(re.findall(r"[぀-ヿ㐀-鿿々〆ヵヶ]", text))
    latin = len(re.findall(r"[A-Za-z]+", text))
    return cjk + latin


def _strip_noise(text: str) -> str:
    """採点前処理: フェンスドコードと連続 blockquote を除去。

    引用された AI 文やコードを書き手自身の文としてカウントしないため。
    """
    text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
    lines = text.split("\n")
    is_q = [bool(re.match(r"^\s*>\s", ln)) for ln in lines]
    keep = []
    for i, ln in enumerate(lines):
        prev_q = is_q[i - 1] if i > 0 else False
        next_q = is_q[i + 1] if i + 1 < len(lines) else False
        if is_q[i] and (prev_q or next_q):  # 連続 blockquote のみ除去
            continue
        keep.append(ln)
    return "\n".join(keep)


def _compile_literal(pat: str) -> re.Pattern:
    """script 境界を尊重してコンパイル。部分文字列 FP を防ぐ。

    - カタカナ語: 前後がカタカナでない時のみ一致 (「ミッション」を「パーミッション」で拾わない)
    - 漢字語: 前後が漢字でない時のみ一致 (「戦略」を「経営戦略」で拾わない)
    - ラテン語: 前後が英字でない時のみ一致
    - 混在フレーズ (かな含む): 十分に特徴的なのでそのまま部分一致
    """
    esc = re.escape(pat)
    if re.fullmatch(f"[{_KATA}]+", pat):
        return re.compile(f"(?<![{_KATA}]){esc}(?![{_KATA}])")
    if re.fullmatch(f"[{_KANJI}]+", pat):
        return re.compile(f"(?<![{_KANJI}]){esc}(?![{_KANJI}])")
    if re.fullmatch(f"[{_LATIN}]+", pat):
        return re.compile(f"(?<![{_LATIN}]){esc}(?![{_LATIN}])")
    return re.compile(esc)


def _expand_cell(cell: str) -> list[tuple[re.Pattern, str]]:
    """vocab.md の 1 列目セルを (compiled_regex, display) のリストへ展開。

    - '/' 区切りの代替を分割 / 括弧内注記を除去 / 〜~ をワイルドカード化。
    """
    out: list[tuple[re.Pattern, str]] = []
    for part in re.split(r"\s*/\s*", cell.strip()):
        p = re.sub(r"[（(].*?[)）]", "", part).strip()
        p = p.replace("〇", "").replace("◯", "").strip()
        if len(p) < 2:  # 短すぎる断片は誤検知源なので捨てる
            continue
        if "〜" in p or "～" in p:
            rx = re.escape(p).replace("\\〜", ".{0,12}?").replace("\\～", ".{0,12}?")
            out.append((re.compile(rx), part.strip()))
        else:
            out.append((_compile_literal(p), part.strip()))
    return out


def load_vocab(vocab_path: Path) -> list[dict]:
    """vocab.md をパースしてパターン定義のリストを返す。

    各要素: {type, regex, display, note}
    """
    patterns: list[dict] = []
    if not vocab_path.exists():
        return patterns
    current: tuple[str, int | None] | None = None
    for line in vocab_path.read_text(encoding="utf-8").split("\n"):
        if line.startswith("#"):
            heading = line.lstrip("#").strip()
            current = None
            for needle, typ, note_col in VOCAB_SECTIONS:
                if needle in heading:
                    current = (typ, note_col)
                    break
            continue
        if current is None or not line.strip().startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if not cells or not cells[0]:
            continue
        if set(cells[0]) <= {"-", ":", " "}:  # 区切り行
            continue
        if cells[0] in VOCAB_HEADER_CELLS:  # ヘッダ行
            continue
        typ, note_col = current
        note = ""
        if note_col is not None and len(cells) > 2:
            cand = cells[note_col]
            if cand and cand != cells[1]:  # 修正方針列と重複しない場合のみ備考扱い
                note = cand
        for rx, display in _expand_cell(cells[0]):
            patterns.append({"type": typ, "regex": rx, "display": display, "note": note})
    return patterns


def _paragraph_of(pos: int, para_bounds: list[tuple[int, int]]) -> int:
    for idx, (s, e) in enumerate(para_bounds):
        if s <= pos < e:
            return idx
    return -1


def _match_vocab(text: str, patterns: list[dict]) -> list[dict]:
    """語彙パターンを span 付きで検出。tier2 は同段落 2+ でのみ発火。"""
    # 段落境界 (空行区切り) を算出
    para_bounds: list[tuple[int, int]] = []
    pos = 0
    for para in re.split(r"(\n\s*\n)", text):
        if not para.startswith("\n"):
            para_bounds.append((pos, pos + len(para)))
        pos += len(para)

    raw: list[dict] = []
    tier2_by_para: dict[int, set[str]] = {}
    tier2_hits: list[dict] = []

    for pat in patterns:
        for m in pat["regex"].finditer(text):
            hit = {
                "type": pat["type"], "text": m.group(0) if pat["type"] == "template" and "〜" in pat["display"] else pat["display"],
                "severity": SEVERITY[pat["type"]], "start": m.start(), "end": m.end(),
                "note": pat["note"],
            }
            if pat["type"] == "tier2":
                pid = _paragraph_of(m.start(), para_bounds)
                tier2_by_para.setdefault(pid, set()).add(pat["display"])
                tier2_hits.append((pid, hit))
            else:
                raw.append(hit)

    # tier2: 同段落に 2 つ以上の distinct 語がある段落のヒットのみ採用
    for pid, hit in tier2_hits:
        if len(tier2_by_para.get(pid, ())) >= 2:
            raw.append(hit)
    return raw


def _match_literals(text: str, words: list[str], typ: str) -> list[dict]:
    out = []
    for w in words:
        for m in re.finditer(re.escape(w), text):
            out.append({"type": typ, "text": w, "severity": SEVERITY[typ],
                        "start": m.start(), "end": m.end(), "note": ""})
    return out


def _match_regex(text: str, rx: re.Pattern, typ: str) -> list[dict]:
    return [{"type": typ, "text": m.group(0), "severity": SEVERITY[typ],
             "start": m.start(), "end": m.end(), "note": ""}
            for m in rx.finditer(text)]


def _formatting(text: str) -> list[dict]:
    issues: list[dict] = []
    lines = text.split("\n")

    # em dash: U+2014(—) と U+2015(―) と スペース区切りの --
    em = len(re.findall(r"[—―]", text)) + len(re.findall(r"(?<!\S)--(?!\S)", text))
    if em >= 3:
        issues.append({"type": "em-dash", "text": f"em dash {em} 個", "severity": SEVERITY["em-dash"], "note": ""})

    bold = len(re.findall(r"\*\*[^*\n]+\*\*", text))
    paras = max(1, len([p for p in re.split(r"\n\s*\n", text) if p.strip()]))
    if bold >= 6 or (bold >= 3 and bold / paras > 1.5):
        issues.append({"type": "bold-overuse", "text": f"bold {bold} 箇所", "severity": SEVERITY["bold-overuse"], "note": ""})

    for ln in lines:
        if ln.lstrip().startswith("#") and EMOJI_RE.search(ln):
            issues.append({"type": "header-emoji", "text": ln.strip()[:40], "severity": SEVERITY["header-emoji"], "note": ""})

    nonblank = [ln for ln in lines if ln.strip()]
    bullets = [ln for ln in nonblank if re.match(r"^\s*(?:[-*・]|\d+[.)])\s", ln)]
    if len(nonblank) >= 8 and len(bullets) / len(nonblank) > 0.6:
        issues.append({"type": "bullet-overuse", "text": f"箇条書き {len(bullets)}/{len(nonblank)} 行",
                       "severity": SEVERITY["bullet-overuse"], "note": ""})
    return issues


def _dedupe(issues: list[dict]) -> list[dict]:
    """span ベースの重複排除。

    1. 同一 type で他ヒットに包含される span を除去
       (「腹落ち」⊂「腹落ちする」、テンプレ literal ⊂ 誘導 regex の二重計上を防ぐ)
    2. 残りを (type, text) で一意化 (同一フレーズの再出現は 1 回だけ数える)
    """
    spanned = [i for i in issues if "start" in i]
    spanless = [i for i in issues if "start" not in i]
    drop = set()
    for a in range(len(spanned)):
        for b in range(len(spanned)):
            if a == b or spanned[a]["type"] != spanned[b]["type"]:
                continue
            ia, ib = spanned[a], spanned[b]
            # ia が ib に真に包含される (かつ同一でない) なら ia を落とす
            if ib["start"] <= ia["start"] and ia["end"] <= ib["end"] and \
               (ib["start"], ib["end"]) != (ia["start"], ia["end"]):
                drop.add(a)
    kept = [it for idx, it in enumerate(spanned) if idx not in drop] + spanless

    seen = set()
    out = []
    for it in kept:
        key = f"{it['type']}:{it['text']}"
        if key in seen:
            continue
        seen.add(key)
        out.append(it)
    return out


def _label(score: int, severities: set[str]) -> str:
    if score == 0 and not severities:
        return "クリーン"
    if score <= 15:
        base = "軽微"
    elif score <= 35:
        base = "やや AI 臭"
    elif score <= 60:
        base = "中程度の AI 臭"
    elif score <= 80:
        base = "強い AI 臭"
    else:
        base = "濃厚な AI 臭"
    # severity フロア: P0 が 1 件でもあれば最低「強い AI 臭」
    if "P0" in severities:
        floor = "強い AI 臭"
        if _LABEL_RANK.index(base) < _LABEL_RANK.index(floor):
            base = floor
    return base


def analyze(text: str, vocab_path: Path | None = None) -> dict:
    """テキストを採点して {score, label, issues, stats} を返す。"""
    if vocab_path is None:
        vocab_path = Path(__file__).resolve().parent / VOCAB_FILENAME

    if not text or not text.strip():
        return {"score": 0, "label": "空", "issues": [], "stats": {"units": 0}, "unscored": True}
    # 長さゲートを regex より前に (巨大入力の DoS/浪費保護)
    if len(text) > MAX_CHARS:
        return {"score": 0, "label": "長すぎ", "issues": [], "stats": {"chars": len(text)}, "unscored": True}

    text = _strip_noise(text)
    units = _count_units(text)
    if units < MIN_UNITS:
        return {"score": 0, "label": "短すぎ", "issues": [], "stats": {"units": units}, "unscored": True}
    if units > MAX_UNITS:
        return {"score": 0, "label": "長すぎ", "issues": [], "stats": {"units": units}, "unscored": True}

    patterns = load_vocab(vocab_path)

    issues: list[dict] = []
    issues += _match_vocab(text, patterns)
    issues += _match_literals(text, CUTOFF_PATTERNS, "cutoff-disclaimer")
    issues += _match_literals(text, CHATBOT_PATTERNS, "chatbot")
    issues += _match_regex(text, FINGERPRINT_RE, "ai-fingerprint")
    issues += _match_regex(text, PLACEHOLDER_RE, "unfilled-placeholder")
    issues += _formatting(text)

    deduped = _dedupe(issues)

    raw = sum(ISSUE_WEIGHTS.get(it["type"], 2) for it in deduped)
    length_factor = max(1.0, math.log2(units / LENGTH_BASE)) if units > LENGTH_BASE else 1.0
    score = min(100, round(raw / length_factor))
    severities = {it["severity"] for it in deduped}

    by_type: dict[str, int] = {}
    for it in deduped:
        by_type[it["type"]] = by_type.get(it["type"], 0) + 1

    # 出力用に内部フィールド (start/end) は落とす
    clean_issues = [
        {k: v for k, v in it.items() if k not in ("start", "end") and (k != "note" or v)}
        for it in deduped
    ]

    return {
        "score": score,
        "label": _label(score, severities),
        "issues": clean_issues,
        "stats": {
            "units": units,
            "raw_score": raw,
            "length_factor": round(length_factor, 2),
            "by_type": by_type,
            "vocab_loaded": bool(patterns),
        },
    }


def _read_input(path: str | None) -> str:
    if path and path != "-":
        try:
            return Path(path).read_text(encoding="utf-8")
        except OSError as e:
            print(f"入力ファイルを読めません: {e}", file=sys.stderr)
            raise SystemExit(2)
    return sys.stdin.read()


def _pretty(result: dict) -> str:
    lines = [f"スコア: {result['score']}/100  ({result['label']})"]
    st = result.get("stats", {})
    if st.get("units") is not None:
        lines.append(f"  units={st.get('units')} raw={st.get('raw_score')} "
                     f"÷{st.get('length_factor')}  vocab={st.get('vocab_loaded')}")
    if result.get("unscored"):
        return "\n".join(lines)
    order = {"P0": 0, "P1": 1, "P2": 2}
    for it in sorted(result["issues"], key=lambda x: order.get(x["severity"], 9)):
        note = f"  〔備考: {it['note']}〕" if it.get("note") else ""
        lines.append(f"  [{it['severity']}] {it['type']}: {it['text']}{note}")
    if not result["issues"]:
        lines.append("  検出なし")
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description="日本語 AI 臭検出エンジン (スリム)")
    ap.add_argument("file", nargs="?", help="対象ファイル (省略時は stdin)")
    ap.add_argument("--pretty", action="store_true", help="人間可読サマリを出力")
    ap.add_argument("--vocab", help="vocab.md のパス (省略時は本体と同ディレクトリ)")
    args = ap.parse_args()

    text = _read_input(args.file)
    vocab_path = Path(args.vocab) if args.vocab else None
    result = analyze(text, vocab_path=vocab_path)

    if args.pretty:
        print(_pretty(result))
    else:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


# ── CATEGORY_MAP: vocab セクション ↔ エンジン type ↔ LLM 専用 の対応契約 ──
# ドリフト防止。ai-writing-detector.test.py がこの表とエンジンの整合を検証する。
CATEGORY_MAP = {
    # 客観 P0 (エンジン内蔵 / 権威 / vocab 外・言語非依存)
    "objective_p0": {
        "ai-fingerprint": "utm_source / 引用マークアップ漏れ",
        "cutoff-disclaimer": "モデル制約の漏れ",
        "chatbot": "チャットボット痕跡",
        "unfilled-placeholder": "未置換プレースホルダ",
    },
    # 準客観 (フォーマット / エンジン内蔵)
    "formatting": {
        "em-dash": "em dash (U+2014/U+2015/--)",
        "bold-overuse": "bold 過多",
        "header-emoji": "ヘッダ絵文字",
        "bullet-overuse": "箇条書き過多",
    },
    # 語彙リコール (vocab.md 由来 / 実行時パース / P2 助言 → LLM が最終判断)
    "vocab_recall": {
        "tier1": ["カタカナ・バズワード", "抽象動詞・形容詞"],
        "template": ["テンプレ 冒頭/締め/強調/誘導"],
        "tier2": ["Tier 2 語彙", "主観評価が入る語"],
        "redundant": ["冗長表現"],
        "sentence-ending": ["文末の癖"],
    },
    # LLM 判断のみ (正規表現化不可 / 文脈依存 → agent が担当)
    "llm_only": [
        "Claude 出力構造の癖 (結論宣言テンプレ/メタ謝罪/数列宣言/まとめ必置/同意確認)",
        "同義語ローテーション",
        "コピュラ回避 (〜となる/〜となっている)",
        "対比過剰 (ただし/とはいえの多用)",
        "3 つ並列の癖",
        "段落間 bridge 文の欠如",
        "接尾辞密度 性/化/的 (FP 高のため決定論では扱わず LLM が密度を体感判断)",
        "誇大表現・根拠不明の数値 (文脈判断)",
        "vocab 備考の除外条件の最終適用 (エンジンは備考を issue に添えるのみ)",
    ],
}


if __name__ == "__main__":
    raise SystemExit(main())
