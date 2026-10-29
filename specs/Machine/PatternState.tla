---- MODULE PatternState ----
\* The Pattern state variant: its tag and the fields it stores, written once.
\* Machine/Pattern.tla holds the branches that produce it.
EXTENDS Base

PatternTag == "PatternState"

PatternState(transitionQueue) ==
  StateRecord(PatternTag, transitionQueue, noStoredSelection, noStoredSelection)
====
