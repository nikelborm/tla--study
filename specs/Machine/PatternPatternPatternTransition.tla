---- MODULE PatternPatternPatternTransition ----
\* ---------------------------------------------------------------------------
\* PatternPatternPatternTransitionState.advance  (Machine/PatternPatternPatternTransition.ts)
\* ---------------------------------------------------------------------------
EXTENDS Base, IncomingPatternFadingIn,
        PatternPatternTransitionState,
        PatternPatternPatternTransitionState,
        PatternPatternSilenceTransitionState,
        Defect

\* Machine/PatternPatternPatternTransition.ts: PatternPatternPatternTransitionQueue.
expectedElementKinds ==
  << Element.PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern,
     Element.PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern,
     Element.IncomingPatternFadingIn >>

is(s) == isInState(PatternPatternPatternTransitionTag, s)

transitionQueueShapesMatchTag ==
  is(state) =>
    transitionQueueMatchesShape(state, expectedElementKinds)

theSameChordOrStrengthWasPressed(pressedParamButtonId) ==
  /\ is(state)
  /\ isTheSameChordOrStrength(pressedParamButtonId, state.transitionQueue[
         3
       ].asset)
  /\ UNCHANGED state

\* ⚠️ This is the branch that builds a PatternPatternSilenceTransitionState out of
\* `middle`, which is a SHORT-fading element, not a long-fading one. The model
\* keeps the code as-is; `TransitionQueueShapesMatchTags` is what objects.
theSamePatternWasPressed_incomingFadeInIsStillRevocable(pressedParamButtonId) ==
  /\ is(state)
  /\ isTheSamePattern(pressedParamButtonId, state.transitionQueue[3].asset)
  /\ state' =
       PatternPatternSilenceTransitionState(<< state.transitionQueue[1],
            state.transitionQueue[2]
         >>, state.transitionQueue[3].asset.chord, state.transitionQueue[
           3
         ].asset.strength)

\* "a 4th input" -> die
theSamePatternWasPressed_incomingFadeInIsNoLongerRevocable_EffectDie(pressedParamButtonId) ==
  /\ is(state)
  /\ isTheSamePattern(pressedParamButtonId, state.transitionQueue[3].asset)
  /\ state' = Defect

\* "a 4th input" -> die
theSamePatternWasNotPressed_incomingFadeInIsNoLongerRevocable_EffectDie(pressedParamButtonId) ==
  /\ is(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         3
       ].asset)
  /\ state' = Defect

theSamePatternWasNotPressed_incomingFadeInIsStillRevocable(pressedParamButtonId) ==
  /\ is(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         3
       ].asset)
  /\ state' =
       PatternPatternPatternTransitionState(<< state.transitionQueue[1],
            state.transitionQueue[2],
            IncomingPatternFadingIn(makePatchedFrom(state.transitionQueue[3].asset, pressedParamButtonId))
         >>)

getNewCleanedUpState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ is(state)
  /\ state' =
       PatternPatternTransitionState(<< state.transitionQueue[2],
            state.transitionQueue[3]
         >>)
====
