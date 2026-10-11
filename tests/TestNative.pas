unit TestNative;

{$I ../src/Velopack.Compat.inc}

interface

uses
  SysUtils, fpcunit, testregistry;

type
  TNativeTests = class(TTestCase)
  protected
    procedure TearDown; override;
  published
    procedure MissingLibraryIsReportedNotRaisedByTryLoad;
    procedure MissingLibraryRaisesLibraryError;
    procedure LoadResolvesAllExports;
    procedure UnloadClearsFunctionPointers;
    procedure StructLayoutMatchesC;
  end;

implementation

uses
  Velopack.Native, Velopack.Types, TestSupport;

type
  TSizeFn = function: NativeUInt; cdecl;

function CSize(const AName: string): NativeUInt;
begin
  Result := TSizeFn(StubProc(AName))();
end;

procedure TNativeTests.TearDown;
begin
  VpkcUnload;
  VpkcLibraryName := '';
end;

procedure TNativeTests.MissingLibraryIsReportedNotRaisedByTryLoad;
begin
  VpkcLibraryName := '/nonexistent/libnothing.so';
  CheckFalse(VpkcTryLoad, 'TryLoad must fail');
  CheckFalse(VpkcIsLoaded);
  CheckTrue(Pos('/nonexistent/libnothing.so', VpkcLoadError) > 0,
    'error message names the library: ' + VpkcLoadError);
end;

procedure TNativeTests.MissingLibraryRaisesLibraryError;
begin
  VpkcLibraryName := '/nonexistent/libnothing.so';
  try
    VpkcLoad;
    Fail('EVelopackLibraryError expected');
  except
    on EVelopackLibraryError do ; // expected
  end;
end;

procedure TNativeTests.LoadResolvesAllExports;
begin
  UseStubLibrary;
  CheckTrue(VpkcIsLoaded);
  CheckEquals(StubLibraryPath, VpkcLoadedPath);
  CheckTrue(Assigned(vpkc_new_update_manager), 'vpkc_new_update_manager');
  CheckTrue(Assigned(vpkc_check_for_updates), 'vpkc_check_for_updates');
  CheckTrue(Assigned(vpkc_app_run), 'vpkc_app_run');
  CheckTrue(Assigned(vpkc_set_logger), 'vpkc_set_logger');
  UseStubLibrary; // second call is a no-op
end;

procedure TNativeTests.UnloadClearsFunctionPointers;
begin
  UseStubLibrary;
  VpkcUnload;
  CheckFalse(VpkcIsLoaded);
  CheckFalse(Assigned(vpkc_new_update_manager));
end;

procedure TNativeTests.StructLayoutMatchesC;
begin
  CheckEquals(CSize('vpkc_stub_sizeof_asset'), SizeOf(vpkc_asset_t), 'asset size');
  CheckEquals(CSize('vpkc_stub_sizeof_update_info'), SizeOf(vpkc_update_info_t), 'update_info size');
  CheckEquals(CSize('vpkc_stub_sizeof_options'), SizeOf(vpkc_update_options_t), 'options size');
  CheckEquals(CSize('vpkc_stub_sizeof_locator'), SizeOf(vpkc_locator_config_t), 'locator size');
  CheckEquals(CSize('vpkc_stub_sizeof_http_options'), SizeOf(vpkc_http_options_t), 'http options size');
  CheckEquals(CSize('vpkc_stub_offsetof_asset_size'), PtrUInt(@vpkc_asset_t(nil^).Size), 'asset.Size offset');
  CheckEquals(CSize('vpkc_stub_offsetof_info_is_downgrade'), PtrUInt(@vpkc_update_info_t(nil^).IsDowngrade), 'info.IsDowngrade offset');
  CheckEquals(CSize('vpkc_stub_offsetof_options_max_deltas'), PtrUInt(@vpkc_update_options_t(nil^).MaximumDeltasBeforeFallback), 'options.MaxDeltas offset');
end;

initialization
  RegisterTest(TNativeTests);
end.
