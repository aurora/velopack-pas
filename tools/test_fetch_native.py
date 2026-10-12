"""Tests for fetch-native.py. Run: python3 -m unittest discover -s tools"""
import hashlib
import importlib.util
import os
import pathlib
import stat
import sys
import tempfile
import unittest
import zipfile

HERE = pathlib.Path(__file__).resolve().parent


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


fetch = load("fetch_native", "fetch-native.py")
package = load("package_native", "package-native.py")


def make_release(directory, os_name="linux", arch="x64", payload=b"LIB-BYTES",
                 corrupt_sums=False, library=True):
    """Builds a fake release directory: one archive plus SHA256SUMS."""
    name = fetch.asset_name(os_name, arch)
    archive = pathlib.Path(directory) / name
    with zipfile.ZipFile(archive, "w") as z:
        if library:
            z.writestr(fetch.LIBRARY_NAME[os_name], payload)
        z.writestr("LICENSE-velopack.txt", "MIT")
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    if corrupt_sums:
        digest = "0" * 64
    (pathlib.Path(directory) / "SHA256SUMS").write_text("%s  %s\n" % (digest, name))
    return pathlib.Path(directory).as_uri()


class Detection(unittest.TestCase):
    def test_arch_names(self):
        for machine, arch in [("x86_64", "x64"), ("AMD64", "x64"), ("arm64", "arm64"),
                              ("aarch64", "arm64"), ("i686", "x86"), ("x86", "x86")]:
            self.assertEqual(fetch.detect_arch(machine), arch, machine)

    def test_unknown_arch_is_an_error(self):
        with self.assertRaises(fetch.FetchError):
            fetch.detect_arch("riscv64")

    def test_library_names_match_the_packaging_script(self):
        self.assertEqual(fetch.LIBRARY_NAME, package.EXPECTED_NAME)

    def test_asset_names_match_the_release_workflow(self):
        self.assertEqual(fetch.asset_name("windows", "x86"), "velopack-native-windows-x86.zip")


class Urls(unittest.TestCase):
    def test_latest_and_pinned(self):
        self.assertEqual(fetch.base_url("a/b", None),
                         "https://github.com/a/b/releases/latest/download")
        self.assertEqual(fetch.base_url("a/b", "v1.0.0"),
                         "https://github.com/a/b/releases/download/v1.0.0")

    def test_override_wins(self):
        self.assertEqual(fetch.base_url("a/b", "v1", "file:///x/"), "file:///x")


class Checksums(unittest.TestCase):
    def test_parses_plain_and_binary_marker(self):
        sums = "AAA  one.zip\nbbb *two.zip\n"
        self.assertEqual(fetch.expected_sha256(sums, "one.zip"), "aaa")
        self.assertEqual(fetch.expected_sha256(sums, "two.zip"), "bbb")

    def test_missing_entry(self):
        with self.assertRaises(fetch.FetchError):
            fetch.expected_sha256("aaa  other.zip\n", "one.zip")


class EndToEnd(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.rel = os.path.join(self.tmp.name, "release")
        self.dest = os.path.join(self.tmp.name, "dest")
        os.makedirs(self.rel)

    def test_installs_only_the_library(self):
        make_release(self.rel)
        path = fetch.fetch("a/b", "v1", "linux", "x64", self.dest,
                           pathlib.Path(self.rel).as_uri())
        self.assertEqual(os.path.basename(path), "libvelopack_libc.so")
        with open(path, "rb") as f:
            self.assertEqual(f.read(), b"LIB-BYTES")
        self.assertEqual(os.listdir(self.dest), ["libvelopack_libc.so"])

    @unittest.skipIf(os.name == "nt", "POSIX permissions")
    def test_library_is_not_private(self):
        make_release(self.rel)
        path = fetch.fetch("a/b", "v1", "linux", "x64", self.dest,
                           pathlib.Path(self.rel).as_uri())
        mode = stat.S_IMODE(os.stat(path).st_mode)
        self.assertEqual(mode, 0o755)

    def test_checksum_mismatch_writes_nothing(self):
        make_release(self.rel, corrupt_sums=True)
        with self.assertRaises(fetch.FetchError) as ctx:
            fetch.fetch("a/b", "v1", "linux", "x64", self.dest,
                        pathlib.Path(self.rel).as_uri())
        self.assertIn("checksum mismatch", str(ctx.exception))
        self.assertFalse(os.path.exists(self.dest) and os.listdir(self.dest))

    def test_archive_without_the_library(self):
        make_release(self.rel, library=False)
        with self.assertRaises(fetch.FetchError):
            fetch.fetch("a/b", "v1", "linux", "x64", self.dest,
                        pathlib.Path(self.rel).as_uri())

    def test_platform_not_in_the_release(self):
        make_release(self.rel)
        with self.assertRaises(fetch.FetchError) as ctx:
            fetch.fetch("a/b", "v1", "windows", "arm64", self.dest,
                        pathlib.Path(self.rel).as_uri())
        self.assertIn("not listed", str(ctx.exception))

    def test_main_returns_nonzero_on_error(self):
        make_release(self.rel, corrupt_sums=True)
        code = fetch.main(["--os", "linux", "--arch", "x64", "--dest", self.dest,
                           "--base-url", pathlib.Path(self.rel).as_uri()])
        self.assertEqual(code, 1)

    def test_main_print_url(self):
        self.assertEqual(fetch.main(["--print-url", "--os", "macos", "--arch", "arm64"]), 0)


if __name__ == "__main__":
    unittest.main()
