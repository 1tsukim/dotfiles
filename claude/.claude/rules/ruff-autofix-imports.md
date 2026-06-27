---
paths:
  - "**/*.py"
  - "**/*.ipynb"
---

# Ruff auto-fix and import edits

In repos where hooks run `ruff format` or `ruff check --fix`, intermediate edits may be auto-fixed. If an import is added before its first use, Ruff may delete it as unused (`F401`) before the usage is added.

Prefer a coherent edit that adds both the import and its first usage. If that is impractical, add the usage first, then add the import immediately after; do not stop in the temporary `NameError` state.

Use `# noqa: F401` only as a short-lived workaround, and remove it in the same task unless the user explicitly wants a lasting unused import.

After edits, verify that both the import and usage survived:

```bash
git diff -- path/to/file.py
git diff --cached -- path/to/file.py
ruff check path/to/file.py
```

For runtime-only references, framework imports, or annotation-related names, run the actual entrypoint when practical. `ast.parse` does not catch unresolved names such as `Foo | None`.

Failure history: mitococa-tools, 2026-05-26 — imports for `eval_project_picker` and `s3_image_loader` were removed twice by the hook and surfaced later as Streamlit `NameError`s.
