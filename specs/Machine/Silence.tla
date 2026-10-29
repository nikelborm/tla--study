---- MODULE Silence ----
\* ---------------------------------------------------------------------------
\* SilenceState.advance  (Machine/Silence🏁.ts)
\* ---------------------------------------------------------------------------
EXTENDS Base, States, PatternPlayback

\* Machine/Silence🏁.ts: SilenceQueue = Schema.Tuple([]).
expectedElementKinds == <<>>

models(s) == isInState(SilenceState!Tag, s)

transitionQueueShapesMatchTag ==
  models(state) => transitionQueueMatchesShape(state, expectedElementKinds)

onPattern(pressedParamButtonId) ==
  /\ models(state)
  /\ pressedParamButtonId.kind = EventKinds.pattern
  /\ state' =
       PatternState!make(<< PatternPlayback(TaggedPatternPointer_makeSimple(pressedParamButtonId.value, state.chord, state.strength))
         >>)

onChord(pressedParamButtonId) ==
  /\ SlowStrums
  /\ models(state)
  /\ pressedParamButtonId.kind = EventKinds.chord
  /\ state' = SlowStrumState!make(pressedParamButtonId.value, state.strength)

onStrength(pressedParamButtonId) ==
  /\ models(state)
  /\ pressedParamButtonId.kind = EventKinds.strength
  /\ state' = SilenceState!make(state.chord, pressedParamButtonId.value)

getNewCleanedUpState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ models(state)
  /\ UNCHANGED state
====
