---- MODULE PatternPatternPatternTransition ----
\* ---------------------------------------------------------------------------
\* PatternPatternPatternTransitionState.advance  (Machine/PatternPatternPatternTransition.ts)
\* ---------------------------------------------------------------------------
EXTENDS Base, States, Elements

\* Machine/PatternPatternPatternTransition.ts: PatternPatternPatternTransitionQueue.
expectedElementKinds ==
  << PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern!Tag,
     PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern!Tag,
     IncomingPatternFadingIn!Tag >>

models(s) == isInState(PatternPatternPatternTransitionState!Tag, s)

transitionQueueShapesMatchTag ==
  models(state) =>
    transitionQueueMatchesShape(state, expectedElementKinds)

theSameChordOrStrengthWasPressed(pressedParamButtonId) ==
  /\ models(state)
  /\ isTheSameChordOrStrength(pressedParamButtonId, state.transitionQueue[
         3
       ].asset)
  /\ UNCHANGED state

\* ⚠️ This is the branch that builds a PatternPatternSilenceTransitionState out of
\* `middle`, which is a SHORT-fading element, not a long-fading one. The model
\* keeps the code as-is; `TransitionQueueShapesMatchTags` is what objects.
theSamePatternWasPressed_incomingFadeInIsStillRevocable(pressedParamButtonId) ==
  /\ models(state)
  /\ isTheSamePattern(pressedParamButtonId, state.transitionQueue[3].asset)
  /\ state' =
       PatternPatternSilenceTransitionState!make(<< state.transitionQueue[1],
            state.transitionQueue[2]
         >>, state.transitionQueue[3].asset.chord, state.transitionQueue[
           3
         ].asset.strength)

\* "a 4th input" -> die
theSamePatternWasPressed_incomingFadeInIsNoLongerRevocable_EffectDie(pressedParamButtonId) ==
  /\ models(state)
  /\ isTheSamePattern(pressedParamButtonId, state.transitionQueue[3].asset)
  /\ state' = DefectState!make

\* "a 4th input" -> die
theSamePatternWasNotPressed_incomingFadeInIsNoLongerRevocable_EffectDie(pressedParamButtonId) ==
  /\ models(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         3
       ].asset)
  /\ state' = DefectState!make

theSamePatternWasNotPressed_incomingFadeInIsStillRevocable(pressedParamButtonId) ==
  /\ models(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         3
       ].asset)
  /\ state' =
       PatternPatternPatternTransitionState!make(<< state.transitionQueue[1],
            state.transitionQueue[2],
            IncomingPatternFadingIn!make(makePatchedFrom(state.transitionQueue[3].asset, pressedParamButtonId))
         >>)

getNewCleanedUpState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ models(state)
  /\ state' =
       PatternPatternTransitionState!make(<< state.transitionQueue[2],
            state.transitionQueue[3]
         >>)
====
