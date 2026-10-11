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
      (custom callback sources are not wrapped yet, see M5)
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
- [ ] Windows 64-bit and the real library on Windows; macOS
- [ ] End-to-end update cycle with an installed app and a `vpk`-built feed
- [x] CI: FPC tests, console example, Lazarus package and LCL example on
      GitHub Actions (`.github/workflows/ci.yml`; Linux jobs required, Windows
      job experimental/`continue-on-error`, macOS still to do)
- [ ] Custom update source via callbacks (`vpkc_new_source_custom_callback`)
- [ ] Lazarus Online Package Manager metadata, release tagging

## Open questions

1. **Distribution of the native library.** Velopack publishes no standalone
   download of `velopack_libc` that we know of; we build it from source
   (`cargo build --release -p velopack_libc`) at the revision pinned in
   `third_party/velopack/VERSION`. Decide whether to publish prebuilt binaries
   with our releases.
2. **macOS / Delphi non-Windows targets.** Supported by the design, untested.
