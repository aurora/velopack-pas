#!/usr/bin/env bash
# Packages the console example with the Velopack CLI (vpk).
# UNVERIFIED: written from the Velopack documentation; check `vpk --help`
# for the options of your vpk version.
#
# Prerequisites: .NET SDK and `dotnet tool install -g vpk`.
# Usage: examples/console/pack.sh 1.0.0
set -euo pipefail

version="${1:?usage: pack.sh <version>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
out="$root/build/package"

rm -rf "$out"
mkdir -p "$out/publish" "$root/build/units"

fpc -Fu"$root/src" -FU"$root/build/units" -FE"$out/publish" \
  "$root/examples/console/ConsoleDemo.lpr"

# The Velopack native library must be shipped next to the executable.
if [[ -n "${VELOPACK_LIBRARY:-}" ]]; then
  cp "$VELOPACK_LIBRARY" "$out/publish/"
else
  echo "warning: set VELOPACK_LIBRARY to the native library to include it" >&2
fi

vpk pack --packId ConsoleDemo --packVersion "$version" \
  --packDir "$out/publish" --mainExe ConsoleDemo \
  --outputDir "$out/releases"
