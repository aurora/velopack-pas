unit TestUpdater;

{$I ../src/Velopack.Compat.inc}

interface

uses
  SysUtils, Classes, fpcunit, testregistry, Velopack.Types, Velopack.Updater;

type
  TUpdaterTests = class(TTestCase)
  private
    FUpdater: TVelopackUpdater;
    FLog: string;
    FLiveBefore: Integer;
    FEventThreadWasMain: Boolean;
    procedure OnCheck(Sender: TObject; AResult: TUpdateCheckResult;
      const ATarget: TVelopackAsset);
    procedure OnProgress(Sender: TObject; Percent: Integer);
    procedure OnDownloaded(Sender: TObject);
    procedure OnError(Sender: TObject; const AMessage: string);
    procedure WaitIdle;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure CheckReportsAvailableUpdateOnMainThread;
    procedure CheckReportsNoUpdate;
    procedure DownloadReportsProgressThenCompleted;
    procedure ErrorsAreDeliveredAsEvents;
    procedure SecondOperationWhileBusyRaises;
    procedure DownloadWithoutCheckRaises;
    procedure ApplyWithoutDownloadRaises;
    procedure DestroyWhileBusyIsSafe;
  end;

implementation

uses
  Velopack.Native, TestSupport;

procedure TUpdaterTests.SetUp;
begin
  UseStubLibrary;
  FLiveBefore := StubLiveObjects;
  FLog := '';
  FUpdater := TVelopackUpdater.Create(nil);
  FUpdater.OnCheckCompleted := OnCheck;
  FUpdater.OnDownloadProgress := OnProgress;
  FUpdater.OnDownloadCompleted := OnDownloaded;
  FUpdater.OnError := OnError;
end;

procedure TUpdaterTests.TearDown;
begin
  FreeAndNil(FUpdater);
  CheckEquals(FLiveBefore, StubLiveObjects, 'native objects leaked');
  VpkcUnload;
  VpkcLibraryName := '';
end;

procedure TUpdaterTests.OnCheck(Sender: TObject; AResult: TUpdateCheckResult;
  const ATarget: TVelopackAsset);
begin
  FEventThreadWasMain := TThread.CurrentThread.ThreadID = MainThreadID;
  FLog := FLog + 'check:' + IntToStr(Ord(AResult)) + ':' + ATarget.Version + ';';
end;

procedure TUpdaterTests.OnProgress(Sender: TObject; Percent: Integer);
begin
  FLog := FLog + 'p' + IntToStr(Percent) + ';';
end;

procedure TUpdaterTests.OnDownloaded(Sender: TObject);
begin
  FLog := FLog + 'done;';
end;

procedure TUpdaterTests.OnError(Sender: TObject; const AMessage: string);
begin
  FLog := FLog + 'error:' + AMessage + ';';
end;

{ Pumps the main-thread queue until the updater is idle (max ~5 s). }
procedure TUpdaterTests.WaitIdle;
var
  I: Integer;
begin
  for I := 1 to 500 do
  begin
    CheckSynchronize(10);
    if not FUpdater.Busy then
      Break;
  end;
  CheckSynchronize(0);
  CheckFalse(FUpdater.Busy, 'updater still busy after timeout');
end;

procedure TUpdaterTests.CheckReportsAvailableUpdateOnMainThread;
begin
  FUpdater.UpdateUrl := 'http://example.invalid';
  FUpdater.CheckForUpdates;
  WaitIdle;
  CheckEquals('check:0:2.0.0;', FLog);
  CheckTrue(FEventThreadWasMain, 'event must run on the main thread');
  CheckTrue(FUpdater.Info <> nil);
end;

procedure TUpdaterTests.CheckReportsNoUpdate;
begin
  FUpdater.UpdateUrl := 'noupdate';
  FUpdater.CheckForUpdates;
  WaitIdle;
  CheckEquals('check:1:;', FLog);
  CheckTrue(FUpdater.Info = nil);
end;

procedure TUpdaterTests.DownloadReportsProgressThenCompleted;
begin
  FUpdater.UpdateUrl := 'http://example.invalid';
  FUpdater.CheckForUpdates;
  WaitIdle;
  FLog := '';
  FUpdater.DownloadUpdates;
  WaitIdle;
  CheckEquals('p0;p50;p100;done;', FLog);
end;

procedure TUpdaterTests.ErrorsAreDeliveredAsEvents;
begin
  FUpdater.UpdateUrl := 'fail';
  FUpdater.CheckForUpdates;
  WaitIdle;
  CheckTrue(Pos('error:', FLog) = 1, FLog);
  CheckTrue(Pos('stub: cannot create manager', FLog) > 0, FLog);
  // The updater is usable again after an error.
  FUpdater.UpdateUrl := 'noupdate';
  FLog := '';
  FUpdater.CheckForUpdates;
  WaitIdle;
  CheckEquals('check:1:;', FLog);
end;

procedure TUpdaterTests.SecondOperationWhileBusyRaises;
begin
  FUpdater.UpdateUrl := 'http://example.invalid';
  FUpdater.CheckForUpdates;
  try
    FUpdater.CheckForUpdates;
    Fail('EVelopackUpdaterBusy expected');
  except
    on EVelopackUpdaterBusy do ; // expected
  end;
  WaitIdle;
end;

procedure TUpdaterTests.DownloadWithoutCheckRaises;
begin
  FUpdater.UpdateUrl := 'http://example.invalid';
  try
    FUpdater.DownloadUpdates;
    Fail('EVelopackError expected');
  except
    on EVelopackError do ; // expected
  end;
end;

procedure TUpdaterTests.ApplyWithoutDownloadRaises;
begin
  try
    FUpdater.ApplyUpdatesAndRestart;
    Fail('EVelopackError expected');
  except
    on EVelopackError do ; // expected
  end;
end;

procedure TUpdaterTests.DestroyWhileBusyIsSafe;
begin
  FUpdater.UpdateUrl := 'http://example.invalid';
  FUpdater.CheckForUpdates;
  FreeAndNil(FUpdater); // joins the worker and drops queued events
  CheckSynchronize(0);  // must not touch the freed component
end;

initialization
  RegisterTest(TUpdaterTests);
end.
