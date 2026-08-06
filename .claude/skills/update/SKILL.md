---
name: update
description: Upgrade pinned dependencies (LibRaw, SQLite, libjpeg-turbo, Node.js base image) in the Dockerfile. Use when the user asks to update, bump, or upgrade Dockerfile dependencies in base-tools-debian.
allowed-tools: Bash, Read, Edit, Grep, Glob, WebFetch
---

# Update Dockerfile dependencies

Bump the pinned versions of LibRaw, SQLite, libjpeg-turbo, and the Node.js base image in [Dockerfile](../../../Dockerfile), refresh the GitHub Actions pins, validate the build, regression-test the new binaries against the previously published ones, and summarize each change with GitHub links for every new commit.

## Live context

- Current Dockerfile pins: !`grep -nE "FROM node|libraw/tarball|sqlite-autoconf|libjpeg-turbo/tarball" "$(git rev-parse --show-toplevel)/Dockerfile"`
- Git status: !`git status --short`

## Workflow

Never hard-code `/home/<user>` paths. Derive everything from the repo root, and
use `git -C <dir>` rather than `cd` so no command depends on the working
directory:

```sh
REPO="$(git rev-parse --show-toplevel)"   # base-tools-debian
SRC="$(dirname "$REPO")"                  # parent dir holding the sibling clones
```

Every path below is written in terms of these two variables. Set them once at the
start and reuse them.

### Step 1: Refresh sibling clones

Always run these before reading versions — sibling clones may be stale.

```sh
git -C "$SRC/LibRaw" fetch --tags --prune && git -C "$SRC/LibRaw" pull --ff-only
git -C "$SRC/libjpeg-turbo" fetch --tags --prune && git -C "$SRC/libjpeg-turbo" pull --ff-only
```

If any pull fails (non-fast-forward, dirty tree, missing clone), stop and report to the user — do not proceed blindly.

Do **not** `git pull` `$SRC/sqlite` — it is a downloaded source tarball, not a git clone. SQLite versions are queried directly from sqlite.org in Step 3.

### Step 2: Check Node.js LTS

1. Read the current pin from the `FROM node:` line in [Dockerfile](../../../Dockerfile).
2. Look up the current active LTS major version at https://nodejs.org/en/about/previous-releases (use WebFetch).
3. If the Dockerfile's major version is **older** than the current active LTS, STOP. Tell the user which major is pinned vs. which is current LTS, and ask whether to migrate. Do not change the `FROM` line without approval.
4. If already on current LTS, leave the `FROM` line alone.

### Step 3: Determine new pins

For each dependency, identify the latest upstream version:

- **LibRaw**: `git -C "$SRC/LibRaw" log -1 --format="%H %s" origin/master` gives the HEAD SHA. Compare to the SHA in the Dockerfile tarball URL. If different, that's the new pin.
- **libjpeg-turbo**: find the newest release tag with `git -C "$SRC/libjpeg-turbo" tag --sort=-v:refname | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -5`. Resolve the tag to a SHA with `git -C "$SRC/libjpeg-turbo" rev-list -n 1 <tag>`. Compare to the Dockerfile SHA.
- **SQLite**: `$SRC/sqlite` is a downloaded tarball, not a git clone — ignore it. Query sqlite.org directly: WebFetch https://sqlite.org/chronology.html (or https://sqlite.org/download.html) to find the latest autoconf release. Note both the version (e.g. `3530000`) and the year segment (e.g. `2026`). Compare to the Dockerfile URL. Confirm the year segment is right by checking the URL resolves before editing: `curl -sIL -o /dev/null -w '%{http_code}\n' https://sqlite.org/<year>/sqlite-autoconf-<version>.tar.gz`

### Step 4: Review diffs before bumping

For LibRaw and libjpeg-turbo, always show the user a summary of what changed between the old and new SHA before editing the Dockerfile:

```sh
git -C "$SRC/LibRaw" log --oneline <old-sha>..<new-sha>
git -C "$SRC/LibRaw" diff --stat <old-sha>..<new-sha>
```

For SQLite, read the release notes snippet from https://sqlite.org/releaselog/<version-dotted>.html (e.g. `3_53_0.html`).

### Step 5: Update the Dockerfile

Use Edit to change only the pins. Preserve formatting exactly. Pin LibRaw and libjpeg-turbo by SHA (never by tag) — this is a hard project rule.

Update the `# YYYYMMDD:` comment above the build block if it's a meaningful bump, using today's date.

### Step 6: Update the GitHub Actions pins

The workflow's actions are pinned by SHA and updated manually (no Dependabot).
Refresh them with pinact:

```sh
make -C "$REPO" update-pins
git -C "$REPO" diff --stat .github/
```

Report which actions moved as part of Step 8. If the working tree is unchanged,
say so — that's a normal outcome, not a failure.

### Step 7: Validate and regression-test

Run this only after **all** edits from Steps 5 and 6 are in place, so the build
reflects the final state of the tree. `regression-test` depends on `validate`, so
one command does both — build, then behavioral A/B:

```sh
make -C "$REPO" regression-test
```

If the build fails, investigate and fix — do not revert without understanding the
cause. Report the failure to the user with the relevant log excerpt.

The regression test exercises all four tools in both the previously published
image and the newly built one, then diffs the results. Its corpus is vendored in
`test/fixtures/` — ten EXIF orientation JPEGs and two Canon CR3s, one of them
deliberately truncated. Nothing outside this repo is required: no sibling
checkout, no Git LFS, no private repository. See the READMEs in
`test/fixtures/jpeg/` and `test/fixtures/raw/` for what each file buys.

It covers:

- `raw-identify -v` — full metadata dumps for both RAW fixtures (catches parser and color-matrix changes)
- `dcraw_emu -w -h -T` — a checksummed demosaic for the complete CR3 and the expected rejection for the truncated CR3
- `jpegtran` — optimize, progressive, rotate+trim, and grayscale transforms over all ten JPEG fixtures, each checksummed
- `sqlite3` — core SQL, JSON, FTS5, R*Tree, math functions, `integrity_check`

Interpreting the output:

- **No differences** — the bump is behavior-preserving. Report that.
- **Differences** — every one needs an explanation traced to an upstream commit
  before you report success. Diff the individual report files and map the change
  to a commit in the range you reviewed in Step 4 (e.g. a new camera color matrix
  changes that model's `raw-identify` matrices and its decode checksum).
  An unexplained difference is a regression — investigate, don't hand-wave.
- **Nonzero exits present in *both* runs** are pre-existing (deliberately corrupt
  or truncated test fixtures, or a module absent from the build). Not regressions.

### Step 8: Report to the user

Present a summary in this shape. Use GitHub compare URLs for LibRaw/libjpeg-turbo and a link to the SQLite release notes.

```
## Dependency updates

- **LibRaw**: `<old-sha-short>` → `<new-sha-short>` (N commits)
  https://github.com/LibRaw/LibRaw/compare/<old-sha>...<new-sha>
  - <one-line summary per notable commit>

- **libjpeg-turbo**: `<old-sha-short>` → `<new-sha-short>` (tag `X.Y.Z`)
  https://github.com/libjpeg-turbo/libjpeg-turbo/compare/<old-sha>...<new-sha>
  - <notable changes>

- **SQLite**: `3.X.Y` → `3.A.B`
  https://sqlite.org/releaselog/<version>.html

- **Node.js**: unchanged at `node:NN-trixie-slim` (current LTS)

- **GitHub Actions**: <actions bumped by `make update-pins`, or "no changes">

`make validate` passed. Regression test vs. the published image: <no differences |
the N differences below, each traced to an upstream commit>.
```

Do **not** git commit — per the user's global rule, always ask before committing.
