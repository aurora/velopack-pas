#!/usr/bin/env python3
"""Downloads the Velopack native library for velopack-pas from a GitHub release.

The library is verified against the SHA256SUMS file of the same release before
anything is written. Only the library file is extracted.

Examples:
  fetch-native.py --dest build                  # latest stable release, this machine
  fetch-native.py --version v0.1.0-beta.1 --dest bin --arch x86
  fetch-native.py --print-url                   # show what would be downloaded

IMPORTANT: --arch is the architecture of YOUR EXECUTABLE, not of the machine. A
32-bit Free Pascal program on 64-bit Windows needs --arch x86. The default is
the architecture of this machine and is printed so that you can check it.

"Latest" means the newest non-pre-release; pre-releases need --version.
"""
import argparse
import hashlib
import io
import os
import platform
import sys
import tempfile
import urllib.error
import urllib.request
import zipfile

DEFAULT_REPO = "aurora/velopack-pas"

# Must match tools/package-native.py (a unit test checks that).
LIBRARY_NAME = {
    "linux": "libvelopack_libc.so",
    "windows": "velopack_libc.dll",
    "macos": "libvelopack_libc.dylib",
}


class FetchError(Exception):
    pass


def detect_os():
    system = platform.system().lower()
    if system == "linux":
        return "linux"
    if system == "windows":
        return "windows"
    if system == "darwin":
        return "macos"
    raise FetchError("unsupported operating system: " + platform.system())


def detect_arch(machine=None):
    machine = (machine or platform.machine()).lower()
    if machine in ("x86_64", "amd64", "x64"):
        return "x64"
    if machine in ("arm64", "aarch64"):
        return "arm64"
    if machine in ("i386", "i686", "x86"):
        return "x86"
    raise FetchError("unsupported architecture: " + machine)


def asset_name(os_name, arch):
    return "velopack-native-%s-%s.zip" % (os_name, arch)


def base_url(repo, version, override=None):
    if override:
        return override.rstrip("/")
    if version:
        return "https://github.com/%s/releases/download/%s" % (repo, version)
    # No API call, no rate limit: GitHub redirects to the latest stable release.
    return "https://github.com/%s/releases/latest/download" % repo


def read_url(url):
    try:
        with urllib.request.urlopen(url, timeout=60) as r:
            return r.read()
    except urllib.error.HTTPError as e:
        raise FetchError("download failed (HTTP %d): %s" % (e.code, url))
    except urllib.error.URLError as e:
        raise FetchError("download failed (%s): %s" % (e.reason, url))


def expected_sha256(sums_text, name):
    """Looks up a file in a `sha256sum` style listing."""
    for line in sums_text.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1].lstrip("*") == name:
            return parts[0].lower()
    raise FetchError("%s is not listed in SHA256SUMS" % name)


def install_library(archive_bytes, os_name, dest):
    """Writes only the library out of the archive; returns its path."""
    lib = LIBRARY_NAME[os_name]
    try:
        z = zipfile.ZipFile(io.BytesIO(archive_bytes))
        data = z.read(lib)
    except (zipfile.BadZipFile, KeyError):
        raise FetchError("the archive does not contain " + lib)
    os.makedirs(dest, exist_ok=True)
    target = os.path.join(dest, lib)
    fd, tmp = tempfile.mkstemp(dir=dest, prefix=".fetch-native-")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        os.chmod(tmp, 0o755)  # mkstemp creates 0600; libraries are normally shared
        os.replace(tmp, target)  # atomic: never leaves a half-written library
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise
    return target


def fetch(repo, version, os_name, arch, dest, url_override=None):
    base = base_url(repo, version, url_override)
    name = asset_name(os_name, arch)
    sums = read_url(base + "/SHA256SUMS").decode("utf-8", "replace")
    want = expected_sha256(sums, name)
    archive = read_url(base + "/" + name)
    got = hashlib.sha256(archive).hexdigest()
    if got != want:
        raise FetchError("checksum mismatch for %s: expected %s, got %s"
                         % (name, want, got))
    return install_library(archive, os_name, dest)


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0],
                                formatter_class=argparse.RawDescriptionHelpFormatter,
                                epilog="\n".join(__doc__.splitlines()[2:]))
    p.add_argument("--version", help="release tag, e.g. v0.1.0 (default: latest stable)")
    p.add_argument("--dest", default=".", help="directory for the library (default: .)")
    p.add_argument("--os", choices=sorted(LIBRARY_NAME), help="default: this machine")
    p.add_argument("--arch", choices=["x64", "x86", "arm64"],
                   help="architecture of your executable (default: this machine)")
    p.add_argument("--repo", default=DEFAULT_REPO, help="default: " + DEFAULT_REPO)
    p.add_argument("--base-url", help="download from here instead of GitHub "
                   "(a directory with SHA256SUMS and the archives; file:// works)")
    p.add_argument("--print-url", action="store_true",
                   help="only print the archive URL")
    a = p.parse_args(argv)
    try:
        os_name = a.os or detect_os()
        arch = a.arch or detect_arch()
        url = base_url(a.repo, a.version, a.base_url) + "/" + asset_name(os_name, arch)
        if a.print_url:
            print(url)
            return 0
        print("platform: %s %s%s" % (os_name, arch,
              "" if a.arch else "  (detected; use --arch for another executable)"))
        path = fetch(a.repo, a.version, os_name, arch, a.dest, a.base_url)
        print("installed: " + path)
        return 0
    except FetchError as e:
        print("error: %s" % e, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
