{ velopack-pas - design-time registration, shared by the Lazarus and Delphi
  packages. Uses the RTL only; the component itself has no GUI dependency. }
unit Velopack.Reg;

{$I ../src/Velopack.Compat.inc}

interface

procedure Register;

implementation

uses
  Classes, Velopack.Updater;

procedure Register;
begin
  RegisterComponents('Velopack', [TVelopackUpdater]);
end;

end.
