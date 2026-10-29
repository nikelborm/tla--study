---- MODULE SlowStrum ----
\* SlowStrumState.advance: any input dies.
EXTENDS Base, States

\* Machine/SlowStrum.ts has SlowStrumQueue = Schema.Tuple([SlowStrumPlayback]),
\* but the model has no SlowStrumPlayback element: a slow strum stores its chord
\* and strength directly and keeps the queue empty.
expectedElementKinds == <<>>

models(s) == isInState(SlowStrumState!Tag, s)

transitionQueueShapesMatchTag ==
  models(state) => transitionQueueMatchesShape(state, expectedElementKinds)

advance_EffectDie(pressedParamButtonId) ==
  /\ SlowStrums
  /\ models(state)
  /\ state' = DefectState!make

getNewCleanedUpState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ models(state)
  /\ UNCHANGED state
====
