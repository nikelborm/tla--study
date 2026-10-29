---- MODULE PatternSilenceTransition ----
\* ---------------------------------------------------------------------------
\* PatternSilenceTransitionState.advance  (Machine/PatternSilenceTransition.ts)
\* The split is `now <= patternPlaybackAntialiasingFadeout_STARTS_AT_SECONDS_SinceAudioContextInit
\* - schedulingSafeBufferInSeconds`. Time is erased, so both sides are branches.
\* ---------------------------------------------------------------------------
EXTENDS Base, PatternPlayback, IncomingPatternFadingIn,
        SilenceState,
        PatternState,
        PatternSilencePatternTransitionState,
        PatternSilenceTransitionState,
        Defect

\* Machine/PatternSilenceTransition.ts: PatternSilenceTransitionQueue.
expectedElementKinds == << Element.PatternPlaybackAtItsLastPlayWithScheduledLongFadeout >>

is(s) == isInState(PatternSilenceTransitionTag, s)

transitionQueueShapesMatchTag ==
  is(state) =>
    transitionQueueMatchesShape(state, expectedElementKinds)

theSameChordOrStrengthWasPressed(pressedParamButtonId) ==
  /\ is(state)
  /\ isTheSameChordOrStrength(pressedParamButtonId, state.transitionQueue[
         1
       ].asset)
  /\ UNCHANGED state

theSamePatternWasPressed_fadingLoopFadeoutIsStillRevocable(pressedParamButtonId) ==
  /\ is(state)
  /\ isTheSamePattern(pressedParamButtonId, state.transitionQueue[1].asset)
  /\ state' =
       PatternState(<< PatternPlayback(state.transitionQueue[1].asset) >>)

theSamePatternWasPressed_fadingLoopFadeoutIsNoLongerRevocable_EffectDie(pressedParamButtonId) ==
  /\ is(state)
  /\ isTheSamePattern(pressedParamButtonId, state.transitionQueue[1].asset)
  /\ state' = Defect

theSamePatternWasNotPressed(pressedParamButtonId) ==
  /\ is(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         1
       ].asset)
  /\ state' =
       PatternSilencePatternTransitionState(<< state.transitionQueue[1],
            IncomingPatternFadingIn(makePatchedFrom(state.transitionQueue[1].asset, pressedParamButtonId))
         >>)

getNewCleanedUpState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ is(state)
  /\ state' =
       SilenceState(state.transitionQueue[1].asset.chord, state.transitionQueue[1].asset.strength)
====
