#!/bin/bash
# A/B regression test for the tools built by the Dockerfile.
#
# Runs regression-test.sh against the previously published image and the
# locally-built one, then diffs the two report trees. An empty diff (beyond
# versions.txt) means the bump changed no observable behavior.
#
# Usage: ./run-regression-test.sh [new-image] [old-image]
#
# Self-contained: the corpus is vendored in test/fixtures, so this needs nothing
# beyond this repo and docker — no sibling checkout, no Git LFS, no private repo.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"  # base-tools-debian

NEW_IMAGE="${1:-base-tools-debian:test}"
OLD_IMAGE="${2:-photostructure/base-tools-debian:latest}"
FIXTURES="$REPO_ROOT/test/fixtures"

WORK="$(mktemp -d -t base-tools-regression-XXXXXX)"

for d in "$FIXTURES/jpeg" "$FIXTURES/raw"; do
  [ -d "$d" ] || { echo "fixtures not found: $d" >&2; exit 1; }
done

docker image inspect "$NEW_IMAGE" >/dev/null 2>&1 ||
  { echo "missing $NEW_IMAGE — run 'make validate' first" >&2; exit 1; }
docker pull -q "$OLD_IMAGE" >/dev/null

run() { # run <image> <outdir>
  mkdir -p "$2"
  docker run --rm \
    --user "$(id -u):$(id -g)" \
    -v "$FIXTURES:/fixtures:ro" \
    -v "$2:/out" \
    -v "$HERE/regression-test.sh:/regression-test.sh:ro" \
    --entrypoint /bin/sh "$1" /regression-test.sh >/dev/null
}

echo "fixtures: $FIXTURES"
echo "old:      $OLD_IMAGE"
echo "new:      $NEW_IMAGE"
echo "reports:  $WORK (kept for inspection — remove when done)"
echo
echo "running old..." && run "$OLD_IMAGE" "$WORK/old"
echo "running new..." && run "$NEW_IMAGE" "$WORK/new"

echo
echo "=== versions ==="
diff "$WORK/old/versions.txt" "$WORK/new/versions.txt" || true

echo
echo "=== behavioral differences ==="
# Capture before testing: `diff -rq` exits 1 when files differ, and under
# `pipefail` that status wins over grep's, so testing the pipeline directly
# reports "no differences" precisely when there are some.
differences="$(diff -rq "$WORK/old" "$WORK/new" | grep -v '/versions.txt' || true)"
# Report coverage alongside the verdict: "no differences" over an empty report
# tree means the test covered nothing, and must not read as a pass.
compared="$(find "$WORK/new" -type f ! -name versions.txt | wc -l)"
if [ -n "$differences" ]; then
  printf '%s\n' "$differences"
  echo
  echo "Inspect a specific difference with:"
  echo "  diff $WORK/old/<subdir>/<file> $WORK/new/<subdir>/<file>"
  exit 1
elif [ "$compared" -eq 0 ]; then
  echo "NOTHING WAS COMPARED — the fixtures produced no reports." >&2
  exit 1
else
  echo "none — byte-identical across all $compared reports"
fi
