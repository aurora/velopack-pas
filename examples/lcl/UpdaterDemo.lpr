program UpdaterDemo;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms,
  Velopack.App,
  MainForm;

var
  Main: TMainForm;

begin
  // Must come first: Velopack may start the app for install/update/uninstall
  // and expects it to exit quickly. Returns False without the native library;
  // the demo then simply runs without update support.
  TVelopackApp.Run;

  Application.Scaled := True;
  Application.Initialize;
  Main := TMainForm.Create(Application);
  Application.ShowMainForm := False;
  Main.Show;
  Application.Run;
end.
