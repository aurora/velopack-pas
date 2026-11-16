# 0010. Build the Linux native library in a manylinux_2_28 container

- Status: accepted
- Date: 2026-11-16

## Context

ADR 0009 builds the published Linux library on the Ubuntu 22.04 runner "for an
older glibc". A shared library built against glibc 2.35 does not load on a
system with an older one, so the published `libvelopack_libc.so` could not be
used on RHEL 8/9 and their clones, Debian 11 or Ubuntu 20.04. Applications
that ship for those systems (for example as AppImages built on an old base)
had to build the library themselves. GitHub will also retire the Ubuntu 22.04
runner at some point, which would raise the requirement further.

The manylinux images of the Python Packaging Authority exist for exactly this
purpose: `quay.io/pypa/manylinux_2_28_x86_64` is AlmaLinux 8 with glibc 2.28
and a current GCC. Rust supports glibc 2.17 and newer. A build of the pinned
Velopack revision there (Rust installed with rustup) needs `GLIBC_2.28` at most.

## Decision

We build the Linux library in the `manylinux_2_28` container, with Rust from
rustup, and fail the release workflow if the built library references a glibc
symbol newer than 2.28 (`objdump -T`). The other platforms are unchanged.

## Consequences

The published Linux library runs on distributions with glibc 2.28 or newer
(RHEL 8, Debian 10, Ubuntu 18.10 and later) independent of the runner image.
The check makes an accidental rise visible. The job depends on the manylinux
image and on rustup being reachable; the image is a moving tag, so a future
image could in principle change the toolchain (the check still guards the
result). Distributions older than glibc 2.28 or with another C library (musl)
are not covered. This supersedes the "Linux on Ubuntu 22.04" part of ADR 0009.
