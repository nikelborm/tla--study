---- MODULE DefectState ----
\* The model-only terminal variant. No action transitions out of it, and the
\* queue is dropped when the playback dies.
EXTENDS Base

Tag == "defect"

make == StateRecord(Tag, <<>>, noStoredSelection, noStoredSelection)
====
