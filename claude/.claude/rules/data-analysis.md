---
paths:
  - "**/*.ipynb"
  - "**/notebooks/**/*.py"
  - "**/analysis/**/*.py"
  - "**/eda/**/*.py"
---

# Data analysis and notebook work

Use goal-driven analysis. Do not just inspect data and report surface-level observations.

Before writing analysis code, state the analysis goal in 1-2 sentences:
what should be clarified, compared, explained, or decided?

## Analysis discipline

* Start with a lightweight data sanity check: schema, row count, missingness,
  duplicates, time range, units, and grain.
* Form an explicit hypothesis or question before each non-trivial analysis step.
* Write code to test that hypothesis or answer that question.
* Treat rejected hypotheses as findings, not failures.
* Actively look for unexpected patterns, but report them only when supported by data.
* Distinguish facts from interpretation: state what the data shows, then what it may imply.

## Notebook structure

For Jupyter-oriented work, present code in separate cells. Start each cell with a short role comment, for example:

```python
# Sanity check: schema & missing values
# Hypothesis: delays concentrate at specific stations
# Finding: actual result vs hypothesis
```

Keep each cell focused on one purpose: load, clean, check, analyze, visualize, or summarize.

## When to use staged work

Use the `staged-work` skill when the analysis needs a step-by-step plan, multiple checkpoints, or a longer investigation workflow.
