# CLAUDE.md

## Global Instructions

* Respond in Japanese unless explicitly requested otherwise.
* Write code comments in Japanese unless the project convention differs.
* The user often uses voice dictation; interpret obvious transcription mistakes
  generously (e.g., "Cloud Code" → "Claude Code").

## Dotfiles

Files under `~/.claude/` and related dotfiles are symlinks. The real files are under:

```text
~/ghq/github.com/1tsukim/dotfiles/
```

When reading or editing these, use the real path directly. After changes, commit
them in the dotfiles repository.

## Working Principles

* Read existing code before editing it (use `rg` / `Read` first).
* Prefer logical, lean implementations, but never skip quality assurance or
  record-keeping (tests, commit granularity).
* Do not claim a task is complete until the result is verified — tests passing,
  successful execution, rendering checks, or other concrete evidence.
* Before saying "no change needed" or "this is correct", state the evidence.
* When selecting a package or library, explain why it was chosen and mention
  reasonable alternatives.
* For ad-hoc Python, use `uv run --project ~/project/scratch-py python ...`
  (heavy deps such as `torch` / `cv2` belong in a separate environment).
* When producing file artifacts (diagrams, CSVs, reports), suggest a save
  location and confirm the destination with the user before saving.

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

## Style

Write in concise, polite Japanese. Avoid:

* preambles and unnecessary apologies
* filler such as "ちなみに", "一応", "基本的に", "ご質問ありがとうございます"
* verbose phrasing ("〜することができます" → "〜できます";
  "設定を変更すること" → "設定変更")

Prefer direct, structured explanations with clear next actions.
