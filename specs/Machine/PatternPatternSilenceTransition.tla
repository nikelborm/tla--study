---- MODULE PatternPatternSilenceTransition ----
\* ---------------------------------------------------------------------------
\* PatternPatternSilenceTransitionState.advance  (Machine/PatternPatternSilenceTransition.ts)
\* ---------------------------------------------------------------------------
EXTENDS Base, States, Elements

\* Machine/PatternPatternSilenceTransition.ts: PatternPatternSilenceTransitionQueue.
expectedElementKinds ==
  << PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern!Tag,
     PatternPlaybackAtItsLastPlayWithScheduledLongFadeout!Tag >>

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
            PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern!make(state.transitionQueue[
                2
              ].asset),
            IncomingPatternFadingIn!make(TaggedPatternPointer_makeSimple(pressedParamButtonId.value, state.chord, state.strength))
         >>)

getNewCleanedUpState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ models(state)
  /\ state' =
       PatternSilenceTransitionState!make(<< PatternPlaybackAtItsLastPlayWithScheduledLongFadeout!make(state.transitionQueue[
                2
              ].asset)
         >>)
====
