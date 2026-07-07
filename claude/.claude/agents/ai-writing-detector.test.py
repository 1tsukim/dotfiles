#!/usr/bin/env python3
"""ai-writing-detector.py の回帰テスト (依存ゼロ / python3 単体実行)。

    python3 ai-writing-detector.test.py

スリム設計の中核主張を守る:
- 自然な人間文・正当な技術文は低スコアで、部分文字列 FP を出さない
- 客観 P0 (指紋 等) は単独でも severity フロアで「強い AI 臭」以上になる
- 露骨な AI 文は高スコアで P0 を検出
- 語彙は vocab.md から実行時ロードされ、必須語がドリフトで欠落しない
"""
import importlib.util
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location(
    "ai_writing_detector", _HERE / "ai-writing-detector.py"
)
det = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(det)

_fails: list[str] = []


def check(name: str, cond: bool, detail: str = "") -> None:
    mark = "ok  " if cond else "FAIL"
    print(f"[{mark}] {name}" + (f"  — {detail}" if detail and not cond else ""))
    if not cond:
        _fails.append(name)


def types_of(r):
    return {i["type"] for i in r["issues"]}


# ── fixtures ──────────────────────────────────────────────

HUMAN_CLEAN = """\
先週の障害は、キャッシュの有効期限を 5 分から 30 秒に縮めたのが直接の原因でした。
リクエストが集中する朝 9 時台に、オリジンへの問い合わせが 12 倍に跳ね上がっています。
暫定対応として TTL を元に戻し、恒久対応はキャッシュ層の二段構えを検討中です。
明日の朝会で、二段キャッシュの設計方針を 15 分もらって相談させてください。
"""

# FP 回帰① 部分文字列: スコープ/ビジョン/ミッション を
#            ジャイロスコープ/テレビジョン/パーミッション の中で拾ってはいけない
#            (いずれも埋め込み形のみ。単独使用は含めない)
FP_SUBSTRING = """\
本モジュールはトランスミッションとサーボモーターを協調制御します。
ユーザーのパーミッションを確認したうえで、テレビジョン出力の同期処理を行います。
ジャイロスコープとアクセラレーターの生信号もあわせて取り込みます。
"""

# FP 回帰② 非機能要件: 可用性/拡張性/保守性… を密度で誤検出してはいけない
FP_NONFUNCTIONAL = """\
非機能要件として可用性、拡張性、保守性、移植性、信頼性、機能性を評価する。
特に可用性と拡張性の両立が難しい。運用時の可観測性も重視する。
負荷試験では応答性と安定性を計測し、劣化の兆候を早期に捉える。
"""

AI_HEAVY = """\
結論から言うと、本記事では DX を加速するための包括的なソリューションを解説します。

まず、シームレスなプラットフォーム上でデータドリブンなインサイトを可視化し、
効率化・最適化・標準化を推進することで、抜本的な変革を実現できます。
これは戦略的かつ本質的な取り組みであり、まさに多岐にわたる価値創出につながると言えるでしょう。

重要なポイントは以下の 3 つです。私の知識は 2023 年までですが、ぜひ参考にしてみてください。
いかがでしたでしょうか。お役に立てれば幸いです。詳細は [ここにURLを挿入] を参照 utm_source=chatgpt.com
"""

# 客観 P0 単独 (指紋のみ)。本文は自然。
P0_ONLY = """\
この記事の内容は概ね妥当でした。参考リンクはこちらです。検証は明日実施する予定で、
結果が出たら共有します。設計の細部は追って詰めますが、方針自体に大きな異論はありません。
出典: https://example.com/article?utm_source=chatgpt.com
"""

HUMAN_WITH_QUOTE = """\
同僚から届いた AI 生成のドラフトはこんな感じでした。

> 結論から言うと、本記事ではシームレスなソリューションを包括的に解説します。
> まさに多岐にわたる価値創出を実現し、抜本的な変革を加速させます。いかがでしたでしょうか。

これはさすがに直したい。要は「キャッシュを二段にして朝の負荷を捌く」だけの話なので、
そのまま一文で書けば十分です。前置きは全部落としましょう。
"""


# ── tests ─────────────────────────────────────────────────

r_human = det.analyze(HUMAN_CLEAN)
check("人間文は語彙をロードできている", r_human["stats"]["vocab_loaded"])
check("人間文は低スコア (<=15)", r_human["score"] <= 15,
      f"score={r_human['score']} {[i['text'] for i in r_human['issues']]}")

# FP 回帰①: 部分文字列を拾わない
r_fp1 = det.analyze(FP_SUBSTRING)
embedded = {"スコープ", "ビジョン", "ミッション"}
hit_words = {i["text"] for i in r_fp1["issues"]}
check("FP①: 埋め込みカタカナ語を tier1 で拾わない",
      "tier1" not in types_of(r_fp1) and not (embedded & hit_words),
      f"issues={[(i['type'], i['text']) for i in r_fp1['issues']]}")
check("FP①: P1 以上を出さない", all(i["severity"] == "P2" for i in r_fp1["issues"]),
      f"issues={[(i['severity'], i['text']) for i in r_fp1['issues']]}")

# FP 回帰②: 非機能要件を密度誤検出しない (tier3 密度は廃止済み)
r_fp2 = det.analyze(FP_NONFUNCTIONAL)
check("FP②: 非機能要件は低スコア (<=10)", r_fp2["score"] <= 10,
      f"score={r_fp2['score']} {[i['text'] for i in r_fp2['issues']]}")
check("FP②: tier3-density type は存在しない",
      "tier3-density" not in types_of(r_fp2) and "tier3-density" not in det.ISSUE_WEIGHTS)

# AI 文
r_ai = det.analyze(AI_HEAVY)
check("AI 文は高スコア (>=60)", r_ai["score"] >= 60, f"score={r_ai['score']}")
for t in ("tier1", "template", "ai-fingerprint", "cutoff-disclaimer", "unfilled-placeholder"):
    check(f"AI 文で {t} を検出", t in types_of(r_ai), f"types={sorted(types_of(r_ai))}")
check("人間文 < AI 文 のスコア順序", r_human["score"] < r_ai["score"])

# 客観 P0 単独 → severity フロアで「強い AI 臭」以上
r_p0 = det.analyze(P0_ONLY)
check("P0 指紋単独を検出", "ai-fingerprint" in types_of(r_p0))
check("P0 単独でもラベルは強い AI 臭以上 (severity フロア)",
      det._LABEL_RANK.index(r_p0["label"]) >= det._LABEL_RANK.index("強い AI 臭"),
      f"label={r_p0['label']} score={r_p0['score']}")

# 引用ブロックは書き手に加点しない
r_quote = det.analyze(HUMAN_WITH_QUOTE)
check("引用ブロックは書き手に加点しない (<=20)", r_quote["score"] <= 20,
      f"score={r_quote['score']} {[i['text'] for i in r_quote['issues']]}")

# 境界: 短すぎ / 空 / 巨大
check("短すぎる入力は unscored", det.analyze("短い。")["unscored"] is True)
check("空入力は unscored", det.analyze("")["unscored"] is True)
check("巨大入力は regex 前に長すぎで弾く",
      det.analyze("あ" * (det.MAX_CHARS + 1)).get("label") == "長すぎ")

# tier2 クラスタ: 単独は発火せず、同段落 2+ で発火
solo = det.analyze("この施策を着実に推進することが目標です。\n\n" + HUMAN_CLEAN)
check("tier2 単独は発火しない", "tier2" not in types_of(solo))
cluster = det.analyze(
    "本プロジェクトでは変革を推進し、成長を加速する。多角的かつ包括的に取り組む方針だ。"
    "この持続的な活動を通じてスケーラブルな価値提供を目指す。\n\n" + HUMAN_CLEAN
)
check("tier2 は同段落 2+ で発火", "tier2" in types_of(cluster))

# span 重複排除: 「腹落ちする」1 回で tier1 が 2 件に増えない
r_span = det.analyze("その説明でようやく腹落ちする感覚があった。" + HUMAN_CLEAN)
t1 = [i for i in r_span["issues"] if i["type"] == "tier1"]
check("span 重複排除: 腹落ち/腹落ちする が二重計上されない", len(t1) <= 1,
      f"tier1={[i['text'] for i in t1]}")

# 備考が issue に添えられる (LLM が除外判断できる)
# ロバストは tier2 なのでクラスタ (同段落 2+) を満たす文にする
r_note = det.analyze("この設計はロバストかつスケーラブルだと考えている。\n\n" + HUMAN_CLEAN)
robust = [i for i in r_note["issues"] if i["text"] == "ロバスト"]
check("備考を issue に添える (ロバスト=技術文脈は許容)",
      bool(robust) and "技術文脈" in robust[0].get("note", ""),
      f"robust={robust}")

# ドリフト検知: 必須語が vocab から確実にロードされる
pats = det.load_vocab(_HERE / det.VOCAB_FILENAME)
by_type_words = {}
for p in pats:
    by_type_words.setdefault(p["type"], set()).add(p["display"])
check("vocab drift: シームレス ∈ tier1", "シームレス" in by_type_words.get("tier1", set()))
check("vocab drift: いかがでしたでしょうか ∈ template",
      "いかがでしたでしょうか" in by_type_words.get("template", set()))
check("vocab drift: 〜することができる ∈ redundant",
      any("することができる" in w for w in by_type_words.get("redundant", set())))
for typ in ("tier1", "template", "tier2", "redundant", "sentence-ending"):
    check(f"vocab から {typ} をロード", len(by_type_words.get(typ, set())) > 0)

# CATEGORY_MAP ↔ 重み/severity のドリフト防止
mapped = (set(det.CATEGORY_MAP["objective_p0"])
          | set(det.CATEGORY_MAP["formatting"])
          | set(det.CATEGORY_MAP["vocab_recall"]))
check("CATEGORY_MAP の type は全て重み定義あり", mapped <= set(det.ISSUE_WEIGHTS),
      f"missing={mapped - set(det.ISSUE_WEIGHTS)}")
check("CATEGORY_MAP の type は全て severity 定義あり", mapped <= set(det.SEVERITY),
      f"missing={mapped - set(det.SEVERITY)}")
check("重み表と severity 表の type 集合が一致",
      set(det.ISSUE_WEIGHTS) == set(det.SEVERITY),
      f"diff={set(det.ISSUE_WEIGHTS) ^ set(det.SEVERITY)}")
check("重み表の type は全て CATEGORY_MAP に載っている", set(det.ISSUE_WEIGHTS) <= mapped,
      f"unmapped={set(det.ISSUE_WEIGHTS) - mapped}")


# ── summary ───────────────────────────────────────────────
print()
if _fails:
    print(f"FAILED: {len(_fails)} 件 — {_fails}")
    raise SystemExit(1)
print("全テスト通過")
