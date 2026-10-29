---- MODULE SlowStrumState ----
\* The SlowStrum state variant: its tag and the fields it stores, written once.
\* Machine/SlowStrum.tla holds the branches that produce it.
EXTENDS Base

SlowStrumTag == "SlowStrumState"

SlowStrumState(chord, strength) ==
  StateRecord(SlowStrumTag, <<>>, chord, strength)
====
