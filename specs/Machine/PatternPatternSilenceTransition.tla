---- MODULE PatternPatternSilenceTransition ----
\* ---------------------------------------------------------------------------
\* PatternPatternSilenceTransitionState.advance  (Machine/PatternPatternSilenceTransition.ts)
\* ---------------------------------------------------------------------------
EXTENDS Base,
        States,
        PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern,
        PatternPlaybackAtItsLastPlayWithScheduledLongFadeout,
        IncomingPatternFadingIn

\* Machine/PatternPatternSilenceTransition.ts: PatternPatternSilenceTransitionQueue.
expectedElementKinds ==
  << Element.PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern,
     Element.PatternPlaybackAtItsLastPlayWithScheduledLongFadeout >>

models(s) == isInState(PatternPatternSilenceTransitionState!Tag, s)

transitionQueueShapesMatchTag ==
  models(state) =>
    transitionQueueMatchesShape(state, expectedElementKinds)

onStrength(pressedParamButtonId) ==
  /\ models(state)
  /\ pressedParamButtonId.kind = EventKinds.strength
  /\ state' =
       PatternPatternSilenceTransitionState!make(state.transitionQueue, state.chord, pressedParamButtonId.value)

onChord_EffectDie(pressedParamButtonId) ==
  /\ models(state)
  /\ pressedParamButtonId.kind = EventKinds.chord
  /\ state' = DefectState!make

onPattern(pressedParamButtonId) ==
  /\ models(state)
  /\ pressedParamButtonId.kind = EventKinds.pattern
  /\ state' =
       PatternPatternPatternTransitionState!make(<< state.transitionQueue[1],
            PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern(state.transitionQueue[
                2
              ].asset),
            IncomingPatternFadingIn(TaggedPatternPointer_makeSimple(pressedParamButtonId.value, state.chord, state.strength))
         >>)

getNewCleanedUpState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ models(state)
  /\ state' =
       PatternSilenceTransitionState!make(<< PatternPlaybackAtItsLastPlayWithScheduledLongFadeout(state.transitionQueue[
                2
              ].asset)
         >>)
====
