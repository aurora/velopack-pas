// velopack-pas - compiler and platform compatibility.
//
// Include this file as the very first directive of every unit:
//
//   {$I Velopack.Compat.inc}
//
// All differences between Free Pascal and Delphi are handled here (or in
// Velopack.Strings). Do not scatter IFDEF FPC blocks through the code base.
// See docs/adr/0005-single-source-for-fpc-and-delphi.md.

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
  // Records that mirror C structs must use the C layout of the platform.
  {$PACKRECORDS C}
{$ELSE}
  // Delphi: natural 8-byte alignment matches the C layout of the native
  // library on Windows (Win32 and Win64). Unverified on other targets.
  {$ALIGN 8}
  {$MINENUMSIZE 1}
{$ENDIF}

// Platform symbols used by the library.
{$IFDEF FPC}
  {$IFDEF MSWINDOWS}{$DEFINE VPK_WINDOWS}{$ENDIF}
  {$IFDEF DARWIN}{$DEFINE VPK_MACOS}{$ENDIF}
  {$IFDEF LINUX}{$DEFINE VPK_LINUX}{$ENDIF}
{$ELSE}
  {$IFDEF MSWINDOWS}{$DEFINE VPK_WINDOWS}{$ENDIF}
  {$IFDEF MACOS}{$DEFINE VPK_MACOS}{$ENDIF}
  {$IFDEF LINUX}{$DEFINE VPK_LINUX}{$ENDIF}
{$ENDIF}

// String encoding policy (see docs/adr/0007-string-encoding.md).
// Free Pascal on Unix-like systems: "string" is treated as UTF-8, as in
// Lazarus. The RTL's default code page conversion is not reliable there
// unless the application links the cwstring unit.
{$IFDEF FPC}
  {$IFNDEF VPK_WINDOWS}
    {$DEFINE VPK_STRING_IS_UTF8}
  {$ENDIF}
{$ENDIF}
