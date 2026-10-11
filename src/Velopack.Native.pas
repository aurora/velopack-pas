{ velopack-pas - 1:1 Pascal translation of Velopack.h plus a dynamic loader.

  This unit mirrors third_party/velopack/Velopack.h. Names are kept identical
  to the C header on purpose, so changes upstream are easy to diff. Application
  code should normally use Velopack.App and Velopack.Manager instead.

  All functions are resolved at run time (see docs/adr/0004). Before calling
  any vpkc_* variable, call VpkcLoad or check VpkcTryLoad. }
unit Velopack.Native;

{$I Velopack.Compat.inc}

interface

uses
  SysUtils;

const
  { Default file name of the native library: the cdylib of the Velopack crate
    "velopack_libc" (src/lib-cpp). Override with VpkcLibraryName or the
    VELOPACK_LIBRARY environment variable. }
{$IFDEF VPK_WINDOWS}
  VPKC_DEFAULT_LIBRARY = 'velopack_libc.dll';
{$ELSE}
  {$IFDEF VPK_MACOS}
  VPKC_DEFAULT_LIBRARY = 'libvelopack_libc.dylib';
  {$ELSE}
  VPKC_DEFAULT_LIBRARY = 'libvelopack_libc.so';
  {$ENDIF}
{$ENDIF}

  VPKC_LIBRARY_ENV_VAR = 'VELOPACK_LIBRARY';

  { vpkc_update_check_t values. }
  UPDATE_ERROR = -1;
  UPDATE_AVAILABLE = 0;
  NO_UPDATE_AVAILABLE = 1;
  REMOTE_IS_EMPTY = 2;

type
  { C "bool" is one byte that must be exactly 0 or 1. Do NOT use ByteBool:
    its True is 255, which is undefined behavior for C / Rust bool. }
  vpkc_bool = Boolean;
  vpkc_size_t = NativeUInt;

  vpkc_update_check_t = Int8;

  { Opaque handles (void* in C). }
  Pvpkc_update_source_t = Pointer;
  Pvpkc_update_manager_t = Pointer;
  PPvpkc_update_manager_t = ^Pvpkc_update_manager_t;

  Pvpkc_http_header_t = ^vpkc_http_header_t;
  PPvpkc_http_header_t = ^Pvpkc_http_header_t;
  vpkc_http_header_t = record
    Name: PAnsiChar;
    Value: PAnsiChar;
  end;

  Pvpkc_http_options_t = ^vpkc_http_options_t;
  vpkc_http_options_t = record
    Headers: PPvpkc_http_header_t;
    HeadersCount: vpkc_size_t;
    TimeoutMilliseconds: UInt64;
  end;

  Pvpkc_asset_t = ^vpkc_asset_t;
  PPvpkc_asset_t = ^Pvpkc_asset_t;
  vpkc_asset_t = record
    PackageId: PAnsiChar;
    Version: PAnsiChar;
    AssetType: PAnsiChar; { "Type" in C; renamed because it is a Pascal keyword }
    FileName: PAnsiChar;
    SHA1: PAnsiChar;
    SHA256: PAnsiChar;
    Size: UInt64;
    NotesMarkdown: PAnsiChar;
    NotesHtml: PAnsiChar;
  end;

  Pvpkc_update_options_t = ^vpkc_update_options_t;
  vpkc_update_options_t = record
    AllowVersionDowngrade: vpkc_bool;
    ExplicitChannel: PAnsiChar;
    MaximumDeltasBeforeFallback: Int32;
  end;

  Pvpkc_locator_config_t = ^vpkc_locator_config_t;
  vpkc_locator_config_t = record
    RootAppDir: PAnsiChar;
    UpdateExePath: PAnsiChar;
    PackagesDir: PAnsiChar;
    ManifestPath: PAnsiChar;
    CurrentBinaryDir: PAnsiChar;
    IsPortable: vpkc_bool;
  end;

  Pvpkc_update_info_t = ^vpkc_update_info_t;
  PPvpkc_update_info_t = ^Pvpkc_update_info_t;
  vpkc_update_info_t = record
    TargetFullRelease: Pvpkc_asset_t;
    BaseRelease: Pvpkc_asset_t;
    DeltasToTarget: PPvpkc_asset_t;
    DeltasToTargetCount: vpkc_size_t;
    IsDowngrade: vpkc_bool;
  end;

  { Callback types. All are cdecl. Exceptions must never escape them. }
  vpkc_release_feed_delegate_t = function(p_user_data: Pointer;
    psz_releases_name: PAnsiChar): PAnsiChar; cdecl;
  vpkc_free_release_feed_t = procedure(p_user_data: Pointer;
    psz_feed: PAnsiChar); cdecl;
  vpkc_download_asset_delegate_t = function(p_user_data: Pointer;
    p_asset: Pvpkc_asset_t; psz_local_path: PAnsiChar;
    progress_callback_id: vpkc_size_t): vpkc_bool; cdecl;
  vpkc_progress_callback_t = procedure(p_user_data: Pointer;
    progress: vpkc_size_t); cdecl;
  vpkc_hook_callback_t = procedure(p_user_data: Pointer;
    psz_app_version: PAnsiChar); cdecl;
  vpkc_log_callback_t = procedure(p_user_data: Pointer;
    psz_level: PAnsiChar; psz_message: PAnsiChar); cdecl;

var
  { ---- update sources ---- }
  vpkc_new_source_file: function(psz_file_path: PAnsiChar): Pvpkc_update_source_t; cdecl;
  vpkc_new_source_http_url: function(psz_http_url: PAnsiChar): Pvpkc_update_source_t; cdecl;
  vpkc_new_source_http_url_with_options: function(psz_http_url: PAnsiChar;
    p_options: Pvpkc_http_options_t): Pvpkc_update_source_t; cdecl;
  vpkc_new_source_github: function(psz_repo_url, psz_access_token: PAnsiChar;
    b_prerelease: vpkc_bool): Pvpkc_update_source_t; cdecl;
  vpkc_new_source_gitlab: function(psz_repo_url, psz_access_token: PAnsiChar;
    b_prerelease: vpkc_bool): Pvpkc_update_source_t; cdecl;
  vpkc_new_source_gitea: function(psz_repo_url, psz_access_token: PAnsiChar;
    b_prerelease: vpkc_bool): Pvpkc_update_source_t; cdecl;
  vpkc_new_source_velopack_flow: function(psz_base_uri: PAnsiChar): Pvpkc_update_source_t; cdecl;
  vpkc_new_source_custom_callback: function(
    cb_release_feed: vpkc_release_feed_delegate_t;
    cb_free_release_feed: vpkc_free_release_feed_t;
    cb_download_entry: vpkc_download_asset_delegate_t;
    p_user_data: Pointer): Pvpkc_update_source_t; cdecl;
  vpkc_source_report_progress: procedure(progress_callback_id: vpkc_size_t;
    progress: Int16); cdecl;
  vpkc_free_source: procedure(p_source: Pvpkc_update_source_t); cdecl;

  { ---- update manager ---- }
  vpkc_new_update_manager: function(psz_url_or_path: PAnsiChar;
    p_options: Pvpkc_update_options_t; p_locator: Pvpkc_locator_config_t;
    p_manager: PPvpkc_update_manager_t): vpkc_bool; cdecl;
  vpkc_new_update_manager_flow: function(p_options: Pvpkc_update_options_t;
    p_locator: Pvpkc_locator_config_t;
    p_manager: PPvpkc_update_manager_t): vpkc_bool; cdecl;
  vpkc_new_update_manager_with_source: function(p_source: Pvpkc_update_source_t;
    p_options: Pvpkc_update_options_t; p_locator: Pvpkc_locator_config_t;
    p_manager: PPvpkc_update_manager_t): vpkc_bool; cdecl;
  vpkc_get_current_version: function(p_manager: Pvpkc_update_manager_t;
    psz_version: PAnsiChar; c_version: vpkc_size_t): vpkc_size_t; cdecl;
  vpkc_get_app_id: function(p_manager: Pvpkc_update_manager_t;
    psz_id: PAnsiChar; c_id: vpkc_size_t): vpkc_size_t; cdecl;
  vpkc_is_portable: function(p_manager: Pvpkc_update_manager_t): vpkc_bool; cdecl;
  vpkc_update_pending_restart: function(p_manager: Pvpkc_update_manager_t;
    p_asset: PPvpkc_asset_t): vpkc_bool; cdecl;
  vpkc_check_for_updates: function(p_manager: Pvpkc_update_manager_t;
    p_update: PPvpkc_update_info_t): vpkc_update_check_t; cdecl;
  vpkc_download_updates: function(p_manager: Pvpkc_update_manager_t;
    p_update: Pvpkc_update_info_t; cb_progress: vpkc_progress_callback_t;
    p_user_data: Pointer): vpkc_bool; cdecl;
  vpkc_wait_exit_then_apply_updates: function(p_manager: Pvpkc_update_manager_t;
    p_asset: Pvpkc_asset_t; b_silent, b_restart: vpkc_bool;
    p_restart_args: PPAnsiChar; c_restart_args: vpkc_size_t): vpkc_bool; cdecl;
  vpkc_unsafe_apply_updates: function(p_manager: Pvpkc_update_manager_t;
    p_asset: Pvpkc_asset_t; b_silent: vpkc_bool; dw_wait_pid: UInt32;
    b_restart: vpkc_bool; p_restart_args: PPAnsiChar;
    c_restart_args: vpkc_size_t): vpkc_bool; cdecl;
  vpkc_free_update_manager: procedure(p_manager: Pvpkc_update_manager_t); cdecl;
  vpkc_free_update_info: procedure(p_update_info: Pvpkc_update_info_t); cdecl;
  vpkc_free_asset: procedure(p_asset: Pvpkc_asset_t); cdecl;

  { ---- VelopackApp startup hooks ---- }
  vpkc_app_run: procedure(p_user_data: Pointer); cdecl;
  vpkc_app_set_auto_apply_on_startup: procedure(b_auto_apply: vpkc_bool); cdecl;
  vpkc_app_set_args: procedure(p_args: PPAnsiChar; c_args: vpkc_size_t); cdecl;
  vpkc_app_set_locator: procedure(p_locator: Pvpkc_locator_config_t); cdecl;
  vpkc_app_set_hook_after_install: procedure(cb: vpkc_hook_callback_t); cdecl;
  vpkc_app_set_hook_before_uninstall: procedure(cb: vpkc_hook_callback_t); cdecl;
  vpkc_app_set_hook_before_update: procedure(cb: vpkc_hook_callback_t); cdecl;
  vpkc_app_set_hook_after_update: procedure(cb: vpkc_hook_callback_t); cdecl;
  vpkc_app_set_hook_first_run: procedure(cb: vpkc_hook_callback_t); cdecl;
  vpkc_app_set_hook_restarted: procedure(cb: vpkc_hook_callback_t); cdecl;

  { ---- diagnostics ---- }
  vpkc_get_last_error: function(psz_error: PAnsiChar;
    c_error: vpkc_size_t): vpkc_size_t; cdecl;
  vpkc_set_logger: procedure(cb_log: vpkc_log_callback_t;
    p_user_data: Pointer); cdecl;

var
  { Explicit library name or path. Takes precedence over VELOPACK_LIBRARY
    and the default name. Set before the first load. }
  VpkcLibraryName: string = '';

{ Loads the native library and resolves all exports. Raises
  EVelopackLibraryError (declared in Velopack.Types) on failure. Calling it
  again while loaded does nothing. }
procedure VpkcLoad;

{ Like VpkcLoad but returns False instead of raising. The reason is available
  from VpkcLoadError. }
function VpkcTryLoad: Boolean;

{ Unloads the library and resets all function variables to nil. }
procedure VpkcUnload;

function VpkcIsLoaded: Boolean;

{ Message of the last failed load attempt, '' if none. }
function VpkcLoadError: string;

{ Path of the loaded library, '' when not loaded. }
function VpkcLoadedPath: string;

implementation

uses
{$IFDEF FPC}
  DynLibs,
{$ELSE}
  {$IFDEF VPK_WINDOWS}
  Winapi.Windows,
  {$ELSE}
  Posix.Dlfcn,
  {$ENDIF}
{$ENDIF}
  Velopack.Types;

type
  TExport = record
    Name: AnsiString;
    Target: PPointer;
  end;
  TExportArray = array of TExport;
  TStringArray = array of string;

var
  GHandle: {$IFDEF FPC}TLibHandle{$ELSE}NativeUInt{$ENDIF} = 0;
  GLoadError: string = '';
  GLoadedPath: string = '';

{ ---- thin OS abstraction (the only place with dynamic loading calls) ---- }

function OsLoad(const APath: string): {$IFDEF FPC}TLibHandle{$ELSE}NativeUInt{$ENDIF};
begin
{$IFDEF FPC}
  Result := LoadLibrary(APath);
{$ELSE}
  {$IFDEF VPK_WINDOWS}
  Result := LoadLibrary(PChar(APath));
  {$ELSE}
  Result := NativeUInt(dlopen(MarshaledAString(UTF8String(APath)), RTLD_NOW));
  {$ENDIF}
{$ENDIF}
end;

function OsGetProc(AHandle: {$IFDEF FPC}TLibHandle{$ELSE}NativeUInt{$ENDIF};
  const AName: AnsiString): Pointer;
begin
{$IFDEF FPC}
  Result := GetProcedureAddress(AHandle, AName);
{$ELSE}
  {$IFDEF VPK_WINDOWS}
  Result := GetProcAddress(HMODULE(AHandle), PAnsiChar(AName));
  {$ELSE}
  Result := dlsym(Pointer(AHandle), MarshaledAString(AName));
  {$ENDIF}
{$ENDIF}
end;

procedure OsUnload(AHandle: {$IFDEF FPC}TLibHandle{$ELSE}NativeUInt{$ENDIF});
begin
{$IFDEF FPC}
  UnloadLibrary(AHandle);
{$ELSE}
  {$IFDEF VPK_WINDOWS}
  FreeLibrary(HMODULE(AHandle));
  {$ELSE}
  dlclose(Pointer(AHandle));
  {$ENDIF}
{$ENDIF}
end;

{ ---- export table ---- }

function ExportTable: TExportArray;

  procedure Add(var AList: TExportArray; const AName: AnsiString; ATarget: Pointer);
  begin
    SetLength(AList, Length(AList) + 1);
    AList[High(AList)].Name := AName;
    AList[High(AList)].Target := PPointer(ATarget);
  end;

begin
  Result := nil;
  Add(Result, 'vpkc_new_source_file', @@vpkc_new_source_file);
  Add(Result, 'vpkc_new_source_http_url', @@vpkc_new_source_http_url);
  Add(Result, 'vpkc_new_source_http_url_with_options', @@vpkc_new_source_http_url_with_options);
  Add(Result, 'vpkc_new_source_github', @@vpkc_new_source_github);
  Add(Result, 'vpkc_new_source_gitlab', @@vpkc_new_source_gitlab);
  Add(Result, 'vpkc_new_source_gitea', @@vpkc_new_source_gitea);
  Add(Result, 'vpkc_new_source_velopack_flow', @@vpkc_new_source_velopack_flow);
  Add(Result, 'vpkc_new_source_custom_callback', @@vpkc_new_source_custom_callback);
  Add(Result, 'vpkc_source_report_progress', @@vpkc_source_report_progress);
  Add(Result, 'vpkc_free_source', @@vpkc_free_source);
  Add(Result, 'vpkc_new_update_manager', @@vpkc_new_update_manager);
  Add(Result, 'vpkc_new_update_manager_flow', @@vpkc_new_update_manager_flow);
  Add(Result, 'vpkc_new_update_manager_with_source', @@vpkc_new_update_manager_with_source);
  Add(Result, 'vpkc_get_current_version', @@vpkc_get_current_version);
  Add(Result, 'vpkc_get_app_id', @@vpkc_get_app_id);
  Add(Result, 'vpkc_is_portable', @@vpkc_is_portable);
  Add(Result, 'vpkc_update_pending_restart', @@vpkc_update_pending_restart);
  Add(Result, 'vpkc_check_for_updates', @@vpkc_check_for_updates);
  Add(Result, 'vpkc_download_updates', @@vpkc_download_updates);
  Add(Result, 'vpkc_wait_exit_then_apply_updates', @@vpkc_wait_exit_then_apply_updates);
  Add(Result, 'vpkc_unsafe_apply_updates', @@vpkc_unsafe_apply_updates);
  Add(Result, 'vpkc_free_update_manager', @@vpkc_free_update_manager);
  Add(Result, 'vpkc_free_update_info', @@vpkc_free_update_info);
  Add(Result, 'vpkc_free_asset', @@vpkc_free_asset);
  Add(Result, 'vpkc_app_run', @@vpkc_app_run);
  Add(Result, 'vpkc_app_set_auto_apply_on_startup', @@vpkc_app_set_auto_apply_on_startup);
  Add(Result, 'vpkc_app_set_args', @@vpkc_app_set_args);
  Add(Result, 'vpkc_app_set_locator', @@vpkc_app_set_locator);
  Add(Result, 'vpkc_app_set_hook_after_install', @@vpkc_app_set_hook_after_install);
  Add(Result, 'vpkc_app_set_hook_before_uninstall', @@vpkc_app_set_hook_before_uninstall);
  Add(Result, 'vpkc_app_set_hook_before_update', @@vpkc_app_set_hook_before_update);
  Add(Result, 'vpkc_app_set_hook_after_update', @@vpkc_app_set_hook_after_update);
  Add(Result, 'vpkc_app_set_hook_first_run', @@vpkc_app_set_hook_first_run);
  Add(Result, 'vpkc_app_set_hook_restarted', @@vpkc_app_set_hook_restarted);
  Add(Result, 'vpkc_get_last_error', @@vpkc_get_last_error);
  Add(Result, 'vpkc_set_logger', @@vpkc_set_logger);
end;

procedure ClearExports;
var
  E: TExport;
begin
  for E in ExportTable do
    E.Target^ := nil;
end;

{ Candidate paths in priority order. }
procedure CollectCandidates(out AList: TStringArray);

  procedure Add(const S: string);
  begin
    SetLength(AList, Length(AList) + 1);
    AList[High(AList)] := S;
  end;

var
  Env: string;
begin
  AList := nil;
  if VpkcLibraryName <> '' then
  begin
    Add(VpkcLibraryName);
    Exit; // an explicit choice is never silently replaced
  end;
  Env := GetEnvironmentVariable(VPKC_LIBRARY_ENV_VAR);
  if Env <> '' then
  begin
    Add(Env);
    Exit;
  end;
  Add(ExtractFilePath(ParamStr(0)) + VPKC_DEFAULT_LIBRARY);
  Add(VPKC_DEFAULT_LIBRARY);
end;

function TryLoadInternal: Boolean;
var
  Candidates: TStringArray;
  Path, Missing, Tried: string;
  Handle: {$IFDEF FPC}TLibHandle{$ELSE}NativeUInt{$ENDIF};
  E: TExport;
  Table: TExportArray;
  P: Pointer;
begin
  Result := False;
  if GHandle <> 0 then
    Exit(True);

  CollectCandidates(Candidates);
  Handle := 0;
  GLoadedPath := '';
  for Path in Candidates do
  begin
    Handle := OsLoad(Path);
    if Handle <> 0 then
    begin
      GLoadedPath := Path;
      Break;
    end;
  end;

  if Handle = 0 then
  begin
    Tried := '';
    for Path in Candidates do
    begin
      if Tried <> '' then
        Tried := Tried + ', ';
      Tried := Tried + Path;
    end;
    GLoadError := 'Velopack native library not found. Tried: ' + Tried;
    Exit;
  end;

  Table := ExportTable;
  Missing := '';
  for E in Table do
  begin
    P := OsGetProc(Handle, E.Name);
    E.Target^ := P;
    if P = nil then
      Missing := Missing + ' ' + string(E.Name);
  end;

  if Missing <> '' then
  begin
    ClearExports;
    OsUnload(Handle);
    GLoadError := 'Velopack native library "' + GLoadedPath +
      '" is missing exports (version mismatch?):' + Missing;
    GLoadedPath := '';
    Exit;
  end;

  GHandle := Handle;
  GLoadError := '';
  Result := True;
end;

function VpkcTryLoad: Boolean;
begin
  Result := TryLoadInternal;
end;

procedure VpkcLoad;
begin
  if not TryLoadInternal then
    raise EVelopackLibraryError.Create(GLoadError);
end;

procedure VpkcUnload;
begin
  if GHandle = 0 then
    Exit;
  ClearExports;
  OsUnload(GHandle);
  GHandle := 0;
  GLoadedPath := '';
end;

function VpkcIsLoaded: Boolean;
begin
  Result := GHandle <> 0;
end;

function VpkcLoadError: string;
begin
  Result := GLoadError;
end;

function VpkcLoadedPath: string;
begin
  Result := GLoadedPath;
end;

end.
