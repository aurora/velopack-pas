unit TestStrings;

{$I ../src/Velopack.Compat.inc}

interface

uses
  SysUtils, fpcunit, testregistry;

type
  TStringTests = class(TTestCase)
  published
    procedure ToUtf8EncodesUmlautsAndEuro;
    procedure FromUtf8RoundTrips;
    procedure FromUtf8NilIsEmpty;
    procedure PUtf8OrNilMapsEmptyToNil;
  end;

implementation

uses
  Velopack.Strings, TestSupport;

const
  // 'Grüße €' written as explicit UTF-8 bytes so the test is independent of
  // the source file encoding and the compiler's code page handling.
  Utf8Bytes = #$47#$72#$C3#$BC#$C3#$9F#$65#$20#$E2#$82#$AC;

procedure TStringTests.ToUtf8EncodesUmlautsAndEuro;
var
  S: string;
begin
  S := FromUtf8(Utf8Bytes);
  CheckEquals('4772C3BCC39F6520E282AC', HexOf(ToUtf8(S)));
end;

procedure TStringTests.FromUtf8RoundTrips;
var
  U: UTF8String;
begin
  U := ToUtf8(FromUtf8(Utf8Bytes));
  CheckEquals(HexOf(Utf8Bytes), HexOf(U));
end;

procedure TStringTests.FromUtf8NilIsEmpty;
begin
  CheckEquals('', FromUtf8(nil));
end;

procedure TStringTests.PUtf8OrNilMapsEmptyToNil;
var
  U: UTF8String;
begin
  U := '';
  CheckTrue(PUtf8OrNil(U) = nil);
  U := 'x';
  CheckTrue(PUtf8OrNil(U) <> nil);
end;

initialization
  RegisterTest(TStringTests);
end.
