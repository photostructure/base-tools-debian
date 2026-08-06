#!/bin/sh
# Runs INSIDE a base-tools-debian image. Exercises every binary in
# /opt/photostructure/tools against this repo's vendored test/fixtures (mounted
# at /fixtures) and writes a deterministic, diffable report tree to /out.
#
# Everything it needs is in this repo — no sibling checkout, no Git LFS, no
# private repository. A bare clone can run it.
#
# Driven by run-regression-test.sh — don't invoke this directly on the host.
set -u

TOOLS=/opt/photostructure/tools
FIXTURES=/fixtures
OUT=/out
TIMEOUT=60

mkdir -p "$OUT/raw-identify" "$OUT/decode" "$OUT/jpegtran"

md5of() { md5sum | cut -d' ' -f1; }

# ---------- versions ----------
{
  echo "sqlite3:  $("$TOOLS"/sqlite3 --version | awk '{print $1}')"
  echo "jpegtran: $("$TOOLS"/jpegtran -version 2>&1 | head -1)"
  echo "libraw:   $(strings "$TOOLS"/raw-identify | grep -m1 -E '^[0-9]+\.[0-9]+\.[0-9]+(-\w+)?$')"
} > "$OUT/versions.txt" 2>&1

# ---------- sqlite ----------
# Exercises the extensions PhotoStructure relies on. A missing module here is
# only a regression if it's absent from the NEW run and present in the OLD one.
"$TOOLS"/sqlite3 :memory: > "$OUT/sqlite.txt" 2>&1 <<'SQL'
.bail off
select 'core', count(*), sum(a), coalesce(group_concat(b),'-') from
  (select 1 a,'one' b union all select 2,'two' union all select 3,null);
select 'json', json_extract('{"x":{"y":[1,2,3]}}','$.x.y[1]');
create virtual table ft using fts5(body);
insert into ft values ('hello world'),('goodbye world');
select 'fts5', count(*) from ft where ft match 'world';
create virtual table r using rtree(id, x0, x1, y0, y1);
insert into r values (1, 0.0, 1.0, 0.0, 1.0);
select 'rtree', count(*) from r where x0 < 0.5;
select 'math', round(sqrt(2.0), 6);
select 'opts', count(*) from pragma_compile_options;
pragma integrity_check;
SQL
echo "sqlite_exit=$?" >> "$OUT/sqlite.txt"

# ---------- raw: identify + decode ----------
find "$FIXTURES/raw" -type f \
  \( -iname '*.cr2' -o -iname '*.cr3' -o -iname '*.nef' -o -iname '*.arw' \
  -o -iname '*.dng' -o -iname '*.raf' -o -iname '*.orf' -o -iname '*.rw2' \
  -o -iname '*.x3f' -o -iname '*.kdc' \) | sort | while read -r f; do
  base=$(basename "$f")

  # raw-identify: full metadata dump, path-normalized so runs are comparable.
  # Catches metadata-parser and color-matrix changes.
  timeout "$TIMEOUT" "$TOOLS"/raw-identify -v "$f" > /tmp/ri.txt 2>&1
  rc=$?
  { echo "exit=$rc"; sed "s|$FIXTURES/||g" /tmp/ri.txt; } > "$OUT/raw-identify/$base.txt"

  # dcraw_emu: actually demosaic (half-size, camera WB, TIFF to stdout) and
  # checksum the pixels. Catches decoder regressions raw-identify can't see.
  # The deliberately truncated fixture exercises the input-validation paths:
  # it is expected to fail here, identically, in both images.
  timeout "$TIMEOUT" "$TOOLS"/dcraw_emu -w -h -T -Z - "$f" > /tmp/d.tiff 2>/tmp/d.err
  rc=$?
  printf 'exit=%s bytes=%s md5=%s\n' \
    "$rc" "$(wc -c < /tmp/d.tiff)" "$(md5of < /tmp/d.tiff)" > "$OUT/decode/$base.txt"
  sed "s|$FIXTURES/||g" /tmp/d.err >> "$OUT/decode/$base.txt"
done

# ---------- jpeg ----------
find "$FIXTURES/jpeg" -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) |
  sort | while read -r f; do
  base=$(basename "$f")
  {
    for op in "-optimize -copy all" "-progressive -copy all" "-rotate 90 -trim" "-grayscale"; do
      # shellcheck disable=SC2086
      timeout "$TIMEOUT" "$TOOLS"/jpegtran $op "$f" > /tmp/j.jpg 2>/tmp/j.err
      printf '%-26s exit=%s bytes=%s md5=%s\n' \
        "[$op]" "$?" "$(wc -c < /tmp/j.jpg)" "$(md5of < /tmp/j.jpg)"
      sed "s|$FIXTURES/||g;s|^|    |" /tmp/j.err
    done
  } > "$OUT/jpegtran/$base.txt"
done

echo "done"
