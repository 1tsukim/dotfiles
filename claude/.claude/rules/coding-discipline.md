---
paths:
  - "**/*.py"
  - "**/*.ipynb"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
---

# Coding discipline

This rule prevents common LLM coding failures. It only adds details not already covered by `CLAUDE.md`.

Apply this rule to non-trivial code generation or modification. Small obvious edits, simple renames, and one-line fixes may skip it.

## Surgical changes

* Touch only the code directly required by the user's request.
* Do not opportunistically improve nearby code, comments, formatting, or structure.
* Match the existing project style; do not rewrite code to personal preference.
* Do not remove unrelated dead code. Only remove orphaned imports, variables, or functions created by your own change.
* Check: every changed line should be directly traceable to the request.

## Minimal implementation

* Do not add unrequested features, abstractions, configuration knobs, or speculative error handling.
* Prefer the smallest implementation that satisfies the request and fits the existing code; add complexity only with a concrete reason you can state.
* Do not perform large rewrites just because the code could be cleaner.
