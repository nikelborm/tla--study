---- MODULE SlowStrumState ----
\* The SlowStrum state variant: its tag and the fields it stores, written once.
\* Machine/SlowStrum.tla holds the branches that produce it.
EXTENDS Base

Tag == "SlowStrumState"

make(chord, strength) ==
  StateRecord(Tag, <<>>, chord, strength)
====
