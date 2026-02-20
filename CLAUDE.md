# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo does

Builds a Debian-based Docker base image (`photostructure/base-tools-debian`) used by PhotoStructure for Docker. The single `Dockerfile` compiles two statically-linked binaries from source — LibRaw and SQLite — and places them in `/opt/photostructure/tools/bin/`. The resulting image is published to both Docker Hub and GHCR as a multi-arch manifest (amd64 + arm64).

## Common tasks

```sh
make validate      # build the builder stage locally to verify LibRaw + SQLite compile
make update-pins   # update GitHub Actions SHAs in the workflow via pinact
```

## CI/CD

Pushes to `main` trigger the GitHub Actions workflow (`.github/workflows/docker-build.yml`), which:
1. Builds amd64 and arm64 images in parallel (on native runners)
2. Merges them into a multi-arch manifest and pushes to Docker Hub and GHCR

## Dockerfile conventions

- **No package.json or Node.js app code** — this repo is purely infrastructure (Dockerfile + CI config).
- **Always pin LibRaw by commit SHA**, not tag name. Tags can be force-pushed; SHAs cannot. The user explicitly prefers the SHA even when a named tag is available.
- LibRaw is fetched via the GitHub REST API tarball endpoint: `https://api.github.com/repos/LibRaw/LibRaw/tarball/<SHA>`
- SQLite is fetched from `https://sqlite.org/<year>/sqlite-autoconf-<version>.tar.gz` — note the year in the URL path must match the release year.
- GitHub Actions are pinned by commit SHA (not tag) in the workflow file — keep this pattern when updating actions. Actions are updated manually (no Dependabot).

## Updating dependencies

When bumping LibRaw:
1. Validate diffs locally by `git pull`ing in `../LibRaw` and studying `git log <old-sha>..<new-sha> --oneline` and `git diff --stat`
2. Update the tarball URL in the `Dockerfile` to use the new SHA (not a tag)

When bumping SQLite:
- Update the version number and year segment in the URL (e.g., `/2026/sqlite-autoconf-3XXXXXX.tar.gz`)
- Run `make validate` to confirm it compiles cleanly
