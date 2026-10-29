---- MODULE PatternSilenceTransitionState ----
\* The PatternSilenceTransition state variant: its tag and the fields it stores,
\* written once. Machine/PatternSilenceTransition.tla holds the branches that
\* produce it.
EXTENDS Base

PatternSilenceTransitionTag == "PatternSilenceTransitionState"

PatternSilenceTransitionState(transitionQueue) ==
  StateRecord(PatternSilenceTransitionTag, transitionQueue, noStoredSelection, noStoredSelection)
====
