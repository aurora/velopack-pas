# 0004. Load the native library dynamically

- Status: accepted
- Date: 2026-10-11

## Context

Static import (`external 'name'`) fails at process start when the library is
missing, with an OS-specific dialog, and fixes the library name at compile
time. Applications that use Velopack are also often run unpackaged during
development, where the library may not exist.

## Decision

We will resolve all `vpkc_*` exports at run time (`LoadLibrary` / `dlopen`)
into procedural variables in `Velopack.Native`. The library is looked up next
to the executable first, then via the system search path. The name can be
overridden by `VpkcLibraryName` or the `VELOPACK_LIBRARY` environment variable.

## Consequences

Applications start without the library and can degrade gracefully (updates
disabled). Slightly more boilerplate in the binding unit. Missing exports are
reported by name, which also detects header version mismatches early.
