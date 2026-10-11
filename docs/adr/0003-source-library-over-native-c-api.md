# 0003. Ship a Pascal source library on top of Velopack's native C API

- Status: accepted
- Date: 2026-10-11

## Context

The library must be reusable from many applications and from both Free Pascal
and Delphi. Options considered:

1. Re-implement Velopack in Pascal. Large, error-prone, drifts from upstream.
2. Build our own native shared library wrapping Velopack. Adds a second binary
   and a second release process; Velopack already exposes a C ABI.
3. Translate the existing C API (`Velopack.h`) and provide Pascal wrappers.

## Decision

We will take option 3 and distribute the result as Pascal units plus IDE
packages. We do not build or ship any binary ourselves.

## Consequences

Minimal code, tracks upstream through the header. Applications must ship
Velopack's native library next to their executable. Header changes upstream
require updating the translation (see `AGENTS.md`).
