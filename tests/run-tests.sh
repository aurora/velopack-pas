#!/usr/bin/env bash
# Builds the native stub and the FPCUnit suite, then runs it.
# Usage: tests/run-tests.sh [fpcunit arguments, e.g. --suite=TNativeTests]
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
mkdir -p build/units

# The stub gets the default library file name of the current platform, so the
# binding finds it exactly like the real library.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) stub_name="velopack_libc.dll"; stub_flags="-shared -static-libgcc" ;;
  Darwin*)              stub_name="libvelopack_libc.dylib"; stub_flags="-dynamiclib -fPIC" ;;
  *)                    stub_name="libvelopack_libc.so"; stub_flags="-shared -fPIC" ;;
esac

gcc -Wall -Wextra $stub_flags -I third_party/velopack \
  -o "build/$stub_name" tests/stub/velopack_stub.c

# FPC_OPTS: extra compiler options, e.g. unit paths when fpc.cfg is missing.
set -f   # keep '*' in FPC_OPTS for the compiler instead of globbing it
# shellcheck disable=SC2086
fpc -Mdelphi -g -Fu"src" -Fu"tests" -FUbuild/units -FEbuild ${FPC_OPTS:-} \
  -vewn tests/VelopackTests.lpr | grep -E "Error|Fatal|Warning|Note: .*unused" || true
set +f

# TestSupport looks for build/<default library name> relative to the working
# directory; set STUB_LIB to override.
build/VelopackTests --all --format=plain "$@"
