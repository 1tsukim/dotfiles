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

# Python 環境

`uv` または Docker のいずれかで構築する。`pip install` をシステム Python に直接叩く提案はしない。仮想環境が無いプロジェクトを触るときは、まず `uv` か Docker どちらで進めるかを確認する。
