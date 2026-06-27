---
paths:
  - "**/*.py"
  - "**/*.ipynb"
---

# Python style

Python-specific idioms LLMs tend to over-engineer. General change discipline is in `coding-discipline.md`.

* Do not add broad or unnecessary `try`/`except`. Catch exceptions only when there is a meaningful recovery path, fallback, cleanup, or actionable error message.
* Do not add branches for speculative cases outside the task or data contract. If an edge case matters, handle it explicitly and explain why.
* Keep one function focused on one purpose (separate loading, cleaning, transformation, modeling, and visualization when logically distinct).
* Name functions by what they do or return. Avoid vague names such as `process_data`, `handle_result`, or `do_analysis`.
* Extract meaningful thresholds, conditions, and specification values into named constants: filter thresholds, tolerances, bin counts, time windows, limits, and acceptance criteria.
* Inline literals are fine for one-off presentation tweaks such as figure title font size, padding, line width, or marker size.
