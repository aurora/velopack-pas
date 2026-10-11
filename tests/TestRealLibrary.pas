{ Smoke tests against the REAL Velopack native library.

  Registered only when the environment variable VELOPACK_REAL_LIB points to the
  library (for example target/release/libvelopack_libc.so of a Velopack
  checkout built with `cargo build --release -p velopack_libc`). Without it the
  suite runs against the C stub only.

  A real update cycle needs an installed Velopack application and a package
  feed, which is out of scope here; these tests cover loading, symbol
  resolution, source creation and the error path outside an installation. }
unit TestRealLibrary;

{$I ../src/Velopack.Compat.inc}

interface

uses
  SysUtils, fpcunit, testregistry;

type
  TRealLibraryTests = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure LoadsAndResolvesAllExports;
    procedure ManagerOutsideInstallationRaisesNativeError;
    procedure AppRunReturnsForNormalStart;
    procedure SourcesCanBeCreatedAndFreed;
  end;

implementation

uses
  Velopack.Native, Velopack.Types, Velopack.App, Velopack.Manager;

const
  ENV_REAL_LIB = 'VELOPACK_REAL_LIB';

procedure TRealLibraryTests.SetUp;
begin
  VpkcLibraryName := GetEnvironmentVariable(ENV_REAL_LIB);
end;

procedure TRealLibraryTests.TearDown;
begin
  VpkcUnload;
  VpkcLibraryName := '';
end;

procedure TRealLibraryTests.LoadsAndResolvesAllExports;
begin
  CheckTrue(VpkcTryLoad, VpkcLoadError);
  CheckEquals(GetEnvironmentVariable(ENV_REAL_LIB), VpkcLoadedPath);
end;

procedure TRealLibraryTests.ManagerOutsideInstallationRaisesNativeError;
begin
  try
    TUpdateManager.Create(GetTempDir).Free;
    Fail('EVelopackError expected: the test process is not a Velopack install');
  except
    on E: EVelopackError do
      CheckTrue(Pos('not properly installed', E.Message) > 0,
        'message from the native library expected, got: ' + E.Message);
  end;
end;

procedure TRealLibraryTests.AppRunReturnsForNormalStart;
begin
  // Plain launch without Velopack arguments: Run must return, not exit.
  TVelopackApp.SetArgs([]);
  CheckTrue(TVelopackApp.Run);
end;

procedure TRealLibraryTests.SourcesCanBeCreatedAndFreed;
begin
  TUpdateSource.FromFile(GetTempDir).Free;
  TUpdateSource.FromHttpUrl('https://example.invalid/releases').Free;
  TUpdateSource.FromGitHub('https://github.com/velopack/velopack').Free;
end;

initialization
  if GetEnvironmentVariable(ENV_REAL_LIB) <> '' then
    RegisterTest(TRealLibraryTests);
end.
