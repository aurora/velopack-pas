#!/usr/bin/env python3
"""Packages a built Velopack native library for a velopack-pas release.

The archive contains the library under the exact file name velopack-pas looks
for (see VPKC_DEFAULT_LIBRARY in src/Velopack.Native.pas), the license of
Velopack (required when redistributing its binaries) and a BUILD-INFO.txt that
records where the binary came from.

Usage:
  package-native.py --lib PATH --license PATH --out DIR --os linux|windows|macos
                    --arch x64|x86|arm64 --velopack-commit SHA --rust-target T
Prints the path of the archive.
"""
import argparse
import datetime
import hashlib
import os
import sys
import zipfile

EXPECTED_NAME = {
    "linux": "libvelopack_libc.so",
    "windows": "velopack_libc.dll",
    "macos": "libvelopack_libc.dylib",
}


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--lib", required=True)
    p.add_argument("--license", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--os", required=True, choices=sorted(EXPECTED_NAME))
    p.add_argument("--arch", required=True, choices=["x64", "x86", "arm64"])
    p.add_argument("--velopack-commit", required=True)
    p.add_argument("--rust-target", required=True)
    a = p.parse_args()

    name = EXPECTED_NAME[a.os]
    if os.path.basename(a.lib) != name:
        sys.exit("error: expected the library to be called %s, got %s"
                 % (name, os.path.basename(a.lib)))
    for path in (a.lib, a.license):
        if not os.path.isfile(path):
            sys.exit("error: missing file: " + path)
    os.makedirs(a.out, exist_ok=True)

    info = "\n".join([
        "velopack-pas native library package",
        "",
        "library:         " + name,
        "sha256:          " + sha256(a.lib),
        "size:            %d bytes" % os.path.getsize(a.lib),
        "platform:        %s %s" % (a.os, a.arch),
        "rust target:     " + a.rust_target,
        "velopack source: https://github.com/velopack/velopack",
        "velopack commit: " + a.velopack_commit,
        "built (UTC):     " + datetime.datetime.now(datetime.timezone.utc)
        .strftime("%Y-%m-%d %H:%M:%S"),
        "",
        "Built with: cargo build --release -p velopack_libc",
        "Put the library next to your executable, or point the environment",
        "variable VELOPACK_LIBRARY at it. Velopack is MIT licensed; its license",
        "is included as LICENSE-velopack.txt.",
        "",
    ])

    archive = os.path.join(a.out, "velopack-native-%s-%s.zip" % (a.os, a.arch))
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(a.lib, name)
        z.write(a.license, "LICENSE-velopack.txt")
        z.writestr("BUILD-INFO.txt", info)
    print(archive)


if __name__ == "__main__":
    main()
