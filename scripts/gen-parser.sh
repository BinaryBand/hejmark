#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
antlr4 -v 4.13.2 -Dlanguage=Python3 -visitor -no-listener \
  -Xexact-output-dir -o Himark/_gen grammar/Himark.g4
touch Himark/_gen/__init__.py
