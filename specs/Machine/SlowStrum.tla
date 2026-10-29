---- MODULE SlowStrum ----
\* SlowStrumState.advance: any input dies.
EXTENDS Base, SlowStrumState, Defect

\* Machine/SlowStrum.ts has SlowStrumQueue = Schema.Tuple([SlowStrumPlayback]),
\* but the model has no SlowStrumPlayback element: a slow strum stores its chord
\* and strength directly and keeps the queue empty.
expectedElementKinds == <<>>

is(s) == isInState(SlowStrumTag, s)

transitionQueueShapesMatchTag ==
  is(state) => transitionQueueMatchesShape(state, expectedElementKinds)

advance_EffectDie(pressedParamButtonId) ==
  /\ SlowStrums
  /\ is(state)
  /\ state' = Defect

getNewCleanedUpState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ is(state)
  /\ UNCHANGED state
====
