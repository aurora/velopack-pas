# Implementation plan

Status legend: `[x]` done, `[ ]` open. Keep this file truthful.

## M0 - Project foundation
- [x] MIT license, `.gitignore`, `.editorconfig`
- [x] Vendor `Velopack.h` as binding reference
- [x] `AGENTS.md`, `CLAUDE.md`
- [ ] Architecture doc, this plan, initial ADRs
- [ ] `README.md`

## M1 - Native binding (layer 1) and support units
- [ ] `Velopack.Compat.inc`
- [ ] `Velopack.Strings`
- [ ] `Velopack.Native`: all types and functions of `Velopack.h`, dynamic loading
- [ ] C stub of the native library for tests (`tests/stub`)
- [ ] `tests/run-tests.sh` and first FPCUnit tests (load / unload / missing library)

## M2 - Object API (layer 3)
- [ ] `Velopack.Types` (records, enums, `EVelopackError`)
- [ ] `Velopack.App` (hooks, auto-apply, args override)
- [ ] `Velopack.Manager`: sources (file, HTTP, GitHub, GitLab, Gitea, Flow),
      options, check / download / apply, pending-restart query
- [ ] Logger bridge (`vpkc_set_logger`)
- [ ] Unit tests against the stub, including leak counting

## M3 - Examples
- [ ] Console example (`examples/console`)
- [ ] Packaging script using `vpk` (`examples/console/pack.sh`)

## M4 - GUI integration (layer 4)
- [ ] Non-visual component `TVelopackUpdater` (worker thread, main-thread events)
- [ ] Lazarus package `packages/lazarus/velopack.lpk` + LCL example
- [ ] Delphi package `packages/delphi/Velopack.dpk` + VCL example
      (cannot be verified in cloud sessions; needs maintainer testing)

## M5 - Quality and release
- [ ] Verify real native library name per platform (see Open questions)
- [ ] Test against the real Velopack library on Windows and Linux
- [ ] CI: FPC build + tests on GitHub Actions
- [ ] Custom update source via callbacks (`vpkc_new_source_custom_callback`)
- [ ] Lazarus Online Package Manager metadata, release tagging

## Open questions

1. **Native library file name.** Assumed `velopack_libc` (`.dll`, `lib*.so`,
   `lib*.dylib`). Not yet verified; override with `VELOPACK_LIBRARY` or
   `VpkcLibraryName` until confirmed.
2. **Distribution of the native library.** Where to obtain it for each
   platform and which Velopack version to pin.
3. **macOS / Delphi non-Windows targets.** Supported by the design, untested.
