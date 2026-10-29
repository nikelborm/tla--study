---- MODULE PatternPatternSilenceTransition ----
\* ---------------------------------------------------------------------------
\* PatternPatternSilenceTransitionState.advance  (Machine/PatternPatternSilenceTransition.ts)
\* ---------------------------------------------------------------------------
EXTENDS Base,
        PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern,
        PatternPlaybackAtItsLastPlayWithScheduledLongFadeout,
        IncomingPatternFadingIn,
        PatternSilenceTransitionState,
        PatternPatternPatternTransitionState,
        PatternPatternSilenceTransitionState,
        Defect

\* Machine/PatternPatternSilenceTransition.ts: PatternPatternSilenceTransitionQueue.
expectedElementKinds ==
  << Element.PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern,
     Element.PatternPlaybackAtItsLastPlayWithScheduledLongFadeout >>

is(s) == isInState(PatternPatternSilenceTransitionTag, s)

transitionQueueShapesMatchTag ==
  is(state) =>
    transitionQueueMatchesShape(state, expectedElementKinds)

onStrength(pressedParamButtonId) ==
  /\ is(state)
  /\ pressedParamButtonId.kind = EventKinds.strength
  /\ state' =
       PatternPatternSilenceTransitionState(state.transitionQueue, state.chord, pressedParamButtonId.value)

onChord_EffectDie(pressedParamButtonId) ==
  /\ is(state)
  /\ pressedParamButtonId.kind = EventKinds.chord
  /\ state' = Defect

onPattern(pressedParamButtonId) ==
  /\ is(state)
  /\ pressedParamButtonId.kind = EventKinds.pattern
  /\ state' =
       PatternPatternPatternTransitionState(<< state.transitionQueue[1],
            PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern(state.transitionQueue[
                2
              ].asset),
            IncomingPatternFadingIn(TaggedPatternPointer_makeSimple(pressedParamButtonId.value, state.chord, state.strength))
         >>)

getNewCleanedUpState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ is(state)
  /\ state' =
       PatternSilenceTransitionState(<< PatternPlaybackAtItsLastPlayWithScheduledLongFadeout(state.transitionQueue[
                2
              ].asset)
         >>)
====
