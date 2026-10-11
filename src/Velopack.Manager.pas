{ velopack-pas - update manager, update sources and update info.

  Typical use:

    Manager := TUpdateManager.Create('https://example.com/releases');
    try
      if Manager.CheckForUpdates(Info) = ucUpdateAvailable then
      try
        Manager.DownloadUpdates(Info);
        Manager.WaitExitThenApplyUpdates(Info.TargetFullRelease);
        // ...then exit the application
      finally
        Info.Free;
      end;
    finally
      Manager.Free;
    end;

  All calls are synchronous and run on the calling thread (ADR 0006). }
unit Velopack.Manager;

{$I Velopack.Compat.inc}

interface

uses
  SysUtils, Velopack.Types, Velopack.Native;

type
  { A location updates are fetched from. Create it with one of the class
    functions and pass it to TUpdateManager.CreateWithSource. The source may be
    freed right after the manager has been created. }
  TUpdateSource = class
  private
    FHandle: Pvpkc_update_source_t;
  public
    { Internal: use the From* class functions instead. }
    constructor CreateFromHandle(AHandle: Pvpkc_update_source_t);
    destructor Destroy; override;
    { Local directory containing releases. }
    class function FromFile(const APath: string): TUpdateSource;
    class function FromHttpUrl(const AUrl: string): TUpdateSource;
    class function FromGitHub(const ARepoUrl: string; const AAccessToken: string = '';
      APrerelease: Boolean = False): TUpdateSource;
    class function FromGitLab(const ARepoUrl: string; const AAccessToken: string = '';
      APrerelease: Boolean = False): TUpdateSource;
    class function FromGitea(const ARepoUrl: string; const AAccessToken: string = '';
      APrerelease: Boolean = False): TUpdateSource;
    class function FromVelopackFlow(const ABaseUri: string = ''): TUpdateSource;
  end;

  { Result of a successful update check. Owns the native data; free it when
    done. Strings are copied, so the Pascal values stay valid after Free. }
  TUpdateInfo = class
  private
    FNative: Pvpkc_update_info_t;
    FTargetFullRelease: TVelopackAsset;
    FBaseRelease: TVelopackAsset;
    FHasBaseRelease: Boolean;
    FDeltasToTarget: TVelopackAssetArray;
    FIsDowngrade: Boolean;
  public
    { Internal: instances are created by TUpdateManager.CheckForUpdates. }
    constructor CreateFromNative(ANative: Pvpkc_update_info_t);
    destructor Destroy; override;
    { The version we are updating to. }
    property TargetFullRelease: TVelopackAsset read FTargetFullRelease;
    { Base of a delta update, only meaningful if HasBaseRelease is True. }
    property BaseRelease: TVelopackAsset read FBaseRelease;
    property HasBaseRelease: Boolean read FHasBaseRelease;
    property DeltasToTarget: TVelopackAssetArray read FDeltasToTarget;
    property IsDowngrade: Boolean read FIsDowngrade;
  end;

  TUpdateManager = class
  private
    FHandle: Pvpkc_update_manager_t;
    FOnProgress: TVelopackProgressEvent;
    FCurrentVersion: string;
    FAppId: string;
    FIsPortable: Boolean;
    procedure Initialize;
  public
    { Fetches updates from a URL or a local directory. }
    constructor Create(const AUrlOrPath: string); overload;
    constructor Create(const AUrlOrPath: string; const AOptions: TUpdateOptions); overload;
    { Fetches updates from the hosted Velopack Flow service. }
    constructor CreateFlow(const AOptions: TUpdateOptions);
    { Uses a custom source. The source can be freed afterwards. }
    constructor CreateWithSource(ASource: TUpdateSource); overload;
    constructor CreateWithSource(ASource: TUpdateSource; const AOptions: TUpdateOptions); overload;
    destructor Destroy; override;

    { Returns True and the asset if an update was already downloaded and only
      waits for a restart. }
    function UpdatePendingRestart(out AAsset: TVelopackAsset): Boolean;

    { Checks for updates. AInfo is nil unless the result is ucUpdateAvailable;
      the caller owns a non-nil AInfo. Raises EVelopackError on failure. }
    function CheckForUpdates(out AInfo: TUpdateInfo): TUpdateCheckResult;

    { Downloads (and prepares) the update. Progress is reported through
      OnProgress on the calling thread. Raises EVelopackError on failure. }
    procedure DownloadUpdates(AInfo: TUpdateInfo);

    { Launches the updater, which waits for this process to exit, applies the
      update and optionally restarts the application. The caller must exit
      the application afterwards. }
    procedure WaitExitThenApplyUpdates(const AAsset: TVelopackAsset;
      ASilent: Boolean = False; ARestart: Boolean = True); overload;
    procedure WaitExitThenApplyUpdates(const AAsset: TVelopackAsset;
      ASilent, ARestart: Boolean; const ARestartArgs: array of string); overload;

    property CurrentVersion: string read FCurrentVersion;
    property AppId: string read FAppId;
    property IsPortable: Boolean read FIsPortable;
    property OnProgress: TVelopackProgressEvent read FOnProgress write FOnProgress;
  end;

implementation

uses
  Velopack.Strings, Velopack.Internal;

{ ---- TUpdateSource ---- }

constructor TUpdateSource.CreateFromHandle(AHandle: Pvpkc_update_source_t);
begin
  inherited Create;
  FHandle := AHandle;
end;

destructor TUpdateSource.Destroy;
begin
  if (FHandle <> nil) and Assigned(vpkc_free_source) then
    vpkc_free_source(FHandle);
  inherited Destroy;
end;

function CheckSource(AHandle: Pvpkc_update_source_t): TUpdateSource;
begin
  if AHandle = nil then
    RaiseLastNativeError('Cannot create update source');
  Result := TUpdateSource.CreateFromHandle(AHandle);
end;

class function TUpdateSource.FromFile(const APath: string): TUpdateSource;
var
  Path: UTF8String;
begin
  VpkcLoad;
  Path := ToUtf8(APath);
  Result := CheckSource(vpkc_new_source_file(PAnsiChar(Path)));
end;

class function TUpdateSource.FromHttpUrl(const AUrl: string): TUpdateSource;
var
  Url: UTF8String;
begin
  VpkcLoad;
  Url := ToUtf8(AUrl);
  Result := CheckSource(vpkc_new_source_http_url(PAnsiChar(Url)));
end;

class function TUpdateSource.FromGitHub(const ARepoUrl, AAccessToken: string;
  APrerelease: Boolean): TUpdateSource;
var
  Url, Token: UTF8String;
begin
  VpkcLoad;
  Url := ToUtf8(ARepoUrl);
  Token := ToUtf8(AAccessToken);
  Result := CheckSource(vpkc_new_source_github(PAnsiChar(Url),
    PUtf8OrNil(Token), APrerelease));
end;

class function TUpdateSource.FromGitLab(const ARepoUrl, AAccessToken: string;
  APrerelease: Boolean): TUpdateSource;
var
  Url, Token: UTF8String;
begin
  VpkcLoad;
  Url := ToUtf8(ARepoUrl);
  Token := ToUtf8(AAccessToken);
  Result := CheckSource(vpkc_new_source_gitlab(PAnsiChar(Url),
    PUtf8OrNil(Token), APrerelease));
end;

class function TUpdateSource.FromGitea(const ARepoUrl, AAccessToken: string;
  APrerelease: Boolean): TUpdateSource;
var
  Url, Token: UTF8String;
begin
  VpkcLoad;
  Url := ToUtf8(ARepoUrl);
  Token := ToUtf8(AAccessToken);
  Result := CheckSource(vpkc_new_source_gitea(PAnsiChar(Url),
    PUtf8OrNil(Token), APrerelease));
end;

class function TUpdateSource.FromVelopackFlow(const ABaseUri: string): TUpdateSource;
var
  Uri: UTF8String;
begin
  VpkcLoad;
  Uri := ToUtf8(ABaseUri);
  Result := CheckSource(vpkc_new_source_velopack_flow(PUtf8OrNil(Uri)));
end;

{ ---- TUpdateInfo ---- }

type
  TAssetPtrArray = array[0..(MaxInt div SizeOf(Pointer)) - 1] of Pvpkc_asset_t;
  PAssetPtrArray = ^TAssetPtrArray;

constructor TUpdateInfo.CreateFromNative(ANative: Pvpkc_update_info_t);
var
  I: Integer;
  Deltas: PAssetPtrArray;
begin
  inherited Create;
  FNative := ANative;
  if ANative^.TargetFullRelease <> nil then
    FTargetFullRelease := AssetFromNative(ANative^.TargetFullRelease);
  FHasBaseRelease := ANative^.BaseRelease <> nil;
  if FHasBaseRelease then
    FBaseRelease := AssetFromNative(ANative^.BaseRelease);
  FIsDowngrade := ANative^.IsDowngrade;
  SetLength(FDeltasToTarget, ANative^.DeltasToTargetCount);
  Deltas := PAssetPtrArray(ANative^.DeltasToTarget);
  for I := 0 to High(FDeltasToTarget) do
    FDeltasToTarget[I] := AssetFromNative(Deltas^[I]);
end;

destructor TUpdateInfo.Destroy;
begin
  if (FNative <> nil) and Assigned(vpkc_free_update_info) then
    vpkc_free_update_info(FNative);
  inherited Destroy;
end;

{ ---- TUpdateManager ---- }

type
  { Passed through the native progress callback as user data. }
  PProgressContext = ^TProgressContext;
  TProgressContext = record
    Sender: TObject;
    Handler: TVelopackProgressEvent;
  end;

procedure NativeProgress(p_user_data: Pointer; progress: vpkc_size_t); cdecl;
var
  Ctx: PProgressContext;
begin
  Ctx := PProgressContext(p_user_data);
  // Exceptions must never cross the native boundary.
  try
    if (Ctx <> nil) and Assigned(Ctx^.Handler) then
      Ctx^.Handler(Ctx^.Sender, Integer(progress));
  except
  end;
end;

procedure TUpdateManager.Initialize;
begin
  FCurrentVersion := ReadNativeString(vpkc_get_current_version, FHandle);
  FAppId := ReadNativeString(vpkc_get_app_id, FHandle);
  FIsPortable := vpkc_is_portable(FHandle);
end;

constructor TUpdateManager.Create(const AUrlOrPath: string);
begin
  Create(AUrlOrPath, DefaultUpdateOptions);
end;

constructor TUpdateManager.Create(const AUrlOrPath: string;
  const AOptions: TUpdateOptions);
var
  Url, Channel: UTF8String;
  NativeOptions: vpkc_update_options_t;
begin
  inherited Create;
  VpkcLoad;
  Url := ToUtf8(AUrlOrPath);
  Channel := ToUtf8(AOptions.ExplicitChannel);
  FillNativeOptions(AOptions, Channel, NativeOptions);
  if not vpkc_new_update_manager(PAnsiChar(Url), @NativeOptions, nil, @FHandle) then
    RaiseLastNativeError('Cannot create update manager');
  Initialize;
end;

constructor TUpdateManager.CreateFlow(const AOptions: TUpdateOptions);
var
  Channel: UTF8String;
  NativeOptions: vpkc_update_options_t;
begin
  inherited Create;
  VpkcLoad;
  Channel := ToUtf8(AOptions.ExplicitChannel);
  FillNativeOptions(AOptions, Channel, NativeOptions);
  if not vpkc_new_update_manager_flow(@NativeOptions, nil, @FHandle) then
    RaiseLastNativeError('Cannot create update manager');
  Initialize;
end;

constructor TUpdateManager.CreateWithSource(ASource: TUpdateSource);
begin
  CreateWithSource(ASource, DefaultUpdateOptions);
end;

constructor TUpdateManager.CreateWithSource(ASource: TUpdateSource;
  const AOptions: TUpdateOptions);
var
  Channel: UTF8String;
  NativeOptions: vpkc_update_options_t;
begin
  inherited Create;
  VpkcLoad;
  Channel := ToUtf8(AOptions.ExplicitChannel);
  FillNativeOptions(AOptions, Channel, NativeOptions);
  if not vpkc_new_update_manager_with_source(ASource.FHandle, @NativeOptions,
    nil, @FHandle) then
    RaiseLastNativeError('Cannot create update manager');
  Initialize;
end;

destructor TUpdateManager.Destroy;
begin
  if (FHandle <> nil) and Assigned(vpkc_free_update_manager) then
    vpkc_free_update_manager(FHandle);
  inherited Destroy;
end;

function TUpdateManager.UpdatePendingRestart(out AAsset: TVelopackAsset): Boolean;
var
  Native: Pvpkc_asset_t;
begin
  Native := nil;
  Result := vpkc_update_pending_restart(FHandle, @Native);
  if Result and (Native <> nil) then
  try
    AAsset := AssetFromNative(Native);
  finally
    vpkc_free_asset(Native);
  end
  else
    AAsset := Default(TVelopackAsset);
end;

function TUpdateManager.CheckForUpdates(out AInfo: TUpdateInfo): TUpdateCheckResult;
var
  Native: Pvpkc_update_info_t;
begin
  AInfo := nil;
  Native := nil;
  case vpkc_check_for_updates(FHandle, @Native) of
    UPDATE_AVAILABLE:
      begin
        if Native = nil then
          raise EVelopackError.Create('Velopack reported an update but returned no data');
        AInfo := TUpdateInfo.CreateFromNative(Native);
        Result := ucUpdateAvailable;
      end;
    NO_UPDATE_AVAILABLE:
      Result := ucNoUpdateAvailable;
    REMOTE_IS_EMPTY:
      Result := ucRemoteIsEmpty;
  else
    RaiseLastNativeError('Update check failed');
    Result := ucNoUpdateAvailable; // not reached
  end;
end;

procedure TUpdateManager.DownloadUpdates(AInfo: TUpdateInfo);
var
  Ctx: TProgressContext;
  Callback: vpkc_progress_callback_t;
begin
  Ctx.Sender := Self;
  Ctx.Handler := FOnProgress;
  if Assigned(FOnProgress) then
    Callback := @NativeProgress
  else
    Callback := nil;
  if not vpkc_download_updates(FHandle, AInfo.FNative, Callback, @Ctx) then
    RaiseLastNativeError('Download failed');
end;

procedure TUpdateManager.WaitExitThenApplyUpdates(const AAsset: TVelopackAsset;
  ASilent, ARestart: Boolean);
begin
  WaitExitThenApplyUpdates(AAsset, ASilent, ARestart, []);
end;

procedure TUpdateManager.WaitExitThenApplyUpdates(const AAsset: TVelopackAsset;
  ASilent, ARestart: Boolean; const ARestartArgs: array of string);
var
  Holder: TNativeAssetHolder;
  Args: array of UTF8String;
  ArgPtrs: array of PAnsiChar;
  I: Integer;
  ArgsPtr: PPAnsiChar;
begin
  SetLength(Args, Length(ARestartArgs));
  SetLength(ArgPtrs, Length(ARestartArgs));
  for I := 0 to High(ARestartArgs) do
  begin
    Args[I] := ToUtf8(ARestartArgs[I]);
    ArgPtrs[I] := PAnsiChar(Args[I]);
  end;
  if Length(ArgPtrs) > 0 then
    ArgsPtr := @ArgPtrs[0]
  else
    ArgsPtr := nil;
  Holder := TNativeAssetHolder.Create(AAsset);
  try
    if not vpkc_wait_exit_then_apply_updates(FHandle, Holder.Native, ASilent,
      ARestart, ArgsPtr, Length(ArgPtrs)) then
      RaiseLastNativeError('Cannot start the updater');
  finally
    Holder.Free;
  end;
end;

end.
