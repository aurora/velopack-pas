unit TestLog;

{$I ../src/Velopack.Compat.inc}

interface

uses
  SysUtils, fpcunit, testregistry;

type
  TLogTests = class(TTestCase)
  protected
    procedure TearDown; override;
  published
    procedure HandlerReceivesLevelAndMessage;
    procedure RemovedHandlerReceivesNothing;
    procedure ExceptionInHandlerDoesNotEscape;
  end;

implementation

uses
  Velopack.Native, Velopack.Log, Velopack.Strings, TestSupport;

type
  TEmitFn = procedure(level, msg: PAnsiChar); cdecl;

var
  GLast: string;
  GRaise: Boolean;

procedure Capture(const Level, Message: string);
begin
  GLast := Level + '|' + Message;
  if GRaise then
    raise Exception.Create('boom');
end;

procedure Emit(const ALevel, AMsg: AnsiString);
begin
  TEmitFn(StubProc('vpkc_stub_emit_log'))(PAnsiChar(ALevel), PAnsiChar(AMsg));
end;

procedure TLogTests.TearDown;
begin
  GRaise := False;
  if VpkcIsLoaded then
    SetVelopackLogger(nil);
  VpkcUnload;
  VpkcLibraryName := '';
end;

procedure TLogTests.HandlerReceivesLevelAndMessage;
begin
  VpkcLibraryName := StubLibraryPath;
  GLast := '';
  SetVelopackLogger(Capture);
  Emit('info', 'hello');
  CheckEquals('info|hello', GLast);
end;

procedure TLogTests.RemovedHandlerReceivesNothing;
begin
  VpkcLibraryName := StubLibraryPath;
  SetVelopackLogger(Capture);
  SetVelopackLogger(nil);
  GLast := '';
  Emit('info', 'ignored');
  CheckEquals('', GLast);
end;

procedure TLogTests.ExceptionInHandlerDoesNotEscape;
begin
  VpkcLibraryName := StubLibraryPath;
  GRaise := True;
  SetVelopackLogger(Capture);
  Emit('warn', 'x'); // must not raise
  CheckEquals('warn|x', GLast);
end;

initialization
  RegisterTest(TLogTests);
end.
