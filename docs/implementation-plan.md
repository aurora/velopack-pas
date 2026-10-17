# Implementation plan

Status legend: `[x]` done, `[ ]` open. Keep this file truthful.

## M0 - Project foundation
- [x] MIT license, `.gitignore`, `.editorconfig`
- [x] Vendor `Velopack.h` as binding reference
- [x] `AGENTS.md`, `CLAUDE.md`
- [x] Architecture doc, this plan, initial ADRs
- [x] `README.md`

## M1 - Native binding (layer 1) and support units
- [x] `Velopack.Compat.inc`
- [x] `Velopack.Strings`
- [x] `Velopack.Native`: all types and functions of `Velopack.h`, dynamic loading
- [x] C stub of the native library for tests (`tests/stub`)
- [x] `tests/run-tests.sh` and first FPCUnit tests (load / unload / missing library)

## M2 - Object API (layer 3)
- [x] `Velopack.Types` (records, enums, `EVelopackError`)
- [x] `Velopack.App` (hooks, auto-apply, args override)
- [x] `Velopack.Manager`: sources (file, HTTP, GitHub, GitLab, Gitea, Flow),
      options, check / download / apply, pending-restart query
- [x] Logger bridge (`Velopack.Log`, `vpkc_set_logger`)
- [x] Unit tests against the stub, including leak counting

## M3 - Examples
- [x] Console example (`examples/console`)
- [x] Packaging script using `vpk` (`examples/console/pack.sh`, unverified)

## M4 - GUI integration (layer 4)
- [x] Non-visual component `TVelopackUpdater` (worker thread, main-thread events)
- [x] Lazarus package `packages/lazarus/velopack_pas.lpk` + LCL example
      (built with lazbuild 3.0; example starts under Xvfb, UI interaction not exercised)
- [x] Delphi package `packages/delphi/Velopack.dpk` + VCL example written,
      **unverified** (needs maintainer testing with Delphi)

## M5 - Quality and release
- [x] Verify real native library name: crate `velopack_libc` (cdylib), i.e.
      `libvelopack_libc.so` / `velopack_libc.dll` / `libvelopack_libc.dylib`;
      all 36 exports match (checked on Linux against the built library)
- [x] Smoke tests against the real library on Linux (load, exports, sources,
      error path, `TVelopackApp.Run`); built from the pinned revision in CI
- [x] Windows 32-bit (FPC 3.2.2 + MinGW stub) in CI against the C stub; found
      and fixed a thread-lifetime bug in `TVelopackUpdater` (see architecture)
- [x] Real library on Windows (32-bit `velopack_libc.dll`, built in CI from the
      pinned revision with `i686-pc-windows-msvc` + static CRT): load, exports,
      error path, locator, and the custom-source check/download/checksum cycle
- [x] macOS Intel (x86_64) and Apple Silicon (arm64) in CI: Homebrew's fpc 3.2.2
      builds natively on both, the real `libvelopack_libc.dylib` is built from
      the pinned revision, and the stub suites plus all real-library tests pass
- [ ] Windows 64-bit (needs a 64-bit Free Pascal on the runner; the choco
      package is 32-bit only)
- [ ] End-to-end update cycle with an installed app and a `vpk`-built feed
      (the real-library tests already cover check and download outside an
      installation, using `TVelopackLocator` and a custom source)
- [x] CI: FPC tests, console example, Lazarus package and LCL example on
      GitHub Actions (`.github/workflows/ci.yml`; Linux jobs required, Windows
      Windows and macOS jobs experimental/`continue-on-error`)
- [x] Custom update source via callbacks (`Velopack.CustomSource`); tested against
      the stub and, in CI, end to end against the real library (feed, download,
      checksum verification)
- [x] Release workflow (`.github/workflows/release.yml`, ADR 0009, `docs/releasing.md`):
      native libraries for 5 platforms + sources + checksums on a `v*` tag
- [x] `tools/fetch-native.py`: downloads and verifies the native library from a
      release (unit-tested against a fake release; not yet run against a real one)
- [x] `TVelopackUpdater` can fetch from GitHub releases (`GitHubRepoUrl`,
      `GitHubPrerelease`, `GitHubAccessToken`); tested against the stub only
- [ ] First real release (needs a tag; maintainer's decision)
- [ ] Lazarus Online Package Manager metadata

## Open questions

1. **Distribution of the native library.** Decided in ADR 0009: prebuilt
   libraries are published with releases. Still open: whether upstream attaches
   its own `velopack_libc` builds to public releases (not checked), code signing
   / notarization, and a Linux arm64 build.
2. **Delphi on non-Windows targets.** Supported by the design, untested.
