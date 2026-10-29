---- MODULE Silence ----
\* ---------------------------------------------------------------------------
\* SilenceState.advance  (Machine/Silence🏁.ts)
\* ---------------------------------------------------------------------------
EXTENDS Base, PatternPlayback, SilenceState, PatternState, SlowStrumState

\* Machine/Silence🏁.ts: SilenceQueue = Schema.Tuple([]).
expectedElementKinds == <<>>

is(s) == isInState(SilenceTag, s)

transitionQueueShapesMatchTag ==
  is(state) => transitionQueueMatchesShape(state, expectedElementKinds)

onPattern(pressedParamButtonId) ==
  /\ is(state)
  /\ pressedParamButtonId.kind = EventKinds.pattern
  /\ state' =
       PatternState(<< PatternPlayback(TaggedPatternPointer_makeSimple(pressedParamButtonId.value, state.chord, state.strength))
         >>)

onChord(pressedParamButtonId) ==
  /\ SlowStrums
  /\ is(state)
  /\ pressedParamButtonId.kind = EventKinds.chord
  /\ state' = SlowStrumState(pressedParamButtonId.value, state.strength)

onStrength(pressedParamButtonId) ==
  /\ is(state)
  /\ pressedParamButtonId.kind = EventKinds.strength
  /\ state' = SilenceState(state.chord, pressedParamButtonId.value)

getNewCleanedUpState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ is(state)
  /\ UNCHANGED state
====
