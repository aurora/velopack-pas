{ velopack-pas - public value types shared by the object API.

  Contains no native pointers: everything here is plain Pascal data, so users
  never have to manage native memory. }
unit Velopack.Types;

{$I Velopack.Compat.inc}

interface

uses
  SysUtils;

type
  { Base class of all errors raised by this library. }
  EVelopackError = class(Exception);

  { Raised when the native Velopack library cannot be loaded or does not
    export the expected functions. }
  EVelopackLibraryError = class(EVelopackError);

  { Result of an update check (errors are raised as EVelopackError). }
  TUpdateCheckResult = (
    ucUpdateAvailable,
    ucNoUpdateAvailable,
    ucRemoteIsEmpty
  );

  { A single release package, either local or on a remote feed. }
  TVelopackAsset = record
    PackageId: string;
    Version: string;
    { "Full" or "Delta". }
    AssetType: string;
    FileName: string;
    SHA1: string;
    SHA256: string;
    Size: UInt64;
    NotesMarkdown: string;
    NotesHtml: string;
  end;

  TVelopackAssetArray = array of TVelopackAsset;

  { Options that customize the update manager. }
  TUpdateOptions = record
    { Allow updating to a version lower than the current one. }
    AllowVersionDowngrade: Boolean;
    { Overrides the release channel. Leave empty for the default channel. }
    ExplicitChannel: string;
    { Maximum number of deltas before falling back to a full download.
      Negative values disable delta updates. }
    MaximumDeltasBeforeFallback: Integer;
  end;

  { Explicit application paths. Normally Velopack locates them itself from the
    running executable of an installed app; set them to use the update manager
    outside an installation (tests, portable layouts, custom hosts). }
  TVelopackLocator = record
    { Root directory of the app (on Linux the path of the AppImage). }
    RootAppDir: string;
    UpdateExePath: string;
    PackagesDir: string;
    { Path of the app manifest (a .nuspec / sq.version file). }
    ManifestPath: string;
    CurrentBinaryDir: string;
    IsPortable: Boolean;
  end;

  { Download progress, 0..100. Invoked on the thread that runs the download. }
  TVelopackProgressEvent = procedure(Sender: TObject; Percent: Integer) of object;

  { Startup hook. Receives the version of the running application. }
  TVelopackHook = procedure(const AppVersion: string);

  { Receives log messages of the native library. }
  TVelopackLogEvent = procedure(const Level, Message: string);

{ Default options: no downgrade, default channel, up to 10 deltas. }
function DefaultUpdateOptions: TUpdateOptions;

implementation

function DefaultUpdateOptions: TUpdateOptions;
begin
  Result.AllowVersionDowngrade := False;
  Result.ExplicitChannel := '';
  Result.MaximumDeltasBeforeFallback := 10;
end;

end.
