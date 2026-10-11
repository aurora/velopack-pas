unit TestManager;

{$I ../src/Velopack.Compat.inc}

interface

uses
  SysUtils, fpcunit, testregistry, Velopack.Types;

type
  TManagerTests = class(TTestCase)
  private
    FProgress: string;
    FLiveBefore: Integer;
    procedure OnProgress(Sender: TObject; Percent: Integer);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure ReadsVersionAppIdAndPortable;
    procedure CreateFailureRaisesWithNativeMessage;
    procedure CheckReturnsUpdateInfoWithAssets;
    procedure NoUpdateAndEmptyRemoteAreResults;
    procedure CheckErrorRaises;
    procedure DownloadReportsProgress;
    procedure DownloadFailureRaises;
    procedure ApplyPassesAssetAndArguments;
    procedure PendingRestartReturnsAsset;
    procedure PendingRestartReturnsFalseWhenNone;
    procedure ManagerWithSourceWorks;
    procedure NothingLeaksAfterFullCycle;
  end;

implementation

uses
  Velopack.Native, Velopack.Strings, Velopack.Manager, TestSupport;

type
  TCStrFn = function: PAnsiChar; cdecl;
  TIntFn = function: Integer; cdecl;
  TSizeFn = function: NativeUInt; cdecl;

procedure TManagerTests.SetUp;
begin
  UseStubLibrary;
  FProgress := '';
  FLiveBefore := StubLiveObjects;
end;

procedure TManagerTests.TearDown;
begin
  CheckEquals(FLiveBefore, StubLiveObjects, 'native objects leaked');
  VpkcUnload;
  VpkcLibraryName := '';
end;

procedure TManagerTests.OnProgress(Sender: TObject; Percent: Integer);
begin
  FProgress := FProgress + IntToStr(Percent) + ';';
end;

procedure TManagerTests.ReadsVersionAppIdAndPortable;
var
  M: TUpdateManager;
begin
  M := TUpdateManager.Create('http://example.invalid');
  try
    CheckEquals('1.2.3', M.CurrentVersion);
    CheckEquals('StubApp', M.AppId);
    CheckTrue(M.IsPortable);
  finally
    M.Free;
  end;
end;

procedure TManagerTests.CreateFailureRaisesWithNativeMessage;
begin
  try
    TUpdateManager.Create('fail').Free;
    Fail('EVelopackError expected');
  except
    on E: EVelopackError do
      CheckTrue(Pos('stub: cannot create manager', E.Message) > 0, E.Message);
  end;
end;

procedure TManagerTests.CheckReturnsUpdateInfoWithAssets;
var
  M: TUpdateManager;
  Info: TUpdateInfo;
begin
  M := TUpdateManager.Create('http://example.invalid');
  try
    CheckTrue(M.CheckForUpdates(Info) = ucUpdateAvailable);
    try
      CheckEquals('2.0.0', Info.TargetFullRelease.Version);
      CheckEquals('Full', Info.TargetFullRelease.AssetType);
      CheckEquals('StubApp', Info.TargetFullRelease.PackageId);
      CheckTrue(Info.TargetFullRelease.Size = 5000000000, '64 bit size');
      CheckEquals('23204E6F74657320C3BC',
        HexOf(ToUtf8(Info.TargetFullRelease.NotesMarkdown)), 'UTF-8 notes');
      CheckFalse(Info.HasBaseRelease);
      CheckFalse(Info.IsDowngrade);
      CheckEquals(1, Length(Info.DeltasToTarget));
      CheckEquals('Delta', Info.DeltasToTarget[0].AssetType);
    finally
      Info.Free;
    end;
  finally
    M.Free;
  end;
end;

procedure TManagerTests.NoUpdateAndEmptyRemoteAreResults;
var
  M: TUpdateManager;
  Info: TUpdateInfo;
begin
  M := TUpdateManager.Create('noupdate');
  try
    CheckTrue(M.CheckForUpdates(Info) = ucNoUpdateAvailable);
    CheckTrue(Info = nil);
  finally
    M.Free;
  end;
  M := TUpdateManager.Create('empty');
  try
    CheckTrue(M.CheckForUpdates(Info) = ucRemoteIsEmpty);
    CheckTrue(Info = nil);
  finally
    M.Free;
  end;
end;

procedure TManagerTests.CheckErrorRaises;
var
  M: TUpdateManager;
  Info: TUpdateInfo;
begin
  M := TUpdateManager.Create('error');
  try
    try
      M.CheckForUpdates(Info);
      Fail('EVelopackError expected');
    except
      on E: EVelopackError do
        CheckTrue(Pos('stub: check failed', E.Message) > 0, E.Message);
    end;
  finally
    M.Free;
  end;
end;

procedure TManagerTests.DownloadReportsProgress;
var
  M: TUpdateManager;
  Info: TUpdateInfo;
begin
  M := TUpdateManager.Create('http://example.invalid');
  try
    M.OnProgress := OnProgress;
    M.CheckForUpdates(Info);
    try
      M.DownloadUpdates(Info);
    finally
      Info.Free;
    end;
    CheckEquals('0;50;100;', FProgress);
  finally
    M.Free;
  end;
end;

procedure TManagerTests.DownloadFailureRaises;
var
  M: TUpdateManager;
  Info: TUpdateInfo;
begin
  M := TUpdateManager.Create('dlfail');
  try
    M.CheckForUpdates(Info);
    try
      try
        M.DownloadUpdates(Info);
        Fail('EVelopackError expected');
      except
        on E: EVelopackError do
          CheckTrue(Pos('stub: download failed', E.Message) > 0, E.Message);
      end;
    finally
      Info.Free;
    end;
  finally
    M.Free;
  end;
end;

procedure TManagerTests.ApplyPassesAssetAndArguments;
var
  M: TUpdateManager;
  Info: TUpdateInfo;
begin
  M := TUpdateManager.Create('http://example.invalid');
  try
    M.CheckForUpdates(Info);
    try
      M.WaitExitThenApplyUpdates(Info.TargetFullRelease, True, True,
        ['--restarted', 'x y']);
    finally
      Info.Free;
    end;
    CheckEquals('2.0.0', string(TCStrFn(StubProc('vpkc_stub_apply_version'))()));
    CheckEquals(1, TIntFn(StubProc('vpkc_stub_apply_silent'))(), 'silent');
    CheckEquals(1, TIntFn(StubProc('vpkc_stub_apply_restart'))(), 'restart');
    CheckEquals(2, Integer(TSizeFn(StubProc('vpkc_stub_apply_argc'))()), 'argc');
    CheckEquals('--restarted', string(TCStrFn(StubProc('vpkc_stub_apply_arg0'))()));
  finally
    M.Free;
  end;
end;

procedure TManagerTests.PendingRestartReturnsAsset;
var
  M: TUpdateManager;
  A: TVelopackAsset;
begin
  M := TUpdateManager.Create('pending');
  try
    CheckTrue(M.UpdatePendingRestart(A));
    CheckEquals('1.9.0', A.Version);
  finally
    M.Free;
  end;
end;

procedure TManagerTests.PendingRestartReturnsFalseWhenNone;
var
  M: TUpdateManager;
  A: TVelopackAsset;
begin
  M := TUpdateManager.Create('http://example.invalid');
  try
    CheckFalse(M.UpdatePendingRestart(A));
    CheckEquals('', A.Version);
  finally
    M.Free;
  end;
end;

procedure TManagerTests.ManagerWithSourceWorks;
var
  S: TUpdateSource;
  M: TUpdateManager;
begin
  S := TUpdateSource.FromFile('/tmp/releases');
  try
    M := TUpdateManager.CreateWithSource(S);
  finally
    S.Free; // allowed right after creating the manager
  end;
  try
    CheckEquals('1.2.3', M.CurrentVersion);
  finally
    M.Free;
  end;
end;

procedure TManagerTests.NothingLeaksAfterFullCycle;
var
  M: TUpdateManager;
  Info: TUpdateInfo;
  S: TUpdateSource;
begin
  S := TUpdateSource.FromGitHub('https://github.com/a/b', 'token', True);
  S.Free;
  M := TUpdateManager.CreateFlow(DefaultUpdateOptions);
  try
    M.CheckForUpdates(Info);
    Info.Free;
  finally
    M.Free;
  end;
  // TearDown compares the live object count with the value from SetUp.
end;

initialization
  RegisterTest(TManagerTests);
end.
