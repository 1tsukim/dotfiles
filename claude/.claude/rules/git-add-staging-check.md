# Git staging completeness check

After `git add <dir>`, verify that the intended files were actually staged.

`git add <dir>` silently skips files matched by `.gitignore`. Broad unanchored patterns copied from virtualenv templates, such as `lib/`, `bin/`, `build/`, or `include/`, can accidentally exclude source or vendored files at any depth.

## Check

Check before committing when adding a whole directory, a new source/vendor tree, or any source-side directory named like an environment directory.

```bash
git status --short
git diff --cached --stat
git diff --cached --name-only
```

If expected files are missing, inspect ignore matches:

```bash
git check-ignore -v path/to/file
git status --ignored --short
```

Warning signs: source/vendor files appear only as ignored, or `git check-ignore -v` points to a broad pattern such as `lib/`.

## Fix

Prefer narrowing the ignore rule over force-adding files.

```gitignore
# Too broad: matches lib/ at any depth
lib/

# Safer
/lib/
venv/lib/
!src/streamlit_app/lib/
```

Use `git add -f` only as an explicit temporary exception and explain why the ignored file should be committed.

Failure history: Streamlit app, 2026-05 — `lib/` ignored `src/streamlit_app/lib/`, so vendored core files were missing from the commit.
