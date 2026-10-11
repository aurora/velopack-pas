# 0007. String encoding policy

- Status: accepted
- Date: 2026-10-11

## Context

The Velopack C API uses UTF-8 `char*` strings. Pascal `string` differs by
compiler: Delphi uses UTF-16 `UnicodeString`; Free Pascal 3.x uses
`AnsiString` with a code page. Lazarus sets that code page to UTF-8. A plain
FPC program on Unix has no code page manager unless it links `cwstring`, and
the default conversion turned `ü` into mojibake (found by the test suite).

## Decision

All conversions live in `Velopack.Strings`. On Delphi and on FPC/Windows we
convert through `UnicodeString`. On FPC for other platforms (`VPK_STRING_IS_UTF8`
in `Velopack.Compat.inc`) a `string` is treated as already containing UTF-8 and
bytes are copied unchanged.

## Consequences

Correct behavior in Lazarus and in typical Unix programs without extra units.
An FPC/Unix program that deliberately uses a non-UTF-8 code page for `string`
is not supported. Revisit if that is reported.
