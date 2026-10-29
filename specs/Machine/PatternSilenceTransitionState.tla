---- MODULE PatternSilenceTransitionState ----
\* The PatternSilenceTransition state variant: its tag and the fields it stores,
\* written once. Machine/PatternSilenceTransition.tla holds the branches that
\* produce it.
EXTENDS Base

Tag == "PatternSilenceTransitionState"

make(transitionQueue) ==
  StateRecord(Tag, transitionQueue, noStoredSelection, noStoredSelection)
====
