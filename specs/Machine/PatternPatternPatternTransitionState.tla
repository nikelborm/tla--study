---- MODULE PatternPatternPatternTransitionState ----
\* The PatternPatternPatternTransition state variant: its tag and the fields it
\* stores, written once. Machine/PatternPatternPatternTransition.tla holds the
\* branches that produce it.
EXTENDS Base

PatternPatternPatternTransitionTag == "PatternPatternPatternTransitionState"

PatternPatternPatternTransitionState(transitionQueue) ==
  StateRecord(PatternPatternPatternTransitionTag, transitionQueue, noStoredSelection, noStoredSelection)
====
