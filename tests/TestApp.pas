unit TestApp;

{$I ../src/Velopack.Compat.inc}

interface

uses
  SysUtils, fpcunit, testregistry;

type
  TAppTests = class(TTestCase)
  protected
    procedure TearDown; override;
  published
    procedure RunReturnsFalseWithoutLibrary;
    procedure RunAppliesAutoApplySetting;
    procedure FirstRunHookReceivesVersion;
  end;

implementation

uses
  Velopack.Native, Velopack.App, TestSupport;

{$IFDEF UNIX}
function c_setenv(name, value: PAnsiChar; overwrite: LongInt): LongInt; cdecl;
  external 'c' name 'setenv';
{$ENDIF}

type
  TIntFn = function: Integer; cdecl;

var
  GHookVersion: string;

procedure FirstRunHook(const AppVersion: string);
begin
  GHookVersion := AppVersion;
end;

procedure TAppTests.TearDown;
begin
  VpkcUnload;
  VpkcLibraryName := '';
end;

procedure TAppTests.RunReturnsFalseWithoutLibrary;
begin
  VpkcLibraryName := '/nonexistent/libnothing.so';
  CheckFalse(TVelopackApp.Run, 'Run must report that update support is unavailable');
end;

procedure TAppTests.RunAppliesAutoApplySetting;
begin
  VpkcLibraryName := StubLibraryPath;
  TVelopackApp.SetAutoApplyOnStartup(False);
  CheckTrue(TVelopackApp.Run);
  CheckEquals(0, TIntFn(StubProc('vpkc_stub_auto_apply'))());
  TVelopackApp.SetAutoApplyOnStartup(True);
  CheckTrue(TVelopackApp.Run);
  CheckEquals(1, TIntFn(StubProc('vpkc_stub_auto_apply'))());
end;

procedure TAppTests.FirstRunHookReceivesVersion;
begin
{$IFDEF UNIX}
  c_setenv('STUB_FIRST_RUN', '1', 1);
  VpkcLibraryName := StubLibraryPath;
  GHookVersion := '';
  TVelopackApp.OnFirstRun(@FirstRunHook);
  CheckTrue(TVelopackApp.Run);
  CheckEquals('1.2.3', GHookVersion);
{$ELSE}
  Ignore('requires setenv');
{$ENDIF}
end;

initialization
  RegisterTest(TAppTests);
end.
