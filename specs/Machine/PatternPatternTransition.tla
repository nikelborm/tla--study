---- MODULE PatternPatternTransition ----
\* ---------------------------------------------------------------------------
\* PatternPatternTransitionState.advance  (Machine/PatternPatternTransition⏳.ts)
\* The real code picks the safe/unsafe pair by comparing `now` to
\* `patternPlaybackAntialiasingFadeout_STARTS... - schedulingSafeBufferInSeconds`.
\* The safe/unsafe split is `now` against a scheduled fadeout time. Time is erased
\* here, so both variants of the split are present as separate branches and the
\* model may take either.
\* ---------------------------------------------------------------------------
EXTENDS Base,
        PatternPlayback,
        PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern,
        PatternPlaybackAtItsLastPlayWithScheduledLongFadeout,
        IncomingPatternFadingIn,
        PatternState,
        PatternPatternTransitionState,
        PatternSilenceTransitionState,
        PatternPatternPatternTransitionState,
        PatternPatternSilenceTransitionState

\* Machine/PatternPatternTransition⏳.ts: PatternPatternTransitionQueue.
expectedElementKinds ==
  << Element.PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern,
     Element.IncomingPatternFadingIn >>

is(s) == isInState(PatternPatternTransitionTag, s)

transitionQueueShapesMatchTag ==
  is(state) =>
    transitionQueueMatchesShape(state, expectedElementKinds)

theSameChordOrStrengthWasPressed(pressedParamButtonId) ==
  /\ is(state)
  /\ isTheSameChordOrStrength(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ UNCHANGED state

whenFadingOutPlaybackIsStillSafeToRevive_onPressedThePatternOfTheIncomingOne(pressedParamButtonId) ==
  /\ is(state)
  /\ isTheSamePattern(pressedParamButtonId, state.transitionQueue[2].asset)
  /\ state' =
       PatternSilenceTransitionState(<< PatternPlaybackAtItsLastPlayWithScheduledLongFadeout(state.transitionQueue[
                1
              ].asset)
         >>)

whenFadingOutPlaybackIsStillSafeToRevive_onFadingOutAssetBroughtBack(pressedParamButtonId) ==
  /\ is(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId) =
       state.transitionQueue[1].asset
  /\ state' =
       PatternState(<< PatternPlayback(state.transitionQueue[1].asset) >>)

whenFadingOutPlaybackIsStillSafeToRevive_onPressedAnyOtherPattern(pressedParamButtonId) ==
  /\ is(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId) #
       state.transitionQueue[1].asset
  /\ state' =
       PatternPatternTransitionState(<< state.transitionQueue[1],
            IncomingPatternFadingIn(makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId))
         >>)

whenFadingOutPlaybackIsUnsafeToRevive_onPressedThePatternOfTheIncomingOne(pressedParamButtonId) ==
  /\ is(state)
  /\ isTheSamePattern(pressedParamButtonId, state.transitionQueue[2].asset)
  /\ state' =
       PatternPatternSilenceTransitionState(<< state.transitionQueue[1],
            PatternPlaybackAtItsLastPlayWithScheduledLongFadeout(state.transitionQueue[
                2
              ].asset)
         >>, state.transitionQueue[2].asset.chord, state.transitionQueue[
           2
         ].asset.strength)

whenFadingOutPlaybackIsUnsafeToRevive_onPressedAnyOtherPattern(pressedParamButtonId) ==
  /\ is(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ state' =
       PatternPatternPatternTransitionState(<< state.transitionQueue[1],
            PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern(state.transitionQueue[
                2
              ].asset),
            IncomingPatternFadingIn(makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId))
         >>)

getNewCleanedUpState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ is(state)
  /\ state' =
       PatternState(<< PatternPlayback(state.transitionQueue[2].asset) >>)
====
