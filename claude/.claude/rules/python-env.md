---
paths:
  - "**/*.py"
  - "**/*.ipynb"
  - "**/pyproject.toml"
  - "**/requirements*.txt"
  - "**/Pipfile"
  - "**/Dockerfile"
  - "**/docker-compose*.y*ml"
---

# Python environment

Use an isolated Python environment. Never suggest raw `pip install` into the system Python.

Before adding dependencies or running Python, inspect the project convention: `pyproject.toml`, lockfiles, `requirements*.txt`, `Pipfile`, Docker files, Makefile, README, or existing `.venv`.

Follow the existing manager. Do not migrate to `uv` or Docker unless the user asks.

If no convention exists, ask whether to use `uv` or Docker before setting one up.

Use environment-scoped commands such as `uv run ...`, `docker compose run --rm ...`, or `python -m pip` inside the selected venv/container. Avoid raw `pip install`, `sudo pip install`, and bare `python script.py`.
