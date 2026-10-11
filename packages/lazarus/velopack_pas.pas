{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit velopack_pas;

{$warn 5023 off : no warning about unused units}
interface

uses
  Velopack.App, Velopack.CustomSource, Velopack.Internal, Velopack.Log, 
  Velopack.Manager, Velopack.Native, Velopack.Strings, Velopack.Types, 
  Velopack.Updater, Velopack.Reg, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('Velopack.Reg', @Velopack.Reg.Register);
end;

initialization
  RegisterPackage('velopack_pas', @Register);
end.
