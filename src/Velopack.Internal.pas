{ velopack-pas - internal helpers shared by Velopack.App and Velopack.Manager.

  Not part of the public API: signatures may change without notice. Handles
  conversion between native structures and the Pascal value types, and error
  retrieval from the native library. }
unit Velopack.Internal;

{$I Velopack.Compat.inc}

interface

uses
  SysUtils, Velopack.Types, Velopack.Native;

type
  { Signature shared by vpkc_get_current_version and vpkc_get_app_id. }
  TNativeStringGetter = function(p_manager: Pvpkc_update_manager_t;
    psz: PAnsiChar; c: vpkc_size_t): vpkc_size_t; cdecl;

  { Builds a temporary native asset from a Pascal asset. The native record
    only points into strings owned by this object, so it is valid until Free.
    Used to pass assets back to the native library without keeping native
    memory alive on the Pascal side. }
  TNativeAssetHolder = class
  private
    FPackageId, FVersion, FAssetType, FFileName, FSHA1, FSHA256,
      FNotesMarkdown, FNotesHtml: UTF8String;
    FNative: vpkc_asset_t;
    function GetNative: Pvpkc_asset_t;
  public
    constructor Create(const AAsset: TVelopackAsset);
    property Native: Pvpkc_asset_t read GetNative;
  end;

{ Message from vpkc_get_last_error, or '' if none is available. }
function LastNativeError: string;

{ Raises EVelopackError with AContext and the last native error message. }
procedure RaiseLastNativeError(const AContext: string);

{ Reads a string from a manager getter, growing the buffer when needed. }
function ReadNativeString(AGetter: TNativeStringGetter;
  AManager: Pvpkc_update_manager_t): string;

{ Fills a native options record. AChannel must outlive its use. }
procedure FillNativeOptions(const AOptions: TUpdateOptions;
  const AChannel: UTF8String; out ANative: vpkc_update_options_t);

{ Copies a native asset into a Pascal value. }
function AssetFromNative(ANative: Pvpkc_asset_t): TVelopackAsset;

implementation

uses
  Velopack.Strings;

function LastNativeError: string;
var
  Buf: UTF8String;
  Need: vpkc_size_t;
begin
  Result := '';
  if not Assigned(vpkc_get_last_error) then
    Exit;
  SetLength(Buf, 512);
  Need := vpkc_get_last_error(PAnsiChar(Buf), Length(Buf));
  if Need > vpkc_size_t(Length(Buf)) then
  begin
    SetLength(Buf, Need);
    Need := vpkc_get_last_error(PAnsiChar(Buf), Length(Buf));
  end;
  Result := FromUtf8(PAnsiChar(Buf));
end;

procedure RaiseLastNativeError(const AContext: string);
var
  Msg: string;
begin
  Msg := LastNativeError;
  if Msg = '' then
    raise EVelopackError.Create(AContext)
  else
    raise EVelopackError.Create(AContext + ': ' + Msg);
end;

function ReadNativeString(AGetter: TNativeStringGetter;
  AManager: Pvpkc_update_manager_t): string;
var
  Buf: UTF8String;
  Need: vpkc_size_t;
begin
  SetLength(Buf, 128);
  Need := AGetter(AManager, PAnsiChar(Buf), Length(Buf));
  if Need > vpkc_size_t(Length(Buf)) then
  begin
    SetLength(Buf, Need);
    AGetter(AManager, PAnsiChar(Buf), Length(Buf));
  end;
  Result := FromUtf8(PAnsiChar(Buf));
end;

procedure FillNativeOptions(const AOptions: TUpdateOptions;
  const AChannel: UTF8String; out ANative: vpkc_update_options_t);
begin
  ANative.AllowVersionDowngrade := AOptions.AllowVersionDowngrade;
  ANative.ExplicitChannel := PUtf8OrNil(AChannel);
  ANative.MaximumDeltasBeforeFallback := AOptions.MaximumDeltasBeforeFallback;
end;

function AssetFromNative(ANative: Pvpkc_asset_t): TVelopackAsset;
begin
  Result.PackageId := FromUtf8(ANative^.PackageId);
  Result.Version := FromUtf8(ANative^.Version);
  Result.AssetType := FromUtf8(ANative^.AssetType);
  Result.FileName := FromUtf8(ANative^.FileName);
  Result.SHA1 := FromUtf8(ANative^.SHA1);
  Result.SHA256 := FromUtf8(ANative^.SHA256);
  Result.Size := ANative^.Size;
  Result.NotesMarkdown := FromUtf8(ANative^.NotesMarkdown);
  Result.NotesHtml := FromUtf8(ANative^.NotesHtml);
end;

{ TNativeAssetHolder }

function TNativeAssetHolder.GetNative: Pvpkc_asset_t;
begin
  Result := @FNative;
end;

constructor TNativeAssetHolder.Create(const AAsset: TVelopackAsset);
begin
  inherited Create;
  FPackageId := ToUtf8(AAsset.PackageId);
  FVersion := ToUtf8(AAsset.Version);
  FAssetType := ToUtf8(AAsset.AssetType);
  FFileName := ToUtf8(AAsset.FileName);
  FSHA1 := ToUtf8(AAsset.SHA1);
  FSHA256 := ToUtf8(AAsset.SHA256);
  FNotesMarkdown := ToUtf8(AAsset.NotesMarkdown);
  FNotesHtml := ToUtf8(AAsset.NotesHtml);
  FNative.PackageId := PAnsiChar(FPackageId);
  FNative.Version := PAnsiChar(FVersion);
  FNative.AssetType := PAnsiChar(FAssetType);
  FNative.FileName := PAnsiChar(FFileName);
  FNative.SHA1 := PAnsiChar(FSHA1);
  FNative.SHA256 := PAnsiChar(FSHA256);
  FNative.Size := AAsset.Size;
  FNative.NotesMarkdown := PAnsiChar(FNotesMarkdown);
  FNative.NotesHtml := PAnsiChar(FNotesHtml);
end;

end.
