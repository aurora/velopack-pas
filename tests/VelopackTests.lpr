program VelopackTests;

{$I ../src/Velopack.Compat.inc}

uses
  Classes, consoletestrunner,
  TestStrings, TestNative, TestManager, TestApp, TestLog;

type
  TVelopackTestRunner = class(TTestRunner);

var
  App: TVelopackTestRunner;

begin
  App := TVelopackTestRunner.Create(nil);
  try
    App.Initialize;
    App.Title := 'velopack-pas tests';
    App.Run;
  finally
    App.Free;
  end;
end.
