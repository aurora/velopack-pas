# 0006. No threading in the core layers

- Status: accepted
- Date: 2026-10-11

## Context

`vpkc_check_for_updates` and `vpkc_download_updates` block. GUI applications
need them off the main thread, but threading primitives and main-thread
marshaling differ between LCL, VCL and console programs.

## Decision

The core (`Velopack.Native`, `Velopack.Manager`, `Velopack.App`) stays
synchronous and thread-agnostic: progress callbacks are invoked on the calling
thread. The optional GUI component (layer 4) owns a worker thread and
marshals events to the main thread with `TThread.Queue`.

## Consequences

The core is easy to test and usable in services and consoles. GUI users get a
ready-made async component; others can choose their own threading model.
`TUpdateManager` instances are not thread-safe; use one per thread.
