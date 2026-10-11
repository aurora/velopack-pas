{ Smoke tests against the REAL Velopack native library.

  Registered only when the environment variable VELOPACK_REAL_LIB points to the
  library (for example target/release/libvelopack_libc.so of a Velopack
  checkout built with `cargo build --release -p velopack_libc`). Without it the
  suite runs against the C stub only.

  A real update cycle needs an installed Velopack application and a package
  feed, which is out of scope here; these tests cover loading, symbol
  resolution, source creation and the error path outside an installation. }
unit TestRealLibrary;

{$I ../src/Velopack.Compat.inc}

interface

uses
  SysUtils, fpcunit, testregistry;

type
  TRealLibraryTests = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure LoadsAndResolvesAllExports;
    procedure ManagerOutsideInstallationRaisesNativeError;
    procedure AppRunReturnsForNormalStart;
    procedure SourcesCanBeCreatedAndFreed;
    procedure ManagerWithLocatorReadsTheManifest;
    procedure CustomSourceDrivesCheckAndDownload;
  end;

implementation

uses
  Classes, Velopack.Native, Velopack.Types, Velopack.App, Velopack.Manager,
  Velopack.CustomSource;

const
  ENV_REAL_LIB = 'VELOPACK_REAL_LIB';

procedure RemoveTestRoots; forward;

procedure TRealLibraryTests.SetUp;
begin
  VpkcLibraryName := GetEnvironmentVariable(ENV_REAL_LIB);
end;

procedure TRealLibraryTests.TearDown;
begin
  VpkcUnload;
  VpkcLibraryName := '';
  RemoveTestRoots;
end;

procedure TRealLibraryTests.LoadsAndResolvesAllExports;
begin
  CheckTrue(VpkcTryLoad, VpkcLoadError);
  CheckEquals(GetEnvironmentVariable(ENV_REAL_LIB), VpkcLoadedPath);
end;

procedure TRealLibraryTests.ManagerOutsideInstallationRaisesNativeError;
begin
  try
    TUpdateManager.Create(GetTempDir).Free;
    Fail('EVelopackError expected: the test process is not a Velopack install');
  except
    on E: EVelopackError do
      CheckTrue(Pos('not properly installed', E.Message) > 0,
        'message from the native library expected, got: ' + E.Message);
  end;
end;

procedure TRealLibraryTests.AppRunReturnsForNormalStart;
begin
  // Plain launch without Velopack arguments: Run must return, not exit.
  TVelopackApp.SetArgs([]);
  CheckTrue(TVelopackApp.Run);
end;

procedure TRealLibraryTests.SourcesCanBeCreatedAndFreed;
begin
  TUpdateSource.FromFile(GetTempDir).Free;
  TUpdateSource.FromHttpUrl('https://example.invalid/releases').Free;
  TUpdateSource.FromGitHub('https://github.com/velopack/velopack').Free;
end;

type
  { Serves a one-package feed from memory and "downloads" it by writing the
    package bytes. SHA-1/SHA-256/size are those of the five bytes 'hello', so
    the real library's checksum verification accepts the result. }
  TMemoryFeed = class
  public
    FeedName: string;
    DownloadedTo: string;
    Progress: string;
    function GetFeed(Sender: TObject; const AReleasesName: string): string;
    function Download(Sender: TObject; const AAsset: TVelopackAsset;
      const ALocalPath: string; AProgressId: TVelopackProgressId): Boolean;
    procedure OnProgress(Sender: TObject; Percent: Integer);
  end;

const
  PackageBytes = 'hello';
  MemoryFeedJson =
    '{"Assets":[{"PackageId":"VpkPasTestApp","Version":"2.0.0","Type":"Full",' +
    '"FileName":"VpkPasTestApp-2.0.0-full.nupkg",' +
    '"SHA1":"aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d",' +
    '"SHA256":"2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",' +
    '"Size":5,"NotesMarkdown":"","NotesHtml":""}]}';

function TMemoryFeed.GetFeed(Sender: TObject; const AReleasesName: string): string;
begin
  FeedName := AReleasesName;
  Result := MemoryFeedJson;
end;

function TMemoryFeed.Download(Sender: TObject; const AAsset: TVelopackAsset;
  const ALocalPath: string; AProgressId: TVelopackProgressId): Boolean;
var
  F: TFileStream;
begin
  DownloadedTo := ALocalPath;
  F := TFileStream.Create(ALocalPath, fmCreate);
  try
    F.WriteBuffer(PackageBytes[1], Length(PackageBytes));
  finally
    F.Free;
  end;
  (Sender as TCustomUpdateSource).ReportProgress(AProgressId, 50);
  // The native library polls for progress every 50 ms and stops as soon as the
  // download has finished, dropping progress that was not yet delivered. Make
  // the download last long enough for the reported progress to arrive.
  Sleep(400);
  Result := True;
end;

procedure TMemoryFeed.OnProgress(Sender: TObject; Percent: Integer);
begin
  Progress := Progress + IntToStr(Percent) + ';';
end;

var
  GTempRoots: array of string;

procedure RemoveTree(const ADir: string);
var
  SR: TSearchRec;
begin
  if FindFirst(IncludeTrailingPathDelimiter(ADir) + '*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faDirectory) <> 0 then
        RemoveTree(IncludeTrailingPathDelimiter(ADir) + SR.Name)
      else
        DeleteFile(IncludeTrailingPathDelimiter(ADir) + SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
  RemoveDir(ADir);
end;

procedure RemoveTestRoots;
var
  I: Integer;
begin
  for I := 0 to High(GTempRoots) do
    RemoveTree(GTempRoots[I]);
  GTempRoots := nil;
end;

{ A throw-away "installation": the manifest fixture plus empty directories.
  The directory name is unique per call; a package left over from an earlier
  run would make the library skip the download it is supposed to perform. }
function MakeTestLocator: TVelopackLocator;
var
  Root: string;
begin
  Root := IncludeTrailingPathDelimiter(GetTempDir) + 'vpkpas-' +
    FormatDateTime('yyyymmddhhnnsszzz', Now) + '-' + IntToStr(Random(1000000));
  SetLength(GTempRoots, Length(GTempRoots) + 1);
  GTempRoots[High(GTempRoots)] := Root;
  ForceDirectories(Root + PathDelim + 'packages');
  ForceDirectories(Root + PathDelim + 'current');
  Result.RootAppDir := Root;
  Result.UpdateExePath := Root + PathDelim + 'Update.exe';
  Result.PackagesDir := Root + PathDelim + 'packages';
  Result.CurrentBinaryDir := Root + PathDelim + 'current';
  Result.ManifestPath := ExpandFileName('tests/fixtures/VpkPasTestApp.nuspec');
  Result.IsPortable := True;
  with TStringList.Create do
  try
    SaveToFile(Result.UpdateExePath);
  finally
    Free;
  end;
end;

procedure TRealLibraryTests.ManagerWithLocatorReadsTheManifest;
var
  M: TUpdateManager;
begin
  M := TUpdateManager.Create(GetTempDir, DefaultUpdateOptions, MakeTestLocator);
  try
    CheckEquals('VpkPasTestApp', M.AppId);
    CheckEquals('1.0.0', M.CurrentVersion);
    CheckTrue(M.IsPortable);
  finally
    M.Free;
  end;
end;

procedure TRealLibraryTests.CustomSourceDrivesCheckAndDownload;
var
  Feed: TMemoryFeed;
  Src: TCustomUpdateSource;
  M: TUpdateManager;
  Info: TUpdateInfo;
begin
  Feed := TMemoryFeed.Create;
  Src := TCustomUpdateSource.Create;
  try
    Src.OnGetReleaseFeed := Feed.GetFeed;
    Src.OnDownloadAsset := Feed.Download;
    M := TUpdateManager.CreateWithSource(Src, DefaultUpdateOptions, MakeTestLocator);
    try
      M.OnProgress := Feed.OnProgress;
      CheckTrue(M.CheckForUpdates(Info) = ucUpdateAvailable,
        'the real library must parse the feed and find 2.0.0 > 1.0.0');
      try
        CheckEquals('releases.stable.json', Feed.FeedName);
        CheckEquals('2.0.0', Info.TargetFullRelease.Version);
        CheckEquals('Full', Info.TargetFullRelease.AssetType);
        CheckEquals(5, Integer(Info.TargetFullRelease.Size));
        M.DownloadUpdates(Info);
      finally
        Info.Free;
      end;
      CheckTrue(Feed.DownloadedTo <> '', 'download callback must have run');
      CheckEquals('', Src.LastCallbackError);
      CheckTrue(Pos('50;', Feed.Progress) > 0,
        'progress reported by the callback must arrive: ' + Feed.Progress);
      // UpdatePendingRestart is not checked: the library opens the downloaded
      // file as a real package archive, and the five test bytes are not one.
    finally
      M.Free;
    end;
  finally
    Src.Free;
    Feed.Free;
  end;
end;

initialization
  Randomize;
  if GetEnvironmentVariable(ENV_REAL_LIB) <> '' then
    RegisterTest(TRealLibraryTests);
end.
