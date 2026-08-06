# RAW regression fixtures

Input corpus for the `raw-identify` and `dcraw_emu` halves of
`.claude/skills/update/regression-test.sh`.

## Contents

| File | What it covers |
| --- | --- |
| `canon-r6mk3-craw.cr3` | Canon EOS R6 Mark III, C-RAW (compressed). Exercises the crx decoder, the color matrix, and a full demosaic. |
| `canon-r6mk3-craw-truncated.cr3` | The first 64 KB of the same file. Metadata parses; the decode must fail. Exercises LibRaw's input-validation paths, which have no other coverage here. |

The subject — saturated magenta florets against green foliage, with clipped
highlights and real shadow detail — is chosen so a color-matrix or demosaic
change moves the decode checksum rather than hiding in flat tone.

C-RAW rather than full RAW deliberately: it is half the size, and Canon's
compressed path is where LibRaw's crx decoder churns most.

## Provenance

Photographed 2026-08-03 by Matthew McEachen. Copyright (c) 2026 PhotoStructure,
MIT licensed under the same terms as this repository — see the root `LICENSE`.

## What this does and does not buy

These fixtures make the regression test **self-contained**: a bare clone of this
public repository can run it, with no sibling checkout, no Git LFS, and no
private repository.

They are a coverage **floor**, not breadth. One camera cannot catch a
manufacturer-specific change in another. A concrete example from the
2026-08-03 bump: LibRaw PR #784 added a dedicated `EOS R50 V` color matrix,
which moved both the reported matrix and the decode checksum for Canon R50 V
files. No R6 Mark III fixture would have surfaced it.

Broad, multi-manufacturer RAW coverage lives in PhotoStructure's own test suite,
which exercises these tools against its full example corpus. If wider coverage is
ever wanted *here*, [raw.pixls.us](https://raw.pixls.us/) publishes CC0 samples
across manufacturers — but weigh each addition against clone size, since CI pulls
this repository on every push.

## Adding a fixture

Keep the set small and stable. Both files are identified twice per regression
run. The complete CR3 is demosaiced twice; the truncated CR3 is rejected twice.
Unexplained corpus churn shows up as diffs that look like regressions. Anything
added must be redistributable under this repo's license and contain nothing
identifiable — these files are public forever.
