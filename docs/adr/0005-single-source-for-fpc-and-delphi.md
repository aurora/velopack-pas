# 0005. One source base for Free Pascal and Delphi

- Status: accepted
- Date: 2026-10-11

## Context

The library should serve Lazarus and Embarcadero users. Maintaining two forks
doubles the effort and invites divergence.

## Decision

We will write the units in a common dialect: `{$mode delphi}` on FPC, and only
language features present in FPC 3.2.2 and Delphi 10.4+. Differences are
isolated in `Velopack.Compat.inc` and `Velopack.Strings`. Only the thin GUI
layer and the package files are compiler-specific.

## Consequences

Features such as anonymous methods and inline generics are avoided in `src/`.
Delphi cannot be verified in our cloud CI, so Delphi support is best-effort
until a maintainer tests it.
