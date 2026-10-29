---- MODULE PatternPatternSilenceTransitionState ----
\* The PatternPatternSilenceTransition state variant: its tag and the fields it
\* stores, written once. Machine/PatternPatternSilenceTransition.tla holds the
\* branches that produce it.
EXTENDS Base

Tag == "PatternPatternSilenceTransitionState"

make(transitionQueue, chord, strength) ==
  StateRecord(Tag, transitionQueue, chord, strength)
====
