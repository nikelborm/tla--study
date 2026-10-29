---- MODULE PatternSilenceTransition ----
\* ---------------------------------------------------------------------------
\* PatternSilenceTransitionState.advance  (Machine/PatternSilenceTransition.ts)
\* The split is `now <= patternPlaybackAntialiasingFadeout_STARTS_AT_SECONDS_SinceAudioContextInit
\* - schedulingSafeBufferInSeconds`. Time is erased, so both sides are branches.
\* ---------------------------------------------------------------------------
EXTENDS Base,
        States,
        PatternPlayback,
        IncomingPatternFadingIn

\* Machine/PatternSilenceTransition.ts: PatternSilenceTransitionQueue.
expectedElementKinds == << Element.PatternPlaybackAtItsLastPlayWithScheduledLongFadeout >>

models(s) == isInState(PatternSilenceTransitionState!Tag, s)

transitionQueueShapesMatchTag ==
  models(state) =>
    transitionQueueMatchesShape(state, expectedElementKinds)

theSameChordOrStrengthWasPressed(pressedParamButtonId) ==
  /\ models(state)
  /\ isTheSameChordOrStrength(pressedParamButtonId, state.transitionQueue[
         1
       ].asset)
  /\ UNCHANGED state

theSamePatternWasPressed_fadingLoopFadeoutIsStillRevocable(pressedParamButtonId) ==
  /\ models(state)
  /\ isTheSamePattern(pressedParamButtonId, state.transitionQueue[1].asset)
  /\ state' =
       PatternState!make(<< PatternPlayback(state.transitionQueue[1].asset) >>)

theSamePatternWasPressed_fadingLoopFadeoutIsNoLongerRevocable_EffectDie(pressedParamButtonId) ==
  /\ models(state)
  /\ isTheSamePattern(pressedParamButtonId, state.transitionQueue[1].asset)
  /\ state' = DefectState!make

theSamePatternWasNotPressed(pressedParamButtonId) ==
  /\ models(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         1
       ].asset)
  /\ state' =
       PatternSilencePatternTransitionState!make(<< state.transitionQueue[1],
            IncomingPatternFadingIn(makePatchedFrom(state.transitionQueue[1].asset, pressedParamButtonId))
         >>)

getNewCleanedUpState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ models(state)
  /\ state' =
       SilenceState!make(state.transitionQueue[1].asset.chord, state.transitionQueue[1].asset.strength)
====
