#!/usr/bin/env bash
# Tiny wrapper so you don't have to remember the java invocation.
#
#   ./run-tlc.sh specs/QueueShapes.tla -config specs/QueueShapes.cfg
#
# TLC writes its state graph next to the spec; we send it to /tmp so the
# directory stays readable.
set -euo pipefail
cd "$(dirname "$0")"

# tla2tools.jar is built for Java 11+. Java 8 is installed system-wide and will
# NOT work, hence the explicit path above.
exec java -XX:+UseParallelGC -cp .tools/tla2tools.jar \
  tlc2.TLC -metadir /tmp/tla-study-states -workers 16 "$@"
