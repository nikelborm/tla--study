---- MODULE PatternPatternTransitionState ----
\* The PatternPatternTransition state variant: its tag and the fields it stores,
\* written once. Machine/PatternPatternTransition.tla holds the branches that
\* produce it.
EXTENDS Base

Tag == "PatternPatternTransitionState"

make(transitionQueue) ==
  StateRecord(Tag, transitionQueue, noStoredSelection, noStoredSelection)
====
