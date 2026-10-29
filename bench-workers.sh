#!/usr/bin/env bash
cd /home/evadev/projects/tla+-study

SPEC="specs/QueueShapes.tla"
CFG="specs/QueueShapes.cfg"

[ -f ".tools/tla2tools.jar" ] || { echo "missing .tools/tla2tools.jar" >&2; exit 1; }
[ -f "$SPEC" ] || { echo "missing $SPEC" >&2; exit 1; }
[ -f "$CFG" ] || { echo "missing $CFG" >&2; exit 1; }

echo "[warmup] heating disk cache + CPU clocks (sequential runs)..."
for i in 1 2; do
  rm -rf /tmp/tla-study-warmup
  java -XX:+UseParallelGC \
    -cp .tools/tla2tools.jar:specs/Machine:specs/Elements \
    tlc2.TLC -metadir /tmp/tla-study-warmup -workers 12 \
    "$SPEC" -config "$CFG" >/dev/null 2>&1 || true
done
rm -rf /tmp/tla-study-warmup
sync 2>/dev/null || true

echo "[bench] running hyperfine for workers 1..20 (sequential per hyperfine run)"
# Use array building more carefully
args=(
  --shell=bash
  --runs 2
  --style full
  --prepare 'sync 2>/dev/null || true; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true'
)

for w in $(seq 1 20); do
  md="/tmp/tla-study-bench-w${w}-$(date +%s)-$$"
  # Use a simpler command without nested quoting hell
  cmd="bash -c 'md=\"/tmp/tla-study-bench-w${w}-\$RANDOM\"; rm -rf \"\$md\"; java -XX:+UseParallelGC -cp .tools/tla2tools.jar:specs/Machine:specs/Elements tlc2.TLC -metadir \"\$md\" -workers ${w} specs/QueueShapes.tla -config specs/QueueShapes.cfg >/dev/null 2>&1; ec=\$?; rm -rf \"\$md\"; exit \$ec'"
  args+=(-n "workers=${w}" "$cmd")
done

hyperfine "${args[@]}"
