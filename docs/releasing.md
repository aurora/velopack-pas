# Releasing

A release is created by pushing a version tag. The workflow
`.github/workflows/release.yml` does everything else (ADR 0009).

## Checklist

1. `main` (or the branch to release) is green in CI: Linux jobs are required;
   look at the experimental Windows and macOS jobs as well.
2. `docs/implementation-plan.md` and the README status are truthful.
3. Decide about the pinned Velopack revision. If you want a newer one, update
   `third_party/velopack/Velopack.h` and `third_party/velopack/VERSION` in
   separate commits (see `AGENTS.md`), and let CI pass again first.
4. Bump the package version in `packages/lazarus/velopack_pas.lpk`
   (`<Version Major=... Minor=.../>`) if it changed.
5. Tag and push. Use a pre-release suffix for anything unfinished:

   ```
   git tag v0.1.0-beta.1
   git push origin v0.1.0-beta.1
   ```

   A tag with a `-suffix` becomes a GitHub *pre-release*.

## What the workflow does

| Job | Purpose |
|-----|---------|
| Plan | checks the tag format, reads the pinned Velopack commit |
| CI passed for this commit | refuses to publish if `ci.yml` has no successful run for the commit |
| Native library (x5) | builds `velopack_libc` for linux x64, windows x64/x86, macOS x64/arm64 and packages it with `tools/package-native.py` |
| Pascal sources | `git archive` of the tag |
| Publish release | writes `SHA256SUMS` and the notes, creates the release with `gh release create` |

Without a tag (manual run from the Actions tab) the same builds run as a dry
run: the archives are kept as workflow artifacts and nothing is published.

## Trying the machinery without publishing

Run the workflow manually (`workflow_dispatch`) once the file is on the default
branch, or temporarily add a `branches:` filter to its `push:` trigger on a
working branch. Both only produce workflow artifacts.

## Known limits

- The windows x64 library is built but not tested with Pascal, because CI has
  only a 32-bit Free Pascal on Windows.
- Binaries are not code-signed or notarized.
- There is no Linux arm64 build yet.
- Fixing a bad release means deleting the release and the tag and tagging again;
  do not re-use a tag that people may already have downloaded.
