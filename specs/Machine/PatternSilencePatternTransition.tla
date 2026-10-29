---- MODULE PatternSilencePatternTransition ----
\* ---------------------------------------------------------------------------
\* PatternSilencePatternTransitionState.advance  (Machine/PatternSilencePatternTransition.ts)
\* The split is `now <= patternPlaybackAntialiasingFadein_STARTS_AT_SECONDS_SinceAudioContextInit
\* - schedulingSafeBufferInSeconds`. Time is erased, so both sides are branches.
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
        PatternPatternSilenceTransitionState,
        PatternSilencePatternTransitionState

\* Machine/PatternSilencePatternTransition.ts: PatternSilencePatternTransitionQueue.
expectedElementKinds ==
  << Element.PatternPlaybackAtItsLastPlayWithScheduledLongFadeout,
     Element.IncomingPatternFadingIn >>

is(s) == isInState(PatternSilencePatternTransitionTag, s)

transitionQueueShapesMatchTag ==
  is(state) =>
    transitionQueueMatchesShape(state, expectedElementKinds)

theSameChordOrStrengthWasPressed(pressedParamButtonId) ==
  /\ is(state)
  /\ isTheSameChordOrStrength(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ UNCHANGED state

theSamePatternWasPressed_incomingFadeInIsStillRevocable(pressedParamButtonId) ==
  /\ is(state)
  /\ isTheSamePattern(pressedParamButtonId, state.transitionQueue[2].asset)
  /\ state' =
       PatternSilenceTransitionState(<< PatternPlaybackAtItsLastPlayWithScheduledLongFadeout(state.transitionQueue[
                1
              ].asset)
         >>)

theSamePatternWasNotPressed_desiredAssetIsTheDyingOne(pressedParamButtonId) ==
  /\ is(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId) =
       state.transitionQueue[1].asset
  /\ state' =
       PatternState(<< PatternPlayback(state.transitionQueue[1].asset) >>)

theSamePatternWasPressed_incomingFadeInIsNoLongerRevocable(pressedParamButtonId) ==
  /\ is(state)
  /\ isTheSamePattern(pressedParamButtonId, state.transitionQueue[2].asset)
  /\ state' =
       PatternPatternSilenceTransitionState(<< PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern(state.transitionQueue[
                1
              ].asset),
            PatternPlaybackAtItsLastPlayWithScheduledLongFadeout(state.transitionQueue[
                2
              ].asset)
         >>, state.transitionQueue[2].asset.chord, state.transitionQueue[
           2
         ].asset.strength)

theSamePatternWasNotPressed_incomingFadeInIsNoLongerRevocable(pressedParamButtonId) ==
  /\ is(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId) #
       state.transitionQueue[1].asset
  /\ state' =
       PatternPatternPatternTransitionState(<< PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern(state.transitionQueue[
                1
              ].asset),
            PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern(state.transitionQueue[
                2
              ].asset),
            IncomingPatternFadingIn(makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId))
         >>)

theSamePatternWasNotPressed_incomingFadeInIsStillRevocable(pressedParamButtonId) ==
  /\ is(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId) #
       state.transitionQueue[1].asset
  /\ state' =
       PatternSilencePatternTransitionState(<< PatternPlaybackAtItsLastPlayWithScheduledLongFadeout(state.transitionQueue[
                1
              ].asset),
            IncomingPatternFadingIn(makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId))
         >>)

getNewCleanedUpState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ is(state)
  /\ state' =
       PatternState(<< PatternPlayback(state.transitionQueue[2].asset) >>)
====
