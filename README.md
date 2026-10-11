# velopack-pas

Free Pascal / Lazarus and Delphi bindings for [Velopack](https://velopack.io),
the installer and auto-update framework. Works in console and GUI
applications.

> **Status: early.** The core binding and object API are implemented and tested
> against a stub of the native library. It has **not** yet been verified against
> the real Velopack library, nor with Delphi. See
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

A complete example is in [examples/console](examples/console).

## Compiler support

| Compiler | Status |
|----------|--------|
| Free Pascal 3.2.2, Linux | built and tested |
| Free Pascal, Windows / macOS | expected to work, untested |
| Delphi 10.4+ | designed for, **untested** |

## Development

```
tests/run-tests.sh      # builds the native stub and runs the FPCUnit suite
```

Read [AGENTS.md](AGENTS.md) before contributing (modular design, small
commits, English only). Decisions are recorded in [docs/adr](docs/adr).

## License

[MIT](LICENSE). Velopack itself is MIT licensed as well.
