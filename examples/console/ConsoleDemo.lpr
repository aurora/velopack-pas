{ velopack-pas - console example.

  Usage: ConsoleDemo <update-url-or-directory>

  Shows the minimal update flow: startup hook, check, download, apply. }
program ConsoleDemo;

{$I ../../src/Velopack.Compat.inc}
{$IFNDEF FPC}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  SysUtils,
  Velopack.Types, Velopack.App, Velopack.Manager;

type
  TProgressPrinter = class
    procedure Print(Sender: TObject; Percent: Integer);
  end;

procedure TProgressPrinter.Print(Sender: TObject; Percent: Integer);
begin
  WriteLn('  download: ', Percent, '%');
end;

procedure OnFirstRun(const AppVersion: string);
begin
  WriteLn('Welcome! First run of version ', AppVersion);
end;

var
  Manager: TUpdateManager;
  Info: TUpdateInfo;
  Printer: TProgressPrinter;
  Pending: TVelopackAsset;
begin
  // 1. Must be the first thing the program does. It may terminate the process
  //    when Velopack launches the app for install / update / uninstall.
  TVelopackApp.OnFirstRun(@OnFirstRun);
  if not TVelopackApp.Run then
    WriteLn('Velopack native library not available: running without updates.');

  if ParamCount < 1 then
  begin
    WriteLn('Usage: ConsoleDemo <update-url-or-directory>');
    Halt(2);
  end;

  try
    Manager := TUpdateManager.Create(ParamStr(1));
  except
    on E: EVelopackError do
    begin
      WriteLn('Updates disabled: ', E.Message);
      Halt(1);
    end;
  end;

  Printer := TProgressPrinter.Create;
  try
    WriteLn('App ', Manager.AppId, ' version ', Manager.CurrentVersion);
    Manager.OnProgress := Printer.Print;

    if Manager.UpdatePendingRestart(Pending) then
    begin
      WriteLn('Version ', Pending.Version, ' is downloaded; applying and restarting...');
      Manager.WaitExitThenApplyUpdates(Pending);
      Exit; // let the updater take over
    end;

    case Manager.CheckForUpdates(Info) of
      ucUpdateAvailable:
        try
          WriteLn('Update available: ', Info.TargetFullRelease.Version);
          Manager.DownloadUpdates(Info);
          Manager.WaitExitThenApplyUpdates(Info.TargetFullRelease);
          WriteLn('Updater launched, exiting.');
        finally
          Info.Free;
        end;
      ucNoUpdateAvailable:
        WriteLn('You are up to date.');
      ucRemoteIsEmpty:
        WriteLn('The release feed is empty.');
    end;
  finally
    Printer.Free;
    Manager.Free;
  end;
end.
