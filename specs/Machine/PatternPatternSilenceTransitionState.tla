---- MODULE PatternPatternSilenceTransitionState ----
\* The PatternPatternSilenceTransition state variant: its tag and the fields it
\* stores, written once. Machine/PatternPatternSilenceTransition.tla holds the
\* branches that produce it.
EXTENDS Base

PatternPatternSilenceTransitionTag == "PatternPatternSilenceTransitionState"

PatternPatternSilenceTransitionState(transitionQueue, chord, strength) ==
  StateRecord(PatternPatternSilenceTransitionTag, transitionQueue, chord, strength)
====
