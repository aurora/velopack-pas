{ velopack-pas - update sources implemented in Pascal.

  Use this when releases do not live on a plain HTTP server, a directory, or a
  supported forge: private storage, an API with its own authentication, a
  database, a corporate proxy with special rules. Velopack asks the source for
  two things and does everything else (version comparison, delta handling,
  checksums, applying) itself:

    1. the release feed: a JSON document with an "Assets" array for
       "releases.<channel>.json" (see GetReleaseFeed), and
    2. the download of one package file to a local path (see DownloadAsset).

  Either derive from TCustomUpdateSource and override the two methods, or
  create an instance and assign the OnGetReleaseFeed / OnDownloadAsset events:

    Source := TCustomUpdateSource.Create;
    Source.OnGetReleaseFeed := HandleFeed;
    Source.OnDownloadAsset := HandleDownload;
    Manager := TUpdateManager.CreateWithSource(Source);

  Lifetime: the native library keeps calling into the source for as long as a
  manager that uses it exists. Keep the source alive at least that long. If it
  is freed earlier, the callbacks fail cleanly (the update check or download
  raises EVelopackError) instead of crashing.

  Threading (observed with the real library): the release feed callback runs
  on the thread that called CheckForUpdates, but DownloadAsset runs on a worker
  thread that the native library creates, while the calling thread waits.
  Never touch GUI controls from either callback. Free Pascal programs on Unix
  must link cthreads (Lazarus applications do) so the RTL is thread-safe. A
  running callback blocks the destruction of its source.

  Progress: the library forwards progress (0 and 100 plus whatever
  ReportProgress sends) by polling every 50 ms and stops polling when the
  download is done. Progress of very fast downloads may therefore not arrive.

  Exceptions never cross the native boundary: they are caught, stored in
  LastCallbackError, and reported to Velopack as a failure. }
unit Velopack.CustomSource;

{$I Velopack.Compat.inc}

interface

uses
  SysUtils, Velopack.Types, Velopack.Manager;

type
  { Identifies one running download for ReportProgress. Only valid while the
    download callback is running. }
  TVelopackProgressId = NativeUInt;

  { Returns the release feed JSON for AReleasesName (for example
    "releases.stable.json"). Raise an exception to report failure. }
  TVelopackFeedEvent = function(Sender: TObject;
    const AReleasesName: string): string of object;

  { Downloads AAsset to ALocalPath. Return True on success; False or an
    exception reports failure. Use TCustomUpdateSource.ReportProgress with
    AProgressId for intermediate progress: Velopack itself reports 0 before
    and 100 after the callback. }
  TVelopackDownloadEvent = function(Sender: TObject; const AAsset: TVelopackAsset;
    const ALocalPath: string; AProgressId: TVelopackProgressId): Boolean of object;

  TCustomUpdateSource = class(TUpdateSource)
  private
    { Opaque: the native library holds a pointer to this context, not to the
      source, so the callbacks stay safe when the source is freed before the
      manager that uses it. }
    FContext: TObject;
    FLastCallbackError: string;
    FOnGetReleaseFeed: TVelopackFeedEvent;
    FOnDownloadAsset: TVelopackDownloadEvent;
  protected
    { Default: calls OnGetReleaseFeed, raises if it is not assigned. }
    function GetReleaseFeed(const AReleasesName: string): string; virtual;
    { Default: calls OnDownloadAsset, raises if it is not assigned. }
    function DownloadAsset(const AAsset: TVelopackAsset;
      const ALocalPath: string; AProgressId: TVelopackProgressId): Boolean; virtual;
  public
    constructor Create;
    destructor Destroy; override;

    { Reports download progress (0..100) from inside DownloadAsset. }
    procedure ReportProgress(AProgressId: TVelopackProgressId; APercent: Integer);

    { Message of the last exception that a callback swallowed, '' if none. }
    property LastCallbackError: string read FLastCallbackError;
    property OnGetReleaseFeed: TVelopackFeedEvent read FOnGetReleaseFeed
      write FOnGetReleaseFeed;
    property OnDownloadAsset: TVelopackDownloadEvent read FOnDownloadAsset
      write FOnDownloadAsset;
  end;

implementation

uses
  SyncObjs, Velopack.Native, Velopack.Strings, Velopack.Internal;

type
  TSourceContext = class
  public
    Lock: TCriticalSection;
    Owner: TCustomUpdateSource;
  end;

var
  { Contexts are tiny and must outlive their source (the native library may
    still call back after the source object is gone), so they are released at
    program exit instead. }
  GContexts: array of TSourceContext;

function NewContext(AOwner: TCustomUpdateSource): TSourceContext;
begin
  Result := TSourceContext.Create;
  Result.Lock := TCriticalSection.Create;
  Result.Owner := AOwner;
  SetLength(GContexts, Length(GContexts) + 1);
  GContexts[High(GContexts)] := Result;
end;

{ ---- native callbacks. Exceptions must never cross the native boundary. ---- }

function CopyToCString(const AUtf8: UTF8String): PAnsiChar;
begin
  GetMem(Result, Length(AUtf8) + 1);
  if Length(AUtf8) > 0 then
    Move(Pointer(AUtf8)^, Result^, Length(AUtf8));
  Result[Length(AUtf8)] := #0;
end;

function NativeGetFeed(p_user_data: Pointer;
  psz_releases_name: PAnsiChar): PAnsiChar; cdecl;
var
  Ctx: TSourceContext;
begin
  Result := nil;
  Ctx := TSourceContext(p_user_data);
  Ctx.Lock.Acquire;
  try
    if Ctx.Owner = nil then
      Exit; // the source is gone: fail instead of calling a dead object
    try
      Result := CopyToCString(ToUtf8(
        Ctx.Owner.GetReleaseFeed(FromUtf8(psz_releases_name))));
    except
      on E: Exception do
      begin
        Result := nil;
        Ctx.Owner.FLastCallbackError := E.Message;
      end;
    end;
  finally
    Ctx.Lock.Release;
  end;
end;

procedure NativeFreeFeed(p_user_data: Pointer; psz_feed: PAnsiChar); cdecl;
begin
  // Allocated by CopyToCString; the context is not needed to release it.
  if psz_feed <> nil then
    FreeMem(psz_feed);
end;

function NativeDownload(p_user_data: Pointer; p_asset: Pvpkc_asset_t;
  psz_local_path: PAnsiChar; progress_callback_id: vpkc_size_t): vpkc_bool; cdecl;
var
  Ctx: TSourceContext;
begin
  Result := False;
  Ctx := TSourceContext(p_user_data);
  Ctx.Lock.Acquire;
  try
    if Ctx.Owner = nil then
      Exit;
    try
      Result := Ctx.Owner.DownloadAsset(AssetFromNative(p_asset),
        FromUtf8(psz_local_path), progress_callback_id);
    except
      on E: Exception do
      begin
        Result := False;
        Ctx.Owner.FLastCallbackError := E.Message;
      end;
    end;
  finally
    Ctx.Lock.Release;
  end;
end;

{ ---- TCustomUpdateSource ---- }

constructor TCustomUpdateSource.Create;
var
  Handle: Pvpkc_update_source_t;
begin
  VpkcLoad;
  // The native library calls back from threads it created itself.
  IsMultiThread := True;
  FContext := NewContext(Self);
  Handle := vpkc_new_source_custom_callback(@NativeGetFeed, @NativeFreeFeed,
    @NativeDownload, FContext);
  if Handle = nil then
  begin
    TSourceContext(FContext).Owner := nil;
    RaiseLastNativeError('Cannot create custom update source');
  end;
  inherited CreateFromHandle(Handle);
end;

destructor TCustomUpdateSource.Destroy;
begin
  if FContext <> nil then
  begin
    // Waits for a callback that is running right now, then makes all later
    // callbacks fail cleanly.
    TSourceContext(FContext).Lock.Acquire;
    try
      TSourceContext(FContext).Owner := nil;
    finally
      TSourceContext(FContext).Lock.Release;
    end;
  end;
  inherited Destroy;
end;

function TCustomUpdateSource.GetReleaseFeed(const AReleasesName: string): string;
begin
  if not Assigned(FOnGetReleaseFeed) then
    raise EVelopackError.Create(
      'No release feed provider: assign OnGetReleaseFeed or override GetReleaseFeed');
  Result := FOnGetReleaseFeed(Self, AReleasesName);
end;

function TCustomUpdateSource.DownloadAsset(const AAsset: TVelopackAsset;
  const ALocalPath: string; AProgressId: TVelopackProgressId): Boolean;
begin
  if not Assigned(FOnDownloadAsset) then
    raise EVelopackError.Create(
      'No download provider: assign OnDownloadAsset or override DownloadAsset');
  Result := FOnDownloadAsset(Self, AAsset, ALocalPath, AProgressId);
end;

procedure TCustomUpdateSource.ReportProgress(AProgressId: TVelopackProgressId;
  APercent: Integer);
begin
  if APercent < 0 then
    APercent := 0
  else if APercent > 100 then
    APercent := 100;
  if Assigned(vpkc_source_report_progress) then
    vpkc_source_report_progress(AProgressId, SmallInt(APercent));
end;

procedure FreeContexts;
var
  I: Integer;
begin
  for I := 0 to High(GContexts) do
  begin
    GContexts[I].Lock.Free;
    GContexts[I].Free;
  end;
  GContexts := nil;
end;

initialization

finalization
  FreeContexts;

end.
