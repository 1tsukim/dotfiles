# Claude config safety — do not self-modify

Do not modify Claude Code's safety-critical config on your own judgment.
Applies to `~/.claude/hooks/**`, `~/.claude/settings.json`, `~/.claude/CLAUDE.md`.

* Never edit, rename (incl. to `.off`), move, chmod, comment out, or otherwise
  weaken these files — including when a hook blocks, slows, or inconveniences the
  task — unless the user explicitly instructs it (e.g. "disable this hook",
  "add X to permissions.deny").
* If a hook/setting blocks the task: stop and report what was blocked, which
  hook/setting is involved, and the options — then wait for an explicit instruction.
* Before changing: state the expected impact (e.g. "weakens deletion protection",
  "allows previously-denied commands").
* After changing: state how to revert (backup path, previous value, exact revert
  command, or the commit/diff to undo).

Why: hooks, settings, and `CLAUDE.md` are Claude Code's safety layer.
Self-modifying them removes safeguards and amplifies the damage of mistakes.
