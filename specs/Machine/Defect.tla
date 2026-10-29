---- MODULE Defect ----
\* The model-only terminal variant. No action transitions out of it; the only
\* thing this file owns is the state predicate and the empty queue shape.
EXTENDS Base, States

expectedElementKinds == <<>>

models(s) == isInState(DefectState!Tag, s)

transitionQueueShapesMatchTag ==
  models(state) => transitionQueueMatchesShape(state, expectedElementKinds)
====
