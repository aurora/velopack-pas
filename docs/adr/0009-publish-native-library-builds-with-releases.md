# 0009. Publish prebuilt native library builds with releases

- Status: accepted
- Date: 2026-10-12

## Context

velopack-pas needs Velopack's native library (`velopack_libc`) at run time
(ADR 0003, ADR 0004). Users would otherwise have to install Rust and build it
from the Velopack sources, on every platform they ship for. Velopack is MIT
licensed, so redistributing binaries is allowed if its license text comes with
them. We could not confirm whether upstream attaches prebuilt `velopack_libc`
binaries to its public releases.

The pinned upstream revision (`third_party/velopack/VERSION`) is already built
in CI on Linux, Windows and macOS, and the binding is tested against it.

## Decision

A release of velopack-pas (git tag `vMAJOR.MINOR.PATCH[-suffix]`) carries:

- a source archive with the Pascal units, packages and docs,
- one `velopack-native-<os>-<arch>.zip` per platform, built from the pinned
  Velopack revision with `cargo build --release -p velopack_libc`, each with the
  library under its default file name, `LICENSE-velopack.txt` and a
  `BUILD-INFO.txt` (commit, Rust target, SHA-256),
- `SHA256SUMS`.

The release workflow publishes only for a tag, only if CI passed for the tagged
commit, and is a dry run otherwise. The release notes state which platforms
were tested with Pascal and which were only built.

## Consequences

Users get a working library without a Rust toolchain. We take on the duty to
rebuild and re-release when the pinned Velopack revision moves (security fixes
included) and to keep the notes truthful. Binaries are built on the CI
runners (Linux on Ubuntu 22.04 for an older glibc, macOS with a deployment
target of 11.0, Windows with a static C runtime) but are not signed or
notarized; users who need that must build their own.
