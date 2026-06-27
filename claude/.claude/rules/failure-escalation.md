# Failure escalation

When Claude causes a failure, incorrect result, or user correction, consider whether it reveals a reusable rule.

Do not create or edit files under `~/.claude/rules/` on your own judgment. Propose first and wait for explicit user approval.

## When to propose a rule

Propose only when the failure is:

* likely to recur in future tasks
* general enough to apply beyond the current file, repo, or one-off task
* preventable by a concise rule

A single failure is enough if it is serious and reusable; repetition strengthens the case but is not required. See "Good candidates" / "Do not record" for which failures qualify.

## What to do after a failure

1. State the root cause in 1-2 sentences.
2. If it meets the threshold, propose one concise rule addition: target file (`~/.claude/rules/<file>.md`), the rule text, and why it prevents recurrence.
3. Ask for approval in one sentence; create or edit the rule file only after explicit approval.

Do not update `~/.claude/CLAUDE.md` or any rule index unless the user explicitly approves that separate change.

## Good candidates

* wrong assumptions that led to incorrect work
* misuse of tools, APIs, CLI flags, or language features
* OS-specific pitfalls (BSD vs GNU command differences)
* environment-specific traps (`sed -i ''`, unsupported `readlink -f`, incompatible `date` options)
* recurring workflow mistakes a short rule could prevent

## Do not record

* one-off typos or accidental slips
* failures caused mainly by external outages, rate limits, or network errors
* user preferences or style choices (use memory instead when appropriate)
* task-specific facts that belong in project documentation, not global rules

## Relationship to other rules

* `improving-skills-and-rules`: user-initiated ("turn this into a rule").
* This rule: Claude-initiated, after Claude notices its own failure pattern.

Why: writing lessons into `~/.claude/` on your own would conflict with `do-not-self-modify-claude-config.md`. Failure lessons become rules only after explicit approval.
