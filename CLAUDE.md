# CLAUDE.md

@AGENTS.md

## Notes specific to Claude Code

- Read `docs/architecture.md` and `docs/implementation-plan.md` before making
  structural changes; update the plan when a milestone is finished.
- Write all documentation, comments and commit messages in English, regardless
  of the language the user writes in.
- Commit early and often in small steps (see "Small commits" in AGENTS.md).
  Push to the branch assigned for the session, never to another one.
- Free Pascal is the verification compiler available in cloud sessions
  (`apt-get install fpc`). Delphi cannot be compiled there: keep Delphi
  compatibility by following the rules in `src/Velopack.Compat.inc` and mark
  Delphi-only code as unverified.
- The real Velopack native library is not available in sandboxed sessions.
  Use the stub in `tests/stub/` for verification.
- The GitHub MCP tools are the only way to talk to GitHub; do not open a pull
  request unless the user asks for one.
