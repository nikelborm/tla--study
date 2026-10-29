---- MODULE PatternPatternPatternTransitionState ----
\* The PatternPatternPatternTransition state variant: its tag and the fields it
\* stores, written once. Machine/PatternPatternPatternTransition.tla holds the
\* branches that produce it.
EXTENDS Base

Tag == "PatternPatternPatternTransitionState"

make(transitionQueue) ==
  StateRecord(Tag, transitionQueue, noStoredSelection, noStoredSelection)
====
