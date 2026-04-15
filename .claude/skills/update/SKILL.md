---
name: update
description: Upgrade pinned dependencies (LibRaw, SQLite, libjpeg-turbo, Node.js base image) in the Dockerfile. Use when the user asks to update, bump, or upgrade Dockerfile dependencies in base-tools-debian.
allowed-tools: Bash, Read, Edit, Grep, Glob, WebFetch
---

# Update Dockerfile dependencies

Bump the pinned versions of LibRaw, SQLite, libjpeg-turbo, and the Node.js base image in [Dockerfile](../../../Dockerfile), validate the build, and summarize each change with GitHub links for every new commit.

## Live context

- Current Dockerfile pins: !`grep -nE "FROM node|libraw/tarball|sqlite-autoconf|libjpeg-turbo/tarball" /home/mrm/src/base-tools-debian/Dockerfile`
- Git status: !`cd /home/mrm/src/base-tools-debian && git status --short`

## Workflow

### Step 1: Refresh sibling clones

Always run these before reading versions — sibling clones may be stale.

```sh
cd /home/mrm/src/LibRaw && git fetch --tags --prune && git pull --ff-only
cd /home/mrm/src/libjpeg-turbo && git fetch --tags --prune && git pull --ff-only
cd /home/mrm/src/sqlite && git fetch --tags --prune && git pull --ff-only
```

If any pull fails (non-fast-forward, dirty tree, missing clone), stop and report to the user — do not proceed blindly.

### Step 2: Check Node.js LTS

1. Read the current pin from the `FROM node:` line in [Dockerfile](../../../Dockerfile).
2. Look up the current active LTS major version at https://nodejs.org/en/about/previous-releases (use WebFetch).
3. If the Dockerfile's major version is **older** than the current active LTS, STOP. Tell the user which major is pinned vs. which is current LTS, and ask whether to migrate. Do not change the `FROM` line without approval.
4. If already on current LTS, leave the `FROM` line alone.

### Step 3: Determine new pins

For each dependency, identify the latest upstream version:

- **LibRaw**: In `/home/mrm/src/LibRaw`, run `git log -1 --format="%H %s" origin/master` to get the HEAD SHA. Compare to the SHA in the Dockerfile tarball URL. If different, that's the new pin.
- **libjpeg-turbo**: In `/home/mrm/src/libjpeg-turbo`, find the newest release tag: `git tag --sort=-v:refname | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -5`. Resolve the tag to a SHA with `git rev-list -n 1 <tag>`. Compare to the Dockerfile SHA.
- **SQLite**: Fetch https://sqlite.org/chronology.html (or https://sqlite.org/download.html) and find the latest autoconf release. Note both the version (e.g. `3530000`) and the year segment (e.g. `2026`). Compare to the Dockerfile URL.

### Step 4: Review diffs before bumping

For LibRaw and libjpeg-turbo, always show the user a summary of what changed between the old and new SHA before editing the Dockerfile:

```sh
cd /home/mrm/src/LibRaw && git log --oneline <old-sha>..<new-sha>
cd /home/mrm/src/LibRaw && git diff --stat <old-sha>..<new-sha>
```

For SQLite, read the release notes snippet from https://sqlite.org/releaselog/<version-dotted>.html (e.g. `3_53_0.html`).

### Step 5: Update the Dockerfile

Use Edit to change only the pins. Preserve formatting exactly. Pin LibRaw and libjpeg-turbo by SHA (never by tag) — this is a hard project rule.

Update the `# YYYYMMDD:` comment above the build block if it's a meaningful bump, using today's date.

### Step 6: Validate

```sh
cd /home/mrm/src/base-tools-debian && make validate
```

If the build fails, investigate and fix — do not revert without understanding the cause. Report the failure to the user with the relevant log excerpt.

### Step 7: Report to the user

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

`make validate` passed.
```

Do **not** git commit — per the user's global rule, always ask before committing.
