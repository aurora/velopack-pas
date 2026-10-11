#!/usr/bin/env bash
# Builds the native stub and the FPCUnit suite, then runs it.
# Usage: tests/run-tests.sh [fpcunit arguments, e.g. --suite=TNativeTests]
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
mkdir -p build/units

gcc -Wall -Wextra -shared -fPIC -I third_party/velopack \
  -o build/libvelopack_libc.so tests/stub/velopack_stub.c

fpc -Mdelphi -g -Fu"src" -Fu"tests" -FUbuild/units -FEbuild \
  -vewn tests/VelopackTests.lpr | grep -E "Error|Fatal|Warning|Note: .*unused" || true

export STUB_LIB="$root/build/libvelopack_libc.so"
build/VelopackTests --all --format=plain "$@"
