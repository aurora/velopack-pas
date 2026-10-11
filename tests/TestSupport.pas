{ Shared helpers for the test suite: locates the native stub library and
  exposes its test-only exports. }
unit TestSupport;

{$I ../src/Velopack.Compat.inc}

interface

uses
  SysUtils, DynLibs;

{ Full path of the stub library (env STUB_LIB, default build/libvelopack_libc.so
  relative to the working directory). }
function StubLibraryPath: string;

{ Points Velopack.Native at the stub and loads it. }
procedure UseStubLibrary;

{ Number of native objects currently alive in the stub (leak detection). }
function StubLiveObjects: Integer;

{ Hex dump of the raw bytes of a string, for encoding-independent comparisons
  (comparing UTF8String with a literal converts code pages in FPC). }
function HexOf(const S: RawByteString): string;

{ Resolves a test-only export of the stub, raises if it is missing. }
function StubProc(const AName: string): Pointer;

implementation

uses
  Velopack.Native;

var
  GStub: TLibHandle = 0;

function HexOf(const S: RawByteString): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    Result := Result + IntToHex(Ord(S[I]), 2);
end;

function StubLibraryPath: string;
begin
  Result := GetEnvironmentVariable('STUB_LIB');
  if Result = '' then
    Result := ExpandFileName('build/libvelopack_libc.so');
end;

procedure UseStubLibrary;
begin
  VpkcLibraryName := StubLibraryPath;
  VpkcLoad;
end;

function StubProc(const AName: string): Pointer;
begin
  if GStub = 0 then
    GStub := LoadLibrary(StubLibraryPath);
  if GStub = 0 then
    raise Exception.Create('stub library not found: ' + StubLibraryPath);
  Result := GetProcedureAddress(GStub, AName);
  if Result = nil then
    raise Exception.Create('stub export missing: ' + AName);
end;

function StubLiveObjects: Integer;
type
  TFn = function: Integer; cdecl;
begin
  Result := TFn(StubProc('vpkc_stub_live_objects'))();
end;

end.
