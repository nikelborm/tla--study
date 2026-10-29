---- MODULE PatternSilencePatternTransitionState ----
\* The PatternSilencePatternTransition state variant: its tag and the fields it
\* stores, written once. Machine/PatternSilencePatternTransition.tla holds the
\* branches that produce it.
EXTENDS Base

Tag == "PatternSilencePatternTransitionState"

make(transitionQueue) ==
  StateRecord(Tag, transitionQueue, noStoredSelection, noStoredSelection)
====
