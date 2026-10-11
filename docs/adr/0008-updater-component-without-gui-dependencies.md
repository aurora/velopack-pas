# 0008. The updater component depends on the RTL only

- Status: accepted
- Date: 2026-10-11

## Context

GUI applications need update checks and downloads off the main thread, with
results delivered on the main thread (ADR 0006). The obvious place is an LCL
component and a VCL component. That would duplicate the logic and make it
impossible to test without a GUI toolkit.

Both toolkits use `TThread.Queue` / `CheckSynchronize` from the RTL to run code
on the main thread, so the toolkit is not needed for marshaling.

## Decision

`TVelopackUpdater` (unit `Velopack.Updater`) is a `TComponent` that uses only
the RTL (`Classes`, `TThread`). It owns the worker thread and hands results to
the main thread through `TThread.Queue`. The Lazarus and Delphi packages only
add a small registration unit that puts the component on the palette.

## Consequences

- One implementation for LCL, VCL, FMX and console programs; testable with
  FPCUnit.
- Console programs and services must pump the queue themselves with
  `CheckSynchronize`; on Unix with FPC the program must link `cthreads`
  (Lazarus GUI applications do this already).
- The component is a thin asynchronous facade; all update logic stays in
  `Velopack.Manager`.
