---- MODULE PatternSilencePatternTransition ----
\* ---------------------------------------------------------------------------
\* PatternSilencePatternTransitionState.advance  (Machine/PatternSilencePatternTransition.ts)
\* The split is `now <= patternPlaybackAntialiasingFadein_STARTS_AT_SECONDS_SinceAudioContextInit
\* - schedulingSafeBufferInSeconds`. Time is erased, so both sides are branches.
\* ---------------------------------------------------------------------------
EXTENDS Base, States, Elements

\* Machine/PatternSilencePatternTransition.ts: PatternSilencePatternTransitionQueue.
expectedElementKinds ==
  << PatternPlaybackAtItsLastPlayWithScheduledLongFadeout!Tag,
     IncomingPatternFadingIn!Tag >>

models(s) == isInState(PatternSilencePatternTransitionState!Tag, s)

transitionQueueShapesMatchTag ==
  models(state) =>
    transitionQueueMatchesShape(state, expectedElementKinds)

theSameChordOrStrengthWasPressed(pressedParamButtonId) ==
  /\ models(state)
  /\ isTheSameChordOrStrength(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ UNCHANGED state

theSamePatternWasPressed_incomingFadeInIsStillRevocable(pressedParamButtonId) ==
  /\ models(state)
  /\ isTheSamePattern(pressedParamButtonId, state.transitionQueue[2].asset)
  /\ state' =
       PatternSilenceTransitionState!make(<< PatternPlaybackAtItsLastPlayWithScheduledLongFadeout!make(state.transitionQueue[
                1
              ].asset)
         >>)

theSamePatternWasNotPressed_desiredAssetIsTheDyingOne(pressedParamButtonId) ==
  /\ models(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId) =
       state.transitionQueue[1].asset
  /\ state' =
       PatternState!make(<< PatternPlayback!make(state.transitionQueue[1].asset) >>)

theSamePatternWasPressed_incomingFadeInIsNoLongerRevocable(pressedParamButtonId) ==
  /\ models(state)
  /\ isTheSamePattern(pressedParamButtonId, state.transitionQueue[2].asset)
  /\ state' =
       PatternPatternSilenceTransitionState!make(<< PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern!make(state.transitionQueue[
                1
              ].asset),
            PatternPlaybackAtItsLastPlayWithScheduledLongFadeout!make(state.transitionQueue[
                2
              ].asset)
         >>, state.transitionQueue[2].asset.chord, state.transitionQueue[
           2
         ].asset.strength)

theSamePatternWasNotPressed_incomingFadeInIsNoLongerRevocable(pressedParamButtonId) ==
  /\ models(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId) #
       state.transitionQueue[1].asset
  /\ state' =
       PatternPatternPatternTransitionState!make(<< PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern!make(state.transitionQueue[
                1
              ].asset),
            PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern!make(state.transitionQueue[
                2
              ].asset),
            IncomingPatternFadingIn!make(makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId))
         >>)

theSamePatternWasNotPressed_incomingFadeInIsStillRevocable(pressedParamButtonId) ==
  /\ models(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId) #
       state.transitionQueue[1].asset
  /\ state' =
       PatternSilencePatternTransitionState!make(<< PatternPlaybackAtItsLastPlayWithScheduledLongFadeout!make(state.transitionQueue[
                1
              ].asset),
            IncomingPatternFadingIn!make(makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId))
         >>)

getNewCleanedUpState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ models(state)
  /\ state' =
       PatternState!make(<< PatternPlayback!make(state.transitionQueue[2].asset) >>)
====
