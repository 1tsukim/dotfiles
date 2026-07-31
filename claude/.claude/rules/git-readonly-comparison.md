# Read-only git comparison

Never use a state-changing git command to inspect or compare code. Uncommitted work — including
work another session or the user made — is lost or hidden the moment you move it.

Do not use for inspection: `git stash` (any form, including `push --keep-index <path>`),
`git checkout`, `git restore`, `git reset`.

## Use instead

```bash
git show HEAD:path/to/file        # committed version of one file (pipe to a temp file if needed)
git diff -- path/to/file          # working tree vs index
git diff --cached -- path/to/file # index vs HEAD
git diff HEAD -- path/to/file     # working tree vs HEAD
git show <rev>:path | diff - path # compare any revision against the current file
```

To lint or run a tool against the committed version, write it out first:
`git show HEAD:src/foo.py > "$TMPDIR/foo_head.py"` — then run the tool on that copy.

## If a state-changing command already ran

Report it to the user immediately, then restore before doing anything else. A dropped stash is
still reachable: `git stash pop`, or `git fsck --unreachable` / the stash commit hash printed by
`Dropped refs/stash@{0} (<sha>)`. Verify the restore with `git diff <sha> -- path` (empty output
means the file matches what was stashed).

Never bury such a command inside a compound one-liner or add `2>/dev/null` — the suppressed output
is exactly the warning you need.

Failure history: pj_cash, 2026-07-31 — `git stash push --keep-index src/feature_engineer.py` was
run only to compare lint counts against HEAD, silently reverting that file's uncommitted changes
while a second session was editing the same repo. `git show HEAD:file` alone would have sufficed
(it was already in the same command).
