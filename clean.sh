#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

rm -rf "$ROOT/isis" "$ROOT/output"
make -C "$ROOT/tools/thames" clean
