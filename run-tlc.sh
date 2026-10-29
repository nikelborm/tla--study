#!/usr/bin/env bash
# Tiny wrapper so you don't have to remember the java invocation.
#
#   ./run-tlc.sh specs/QueueShapes.tla -config specs/QueueShapes.cfg
#
# TLC writes its state graph next to the spec; we send it to /tmp so the
# directory stays readable.
set -euo pipefail
cd "$(dirname "$0")"

# tla2tools.jar needs Java 11+. Whatever `java` resolves to must be that new.
#
# TLA+ finds modules by file name on the search path. The directory of the root
# module (specs/) is searched implicitly; subdirectories are not, so Machine/ and
# Elements/ are added here by hand.
exec java -XX:+UseParallelGC \
  -cp .tools/tla2tools.jar:specs/Machine:specs/Elements \
  tlc2.TLC -metadir /tmp/tla-study-states -workers 6 "$@"

# with bench discovered that on my laptop after 6, there's no benefit
