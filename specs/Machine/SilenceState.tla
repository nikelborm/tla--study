---- MODULE SilenceState ----
\* The Silence state variant: its tag and the fields it stores, written once.
\* Machine/Silence.tla holds the branches that produce it.
EXTENDS Base

Tag == "SilenceState"

make(chord, strength) ==
  StateRecord(Tag, <<>>, chord, strength)
====
