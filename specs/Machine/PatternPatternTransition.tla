---- MODULE PatternPatternTransition ----
\* ---------------------------------------------------------------------------
\* PatternPatternTransitionState.advance  (Machine/PatternPatternTransition⏳.ts)
\* The real code picks the safe/unsafe pair by comparing `now` to
\* `patternPlaybackAntialiasingFadeout_STARTS... - schedulingSafeBufferInSeconds`.
\* The safe/unsafe split is `now` against a scheduled fadeout time. Time is erased
\* here, so both variants of the split are present as separate branches and the
\* model may take either.
\* ---------------------------------------------------------------------------
EXTENDS Base, States, Elements

\* Machine/PatternPatternTransition⏳.ts: PatternPatternTransitionQueue.
expectedElementKinds ==
  << PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern!Tag,
     IncomingPatternFadingIn!Tag >>

models(s) == isInState(PatternPatternTransitionState!Tag, s)

transitionQueueShapesMatchTag ==
  models(state) =>
    transitionQueueMatchesShape(state, expectedElementKinds)

theSameChordOrStrengthWasPressed(pressedParamButtonId) ==
  /\ models(state)
  /\ isTheSameChordOrStrength(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ UNCHANGED state

whenFadingOutPlaybackIsStillSafeToRevive_onPressedThePatternOfTheIncomingOne(pressedParamButtonId) ==
  /\ models(state)
  /\ isTheSamePattern(pressedParamButtonId, state.transitionQueue[2].asset)
  /\ state' =
       PatternSilenceTransitionState!make(<< PatternPlaybackAtItsLastPlayWithScheduledLongFadeout!make(state.transitionQueue[
                1
              ].asset)
         >>)

whenFadingOutPlaybackIsStillSafeToRevive_onFadingOutAssetBroughtBack(pressedParamButtonId) ==
  /\ models(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId) =
       state.transitionQueue[1].asset
  /\ state' =
       PatternState!make(<< PatternPlayback!make(state.transitionQueue[1].asset) >>)

whenFadingOutPlaybackIsStillSafeToRevive_onPressedAnyOtherPattern(pressedParamButtonId) ==
  /\ models(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId) #
       state.transitionQueue[1].asset
  /\ state' =
       PatternPatternTransitionState!make(<< state.transitionQueue[1],
            IncomingPatternFadingIn!make(makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId))
         >>)

whenFadingOutPlaybackIsUnsafeToRevive_onPressedThePatternOfTheIncomingOne(pressedParamButtonId) ==
  /\ models(state)
  /\ isTheSamePattern(pressedParamButtonId, state.transitionQueue[2].asset)
  /\ state' =
       PatternPatternSilenceTransitionState!make(<< state.transitionQueue[1],
            PatternPlaybackAtItsLastPlayWithScheduledLongFadeout!make(state.transitionQueue[
                2
              ].asset)
         >>, state.transitionQueue[2].asset.chord, state.transitionQueue[
           2
         ].asset.strength)

whenFadingOutPlaybackIsUnsafeToRevive_onPressedAnyOtherPattern(pressedParamButtonId) ==
  /\ models(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ state' =
       PatternPatternPatternTransitionState!make(<< state.transitionQueue[1],
            PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern!make(state.transitionQueue[
                2
              ].asset),
            IncomingPatternFadingIn!make(makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId))
         >>)

getNewCleanedUpState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ models(state)
  /\ state' =
       PatternState!make(<< PatternPlayback!make(state.transitionQueue[2].asset) >>)
====
