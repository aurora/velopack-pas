# AGENTS.md

Guidance for AI coding agents and human contributors working on **velopack-pas**,
a Free Pascal / Lazarus and Delphi binding for [Velopack](https://velopack.io).

## Language

- **All documentation, code comments, identifiers, commit messages and ADRs are
  written in English.** No exceptions, even if the conversation with the
  maintainer happens in another language.

## Project in one paragraph

velopack-pas is a **source library** (Pascal units plus IDE packages). It does
not re-implement Velopack. It translates Velopack's native C API
(`third_party/velopack/Velopack.h`) to Pascal, wraps it in an idiomatic
object API, and optionally offers a non-visual GUI component. The native
Velopack library is loaded dynamically at run time. See `docs/architecture.md`.

## Working rules

### Modular design
- Keep the layers strictly separated (see `docs/architecture.md`):
  `Native` -> `Types/Strings` -> `App/Manager` -> optional GUI component.
- A lower layer must never `uses` a higher one.
- Layers 1 and 2 must **not** depend on LCL, VCL or FMX. GUI code lives only
  in the component packages.
- One unit = one responsibility. Prefer a new small unit over growing an
  existing one beyond ~500 lines.
- Public API stays small. Everything not meant for users goes into the
  `implementation` section.

### Small commits
- Commit in **small, self-contained steps**: one logical change per commit.
- Every commit must leave the repository in a compiling state with passing
  tests.
- Never mix refactoring, formatting and behavior changes in one commit.
- Commit message format: `type: short summary` (imperative, <= 72 chars),
  optional body explaining *why*. Types: `feat`, `fix`, `docs`, `test`,
  `refactor`, `build`, `chore`.
- Documentation and tests for a change belong in the same or the directly
  following commit.

### Compiler compatibility
- Code under `src/` must compile with **Free Pascal >= 3.2.2** and with
  **Delphi >= 10.4** from the same source.
- Start every unit with `{$I Velopack.Compat.inc}`. Compiler differences are
  handled there or in a clearly named `{$IFDEF FPC}` block, never scattered.
- Do not use anonymous methods, generics-heavy constructs or other features
  missing from FPC 3.2.2 in `src/`.
- Do not hard-code platform assumptions; use the conditionals from the include
  file.

### Native interop
- The C API uses UTF-8 `char*` strings. Convert only through
  `Velopack.Strings`.
- Every native allocation has exactly one owner and one `vpkc_free_*` call.
  Wrap native handles in classes that free them in `Destroy`.
- Callbacks passed to native code are `cdecl` and must never let an exception
  escape.
- When `Velopack.h` changes, update `third_party/velopack/Velopack.h`,
  `Velopack.Native.pas` and the version note in `docs/architecture.md` in
  separate commits.

### Tests and verification
- Tests live in `tests/` and use FPCUnit. `tests/run-tests.sh` builds a small C
  stub of the native library, so tests run without the real Velopack binary.
- Run `tests/run-tests.sh` before every commit that touches `src/`.
- Do not claim something works unless it was compiled and run. If something
  could not be verified (e.g. Delphi, Windows), say so in the commit body or
  docs.

### Decisions and planning
- Significant decisions are recorded as ADRs in `docs/adr/` (copy
  `0000-template.md`, increment the number, never rewrite accepted ADRs —
  supersede them instead).
- `docs/implementation-plan.md` is the roadmap. Tick off milestones as they
  land and keep it truthful.

## Repository layout

| Path | Purpose |
|------|---------|
| `src/` | Library units (FPC + Delphi compatible) |
| `packages/` | Lazarus `.lpk` and Delphi `.dpk` packages |
| `examples/` | Console and GUI sample applications |
| `tests/` | FPCUnit tests and the native stub |
| `docs/` | Architecture, plan, ADRs |
| `third_party/velopack/` | Vendored `Velopack.h` (binding reference) |

## Style

- Two-space indentation, no tabs. LF line endings (`.editorconfig`).
- Type names `TFoo`, exceptions `EFoo`, interfaces `IFoo`, pointers `PFoo`.
- Comments explain *why*, not *what*. Public declarations get a short doc
  comment.
