# JPEG regression fixtures

Input corpus for the `jpegtran` half of `.claude/skills/update/regression-test.sh`.

## Why these are vendored

They were previously read out of PhotoStructure's `examples/` directory in a
sibling checkout. That had three problems, each of which made the regression test
pass when it should not have:

- **Git LFS.** `examples/` is LFS-tracked. An unhydrated checkout yields ~130-byte
  pointer files; both the old and new image would "process" the same text files,
  agree perfectly, and the test would report no differences.
- **Wrong files.** The JPEG search used `-maxdepth 1`, which skipped every
  rotation fixture — `orientation/`, `90/`, `180/`, `270/` all live one level
  down. The `-rotate 90 -trim` transform was only ever exercised on unrotated
  images.
- **A cross-repo dependency.** Testing this repo required a hydrated PhotoStructure
  checkout beside it.

Vendored here they are plain files in git, always present, always real.

## Contents

The ten EXIF orientation samples (`Landscape_{0,1,3,6,8}`, `Portrait_{0,1,3,6,8}`)
cover the normal and rotated EXIF orientation values. Between them they exercise
both JPEG dimensions relative to the MCU grid, which is what makes
`-rotate 90 -trim` interesting.

Keep this set small and stable. Each file is transformed four ways per image per
regression run; churn in the corpus shows up as unexplained diffs.

## Provenance

From [recurser/exif-orientation-examples](https://github.com/recurser/exif-orientation-examples),
copyright (c) 2010 Dave Perrett, MIT licensed. See [LICENSE](LICENSE), which must
travel with these files.

RAW fixtures live in [`../raw/`](../raw/README.md) and are vendored for the same
reasons.
