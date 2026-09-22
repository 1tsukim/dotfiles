# CLAUDE.md

## Global Instructions

* Respond in Japanese unless explicitly requested otherwise.
* Write code comments in Japanese unless the project convention differs.
* The user often uses voice dictation; interpret obvious transcription mistakes
  generously (e.g., "Cloud Code" → "Claude Code").

## Dotfiles

Entries under `~/.claude/` are symlinks into two repositories. Read and edit the
real file, then commit in the repository that owns it:

| Path under `~/.claude/` | Repository |
|---|---|
| `skills/` | `~/ghq/github.com/1tsukim/claude-context/claude/.claude/skills/` |
| `CLAUDE.md`, `settings.json`, `rules/`, `hooks/`, `agents/`, `commands/`, `statusline-command.sh` | `~/ghq/github.com/1tsukim/dotfiles/claude/.claude/` |

When unsure, resolve the target with `readlink ~/.claude/<path>`.

## Working Principles

* If the request has multiple plausible interpretations, present them before
  implementing — do not silently pick one. If something is unclear, stop and
  name what is confusing.
* Read existing code before editing it (use `rg` / `Read` first).
* Prefer logical, lean implementations, but never skip quality assurance or
  record-keeping (tests, commit granularity).
* Convert the task into a verifiable goal before starting ("fix the bug" →
  "write a failing test that reproduces it, then make it pass"), and state the
  verification method for each step of a multi-step plan.
* Do not claim a task is complete until the result is verified — tests passing,
  successful execution, rendering checks, or other concrete evidence.
* Before saying "no change needed" or "this is correct", state the evidence.
* When selecting a package or library, explain why it was chosen and mention
  reasonable alternatives.
* For ad-hoc Python, use `uv run --project ~/project/scratch-py python ...`
  (heavy deps such as `torch` / `cv2` belong in a separate environment).
* When producing file artifacts (diagrams, CSVs, reports), suggest a save
  location and confirm the destination with the user before saving.

## Review Loop (crit)

Artifacts longer than one screen (plans, requirement docs, analysis reports,
slide drafts, code diffs) go through `crit` before being presented: write the
file, then open `crit <file>` so the user can comment on exact lines.

* Keep short answers, one-off questions, and binary decisions in chat — the
  browser round trip costs more than it saves.
* Plan mode needs no action; the `ExitPlanMode` hook routes plans to crit.
* Rendered artifacts (Marp, reveal.js, dashboards) need live mode, not
  `crit preview` — see the `marp` skill.
* Read comments with `crit comments --json`, reply with
  `crit comment --reply-to <id>`. Never pass `--resolve`; resolving is the
  user's call.

## Task Strategy

For non-trivial tasks, briefly consider whether independent investigation,
review, or implementation work can be delegated to subagents.

Use subagents only when they reduce main-context clutter or enable meaningful
parallel work. Do not use them for simple lookups or tightly sequential tasks.

## Command Preferences

* Prefer `rg` over `grep`.
* Prefer `gh` over `WebFetch` for GitHub access.
* Prefer `trash` over `rm` for file deletion.
* Do not run `git checkout` when it may overwrite uncommitted changes without
  user approval.
* Do not use raw `git commit`; use the `commit` skill.
* Before any AWS S3 operation, invoke the `aws-s3` skill (wrappers, `--profile`, overwrite confirmation).

## Style

Write in concise, polite Japanese. Avoid:

* preambles and unnecessary apologies
* filler such as "ちなみに", "一応", "基本的に", "ご質問ありがとうございます"
* verbose phrasing ("〜することができます" → "〜できます";
  "設定を変更すること" → "設定変更")

Prefer direct, structured explanations with clear next actions.
