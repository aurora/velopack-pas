{ velopack-pas - application startup hooks (VelopackApp).

  Call TVelopackApp.Run as the very first thing in the program, before the GUI
  framework is initialized:

    begin
      TVelopackApp.OnFirstRun(@HandleFirstRun);
      TVelopackApp.Run;
      Application.Initialize;
      ...
    end.

  Velopack starts the application with special arguments during install,
  update and uninstall. In those cases Run executes the matching hook and
  terminates the process; it only returns for a normal start. }
unit Velopack.App;

{$I Velopack.Compat.inc}

interface

uses
  SysUtils, Velopack.Types;

type
  TVelopackApp = class
  public
    { Whether downloaded updates are applied on startup. Default: True. }
    class procedure SetAutoApplyOnStartup(AValue: Boolean);
    { Overrides the command line arguments seen by Velopack. By default the
      process arguments are used. }
    class procedure SetArgs(const AArgs: array of string);

    { Hooks. Install, uninstall and update hooks run in a time-critical phase
      (the process exits afterwards and is killed after 30 seconds) and are
      only invoked on Windows. Set hooks before calling Run. }
    class procedure OnAfterInstall(AHook: TVelopackHook);
    class procedure OnBeforeUninstall(AHook: TVelopackHook);
    class procedure OnBeforeUpdate(AHook: TVelopackHook);
    class procedure OnAfterUpdate(AHook: TVelopackHook);
    { Called on the first start after installation. }
    class procedure OnFirstRun(AHook: TVelopackHook);
    { Called when Velopack restarted the app after applying an update. }
    class procedure OnRestarted(AHook: TVelopackHook);

    { Lets Velopack handle install / update / uninstall launches. Returns True
      for a normal start. Returns False when the native library could not be
      loaded (for example during development without Velopack): the
      application should then simply continue without update support. }
    class function Run: Boolean;
  end;

implementation

uses
  Velopack.Native, Velopack.Strings;

var
  GAfterInstall, GBeforeUninstall, GBeforeUpdate, GAfterUpdate,
    GFirstRun, GRestarted: TVelopackHook;
  GAutoApply: Boolean = True;
  GArgs: array of UTF8String;
  GArgPtrs: array of PAnsiChar;
  GArgsSet: Boolean = False;

{ Native callbacks. Exceptions must never cross the native boundary. }

procedure Dispatch(AHook: TVelopackHook; AVersion: PAnsiChar);
begin
  if not Assigned(AHook) then
    Exit;
  try
    AHook(FromUtf8(AVersion));
  except
  end;
end;

procedure NativeAfterInstall(p_user_data: Pointer; v: PAnsiChar); cdecl;
begin Dispatch(GAfterInstall, v); end;

procedure NativeBeforeUninstall(p_user_data: Pointer; v: PAnsiChar); cdecl;
begin Dispatch(GBeforeUninstall, v); end;

procedure NativeBeforeUpdate(p_user_data: Pointer; v: PAnsiChar); cdecl;
begin Dispatch(GBeforeUpdate, v); end;

procedure NativeAfterUpdate(p_user_data: Pointer; v: PAnsiChar); cdecl;
begin Dispatch(GAfterUpdate, v); end;

procedure NativeFirstRun(p_user_data: Pointer; v: PAnsiChar); cdecl;
begin Dispatch(GFirstRun, v); end;

procedure NativeRestarted(p_user_data: Pointer; v: PAnsiChar); cdecl;
begin Dispatch(GRestarted, v); end;

class procedure TVelopackApp.SetAutoApplyOnStartup(AValue: Boolean);
begin
  GAutoApply := AValue;
end;

class procedure TVelopackApp.SetArgs(const AArgs: array of string);
var
  I: Integer;
begin
  SetLength(GArgs, Length(AArgs));
  SetLength(GArgPtrs, Length(AArgs));
  for I := 0 to High(AArgs) do
  begin
    GArgs[I] := ToUtf8(AArgs[I]);
    GArgPtrs[I] := PAnsiChar(GArgs[I]);
  end;
  GArgsSet := True;
end;

class procedure TVelopackApp.OnAfterInstall(AHook: TVelopackHook);
begin GAfterInstall := AHook; end;

class procedure TVelopackApp.OnBeforeUninstall(AHook: TVelopackHook);
begin GBeforeUninstall := AHook; end;

class procedure TVelopackApp.OnBeforeUpdate(AHook: TVelopackHook);
begin GBeforeUpdate := AHook; end;

class procedure TVelopackApp.OnAfterUpdate(AHook: TVelopackHook);
begin GAfterUpdate := AHook; end;

class procedure TVelopackApp.OnFirstRun(AHook: TVelopackHook);
begin GFirstRun := AHook; end;

class procedure TVelopackApp.OnRestarted(AHook: TVelopackHook);
begin GRestarted := AHook; end;

class function TVelopackApp.Run: Boolean;
var
  ArgsPtr: PPAnsiChar;
begin
  Result := VpkcTryLoad;
  if not Result then
    Exit;

  vpkc_app_set_auto_apply_on_startup(GAutoApply);
  if GArgsSet then
  begin
    if Length(GArgPtrs) > 0 then
      ArgsPtr := @GArgPtrs[0]
    else
      ArgsPtr := nil;
    vpkc_app_set_args(ArgsPtr, Length(GArgPtrs));
  end;
  if Assigned(GAfterInstall) then
    vpkc_app_set_hook_after_install(@NativeAfterInstall);
  if Assigned(GBeforeUninstall) then
    vpkc_app_set_hook_before_uninstall(@NativeBeforeUninstall);
  if Assigned(GBeforeUpdate) then
    vpkc_app_set_hook_before_update(@NativeBeforeUpdate);
  if Assigned(GAfterUpdate) then
    vpkc_app_set_hook_after_update(@NativeAfterUpdate);
  if Assigned(GFirstRun) then
    vpkc_app_set_hook_first_run(@NativeFirstRun);
  if Assigned(GRestarted) then
    vpkc_app_set_hook_restarted(@NativeRestarted);

  vpkc_app_run(nil); // may not return
end;

end.
