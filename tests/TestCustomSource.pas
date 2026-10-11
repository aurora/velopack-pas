unit TestCustomSource;

{$I ../src/Velopack.Compat.inc}

interface

uses
  SysUtils, fpcunit, testregistry, Velopack.Types, Velopack.CustomSource;

type
  TCustomSourceTests = class(TTestCase)
  private
    FProgress: string;
    FLiveBefore: Integer;
    FSeenFeedName: string;
    FSeenAsset: TVelopackAsset;
    FSeenPath: string;
    FRaiseInFeed: Boolean;
    FDownloadResult: Boolean;
    FSource: TCustomUpdateSource;
    function OnFeed(Sender: TObject; const AReleasesName: string): string;
    function OnDownload(Sender: TObject; const AAsset: TVelopackAsset;
      const ALocalPath: string; AProgressId: TVelopackProgressId): Boolean;
    procedure OnProgress(Sender: TObject; Percent: Integer);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure FeedReachesTheNativeLibraryUnchanged;
    procedure DownloadReceivesAssetPathAndReportsProgress;
    procedure FeedExceptionBecomesAFailure;
    procedure DownloadReturningFalseRaises;
    procedure MissingHandlersGiveADescriptiveError;
    procedure SubclassCanOverrideTheMethods;
    procedure SourceFreedBeforeManagerFailsCleanly;
  end;

implementation

uses
  Velopack.Native, Velopack.Manager, TestSupport;

type
  TCStrFn = function: PAnsiChar; cdecl;

  { Override style instead of events. }
  TOverridingSource = class(TCustomUpdateSource)
  public
    Calls: string;
  protected
    function GetReleaseFeed(const AReleasesName: string): string; override;
    function DownloadAsset(const AAsset: TVelopackAsset;
      const ALocalPath: string; AProgressId: TVelopackProgressId): Boolean; override;
  end;

const
  // "ü" written as UTF-8 bytes so the test does not depend on the source file
  // encoding or the compiler's code page handling.
  FeedJson =
    '{"Assets":[{"PackageId":"A","Version":"2.0.0","Type":"Full",' +
    '"FileName":"A-2.0.0-full.nupkg","SHA1":"s1","SHA256":"s2","Size":5,' +
    '"NotesMarkdown":"gr'#$C3#$BC#$C3#$9F'e"}]}';

function TOverridingSource.GetReleaseFeed(const AReleasesName: string): string;
begin
  Calls := Calls + 'feed;';
  Result := FeedJson;
end;

function TOverridingSource.DownloadAsset(const AAsset: TVelopackAsset;
  const ALocalPath: string; AProgressId: TVelopackProgressId): Boolean;
begin
  Calls := Calls + 'download;';
  ReportProgress(AProgressId, 50);
  Result := True;
end;

procedure TCustomSourceTests.SetUp;
begin
  UseStubLibrary;
  FProgress := '';
  FSeenFeedName := '';
  FSeenPath := '';
  FSeenAsset := Default(TVelopackAsset);
  FRaiseInFeed := False;
  FDownloadResult := True;
  FLiveBefore := StubLiveObjects;
  FSource := TCustomUpdateSource.Create;
  FSource.OnGetReleaseFeed := OnFeed;
  FSource.OnDownloadAsset := OnDownload;
end;

procedure TCustomSourceTests.TearDown;
begin
  FreeAndNil(FSource);
  CheckEquals(FLiveBefore, StubLiveObjects, 'native objects leaked');
  VpkcUnload;
  VpkcLibraryName := '';
end;

function TCustomSourceTests.OnFeed(Sender: TObject;
  const AReleasesName: string): string;
begin
  FSeenFeedName := AReleasesName;
  if FRaiseInFeed then
    raise Exception.Create('boom');
  Result := FeedJson;
end;

function TCustomSourceTests.OnDownload(Sender: TObject;
  const AAsset: TVelopackAsset; const ALocalPath: string;
  AProgressId: TVelopackProgressId): Boolean;
begin
  FSeenAsset := AAsset;
  FSeenPath := ALocalPath;
  (Sender as TCustomUpdateSource).ReportProgress(AProgressId, 25);
  (Sender as TCustomUpdateSource).ReportProgress(AProgressId, 60);
  Result := FDownloadResult;
end;

procedure TCustomSourceTests.OnProgress(Sender: TObject; Percent: Integer);
begin
  FProgress := FProgress + IntToStr(Percent) + ';';
end;

procedure TCustomSourceTests.FeedReachesTheNativeLibraryUnchanged;
var
  M: TUpdateManager;
  Info: TUpdateInfo;
begin
  M := TUpdateManager.CreateWithSource(FSource);
  try
    CheckTrue(M.CheckForUpdates(Info) = ucUpdateAvailable);
    Info.Free;
  finally
    M.Free;
  end;
  CheckEquals('releases.stable.json', FSeenFeedName);
  CheckEquals('releases.stable.json',
    string(TCStrFn(StubProc('vpkc_stub_last_feed_name'))()));
  CheckEquals(HexOf(FeedJson),
    HexOf(RawByteString(TCStrFn(StubProc('vpkc_stub_last_feed'))())),
    'feed bytes (incl. UTF-8) must arrive unchanged');
end;

procedure TCustomSourceTests.DownloadReceivesAssetPathAndReportsProgress;
var
  M: TUpdateManager;
  Info: TUpdateInfo;
begin
  M := TUpdateManager.CreateWithSource(FSource);
  try
    M.OnProgress := OnProgress;
    M.CheckForUpdates(Info);
    try
      M.DownloadUpdates(Info);
    finally
      Info.Free;
    end;
  finally
    M.Free;
  end;
  CheckEquals('2.0.0', FSeenAsset.Version);
  CheckEquals('Full', FSeenAsset.AssetType);
  CheckTrue(FSeenAsset.Size = 5000000000, 'asset is the one the manager chose');
  CheckEquals('/tmp/vpk-stub-download.nupkg', FSeenPath);
  // 0 and 100 come from the native library, 25 and 60 from the handler.
  CheckEquals('0;25;60;100;', FProgress);
end;

procedure TCustomSourceTests.FeedExceptionBecomesAFailure;
var
  M: TUpdateManager;
  Info: TUpdateInfo;
begin
  FRaiseInFeed := True;
  M := TUpdateManager.CreateWithSource(FSource);
  try
    try
      M.CheckForUpdates(Info);
      Fail('EVelopackError expected');
    except
      on EVelopackError do ; // expected: reported as a normal failure
    end;
  finally
    M.Free;
  end;
  CheckEquals('boom', FSource.LastCallbackError);
end;

procedure TCustomSourceTests.DownloadReturningFalseRaises;
var
  M: TUpdateManager;
  Info: TUpdateInfo;
begin
  FDownloadResult := False;
  M := TUpdateManager.CreateWithSource(FSource);
  try
    M.CheckForUpdates(Info);
    try
      try
        M.DownloadUpdates(Info);
        Fail('EVelopackError expected');
      except
        on E: EVelopackError do
          CheckTrue(Pos('custom download callback returned false', E.Message) > 0,
            E.Message);
      end;
    finally
      Info.Free;
    end;
  finally
    M.Free;
  end;
end;

procedure TCustomSourceTests.MissingHandlersGiveADescriptiveError;
var
  Bare: TCustomUpdateSource;
  M: TUpdateManager;
  Info: TUpdateInfo;
begin
  Bare := TCustomUpdateSource.Create;
  try
    M := TUpdateManager.CreateWithSource(Bare);
    try
      try
        M.CheckForUpdates(Info);
        Fail('EVelopackError expected');
      except
        on EVelopackError do ; // expected
      end;
    finally
      M.Free;
    end;
    CheckTrue(Pos('OnGetReleaseFeed', Bare.LastCallbackError) > 0,
      Bare.LastCallbackError);
  finally
    Bare.Free;
  end;
end;

procedure TCustomSourceTests.SubclassCanOverrideTheMethods;
var
  Src: TOverridingSource;
  M: TUpdateManager;
  Info: TUpdateInfo;
begin
  Src := TOverridingSource.Create;
  try
    M := TUpdateManager.CreateWithSource(Src);
    try
      M.OnProgress := OnProgress;
      M.CheckForUpdates(Info);
      try
        M.DownloadUpdates(Info);
      finally
        Info.Free;
      end;
    finally
      M.Free;
    end;
    CheckEquals('feed;download;', Src.Calls);
    CheckEquals('0;50;100;', FProgress);
  finally
    Src.Free;
  end;
end;

procedure TCustomSourceTests.SourceFreedBeforeManagerFailsCleanly;
var
  Src: TCustomUpdateSource;
  M: TUpdateManager;
  Info: TUpdateInfo;
begin
  Src := TCustomUpdateSource.Create;
  Src.OnGetReleaseFeed := OnFeed;
  M := TUpdateManager.CreateWithSource(Src);
  try
    Src.Free; // the manager outlives its source: callbacks must not crash
    FSeenFeedName := '';
    try
      M.CheckForUpdates(Info);
      Fail('EVelopackError expected');
    except
      on EVelopackError do ; // expected
    end;
    CheckEquals('', FSeenFeedName, 'the freed source must not be called');
  finally
    M.Free;
  end;
end;

initialization
  RegisterTest(TCustomSourceTests);
end.
