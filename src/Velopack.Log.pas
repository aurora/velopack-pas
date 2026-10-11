{ velopack-pas - bridge for the log output of the native Velopack library.

  The handler may be invoked from any thread (including worker threads of the
  native library). Make it thread-safe, and do not touch GUI controls from it
  directly. }
unit Velopack.Log;

{$I Velopack.Compat.inc}

interface

uses
  SysUtils, Velopack.Types;

{ Installs a handler for native log messages. Pass nil to remove it. Loads the
  native library if needed and raises EVelopackLibraryError if that fails. }
procedure SetVelopackLogger(AHandler: TVelopackLogEvent);

implementation

uses
  Velopack.Native, Velopack.Strings;

var
  GHandler: TVelopackLogEvent;

procedure NativeLog(p_user_data: Pointer; psz_level, psz_message: PAnsiChar); cdecl;
var
  Handler: TVelopackLogEvent;
begin
  Handler := GHandler;
  if not Assigned(Handler) then
    Exit;
  // Exceptions must never cross the native boundary.
  try
    Handler(FromUtf8(psz_level), FromUtf8(psz_message));
  except
  end;
end;

procedure SetVelopackLogger(AHandler: TVelopackLogEvent);
begin
  VpkcLoad;
  GHandler := AHandler;
  if Assigned(AHandler) then
    vpkc_set_logger(@NativeLog, nil)
  else
    vpkc_set_logger(nil, nil);
end;

end.
