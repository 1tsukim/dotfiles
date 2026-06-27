---
paths:
  - "**/*.sh"
  - "**/*.py"
---

# Script naming to avoid hook false positives

Avoid naming local scripts like destructive AWS-style subcommands. Patterns such
as `delete-*`, `terminate-*`, `purge-*`, `release-*`, `revoke-*`, `deregister-*`,
`disassociate-*`, or `detach-*` may trigger
`~/.claude/hooks/block-dangerous-aws.sh` and block harmless commands such as
`bash delete-old.sh`.

Prefer names that are less likely to match destructive subcommand patterns:

* Bad: `delete-old.sh`, `terminate-job.sh`, `purge-cache.sh`
* Good: `cleanup_old.sh`, `old_file_cleanup.sh`, `clear_cache.sh`

The risky pattern is the destructive verb followed by `-`. Names such as
`delete.sh`, `delete_old.sh`, or `my-delete.sh` may avoid this specific pattern,
but still prefer safer names for new scripts.

If an existing filename is blocked, do not disable or rename Claude hooks yourself.
Report the block, suggest renaming the local script when reasonable, and follow
`do-not-self-modify-claude-config.md` for any hook changes.
