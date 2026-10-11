# 0002. License the project under MIT

- Status: accepted
- Date: 2026-10-11

## Context

Velopack is MIT licensed. The binding vendors `Velopack.h` and loads the
Velopack native library. A permissive license keeps the library usable in
commercial and open-source applications and is compatible with Free Pascal's
and Lazarus' linking exception culture.

## Decision

We will license velopack-pas under the MIT license (`LICENSE`).

## Consequences

Users can embed the library freely. Contributions are accepted under MIT.
The vendored `Velopack.h` keeps its upstream MIT terms.
