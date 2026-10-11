// UNVERIFIED: written without access to a Delphi compiler.
program UpdaterDemo;

uses
  Vcl.Forms,
  Velopack.App in '..\..\src\Velopack.App.pas',
  Velopack.Types in '..\..\src\Velopack.Types.pas',
  Velopack.Strings in '..\..\src\Velopack.Strings.pas',
  Velopack.Native in '..\..\src\Velopack.Native.pas',
  Velopack.Internal in '..\..\src\Velopack.Internal.pas',
  Velopack.Manager in '..\..\src\Velopack.Manager.pas',
  Velopack.Updater in '..\..\src\Velopack.Updater.pas',
  MainForm in 'MainForm.pas';

var
  Main: TMainForm;

begin
  // Must come first: Velopack may start the app for install/update/uninstall.
  TVelopackApp.Run;

  Application.Initialize;
  Main := TMainForm.Create(Application);
  Application.MainForm := Main;
  Main.Show;
  Application.Run;
end.
