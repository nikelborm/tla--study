---- MODULE Defect ----
\* The model-only terminal variant. There are no branches: nothing transitions
\* out of it, and the queue is dropped when the playback dies.
EXTENDS Base

DefectTag == "defect"

isDefect(s) == isInState(DefectTag, s)

Defect == StateRecord(DefectTag, <<>>, noStoredSelection, noStoredSelection)
====
