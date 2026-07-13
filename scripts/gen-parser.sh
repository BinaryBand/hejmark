#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
antlr4 -v 4.13.2 -Dlanguage=Python3 -visitor -no-listener \
  -Xexact-output-dir -o Himark/adapters/_gen grammar/Himark.g4
touch Himark/adapters/_gen/__init__.py
