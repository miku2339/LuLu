#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT_DIR/work"
TEST_BINARY="$(mktemp "$ROOT_DIR/work/preview-model-tests.XXXXXX")"
trap 'rm -f "$TEST_BINARY"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=11.0 \
    -framework Cocoa "$ROOT_DIR/Preview/PreviewModelTests.m" "$ROOT_DIR/Preview/PreviewModel.m" -o "$TEST_BINARY"
"$TEST_BINARY"
