{ velopack-pas - UTF-8 string helpers.

  The Velopack C API exchanges UTF-8 encoded, NUL terminated strings. This is
  the only unit that converts between Pascal strings and C strings. }
unit Velopack.Strings;

{$I Velopack.Compat.inc}

interface

{ Encodes a Pascal string as UTF-8. The result can be passed as PAnsiChar
  (for example PAnsiChar(Result)) for as long as the variable is alive. }
function ToUtf8(const S: string): UTF8String;

{ Decodes a NUL terminated UTF-8 C string. A nil pointer yields ''. }
function FromUtf8(P: PAnsiChar): string;

{ Returns nil for an empty string, otherwise a pointer into the given UTF-8
  string. Use for optional C parameters where nil means "not set". }
function PUtf8OrNil(const S: UTF8String): PAnsiChar;

implementation

function ToUtf8(const S: string): UTF8String;
begin
  Result := UTF8Encode(UnicodeString(S));
end;

function FromUtf8(P: PAnsiChar): string;
var
  Raw: UTF8String;
begin
  if P = nil then
    Exit('');
  SetString(Raw, P, StrLen(P));
  Result := string(UTF8Decode(Raw));
end;

function PUtf8OrNil(const S: UTF8String): PAnsiChar;
begin
  if S = '' then
    Result := nil
  else
    Result := PAnsiChar(S);
end;

end.
