# velopack-pas

[![CI](https://github.com/aurora/velopack-pas/actions/workflows/ci.yml/badge.svg)](https://github.com/aurora/velopack-pas/actions/workflows/ci.yml)

Free Pascal / Lazarus and Delphi bindings for [Velopack](https://velopack.io),
the installer and auto-update framework. Works in console and GUI
applications.

> **Status: early.** The binding and object API are implemented. Tests run
> against a stub of the native library and, in CI, smoke tests against the real
> Velopack library on Linux. A full update cycle (installed app, real feed),
> Windows/macOS and Delphi are **not** verified yet. See
> [docs/implementation-plan.md](docs/implementation-plan.md).

## How it works

velopack-pas is a **source library**. It translates Velopack's C API to Pascal
and loads the native Velopack library at run time; you ship that library next
to your executable. Nothing from Velopack is re-implemented. Details:
[docs/architecture.md](docs/architecture.md).

## Usage

```pascal
program MyApp;

uses
  Velopack.Types, Velopack.App, Velopack.Manager;

var
  Manager: TUpdateManager;
  Info: TUpdateInfo;
begin
  TVelopackApp.Run;                      // first statement, before the GUI

  Manager := TUpdateManager.Create('https://example.com/releases');
  try
    if Manager.CheckForUpdates(Info) = ucUpdateAvailable then
    try
      Manager.DownloadUpdates(Info);
      Manager.WaitExitThenApplyUpdates(Info.TargetFullRelease);
      // ...now exit your application
    finally
      Info.Free;
    end;
  finally
    Manager.Free;
  end;
end.
```

### Custom update sources

When releases are not on a plain HTTP server, a directory or a supported forge,
serve them yourself: `Velopack.CustomSource.TCustomUpdateSource` takes a feed
provider and a download handler (events or overridden methods); Velopack does
the rest. Keep the source alive as long as a manager uses it. Details and
threading notes are in the unit header.

### GUI applications

`TVelopackUpdater` runs the blocking calls on a worker thread and raises its
events on the main thread; it works with LCL, VCL, FMX and console programs.

```pascal
Updater.UpdateUrl := 'https://example.com/releases';
Updater.OnCheckCompleted := HandleCheck;   // then call Updater.DownloadUpdates
Updater.OnDownloadProgress := HandleProgress;
Updater.OnDownloadCompleted := HandleDownloaded; // Updater.ApplyUpdatesAndRestart; Close;
Updater.CheckForUpdates;
```

Install the Lazarus package `packages/lazarus/velopack_pas.lpk` (or the Delphi
package `packages/delphi/Velopack.dpk`) to get the component on the palette.
Examples: [console](examples/console), [LCL](examples/lcl), [VCL](examples/vcl).
Free Pascal programs on Unix must link `cthreads` (Lazarus does this for you).

## Compiler support

| Compiler | Status |
|----------|--------|
| Free Pascal 3.2.2, Linux | built and tested (also Lazarus 3.0 / LCL gtk2 build) |
| Free Pascal 3.2.2, Windows 32-bit | tests pass in CI against the stub (experimental job) |
| Free Pascal, Windows 64-bit / macOS | expected to work, untested |
| Delphi 10.4+ | designed for, **untested** |

## Getting the native library

Build it from the Velopack sources (needs Rust):

```
git clone https://github.com/velopack/velopack
cd velopack && cargo build --release -p velopack_libc
# -> target/release/libvelopack_libc.so | velopack_libc.dll | libvelopack_libc.dylib
```

Use the revision in [third_party/velopack/VERSION](third_party/velopack/VERSION)
(the one the vendored header and CI use) and put the library next to your
executable, or point `VELOPACK_LIBRARY` at it.

## Development

```
tests/run-tests.sh      # builds the native stub and runs the FPCUnit suite
# also run the smoke tests against a real library:
VELOPACK_REAL_LIB=/path/to/libvelopack_libc.so tests/run-tests.sh
```

Read [AGENTS.md](AGENTS.md) before contributing (modular design, small
commits, English only). Decisions are recorded in [docs/adr](docs/adr).

## License

[MIT](LICENSE). Velopack itself is MIT licensed as well.
