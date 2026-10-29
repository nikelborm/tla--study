---- MODULE Pattern ----
\* ---------------------------------------------------------------------------
\* PatternState.advance  (Machine/Pattern⏳.ts)
\* ---------------------------------------------------------------------------
EXTENDS Base,
        States,
        PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern,
        PatternPlaybackAtItsLastPlayWithScheduledLongFadeout,
        IncomingPatternFadingIn

\* Machine/Pattern⏳.ts: PatternQueue = Schema.Tuple([PatternPlayback]).
expectedElementKinds == << Element.PatternPlayback >>

models(s) == isInState(PatternState!Tag, s)

transitionQueueShapesMatchTag ==
  models(state) => transitionQueueMatchesShape(state, expectedElementKinds)

theSameChordOrStrengthWasPressed(pressedParamButtonId) ==
  /\ models(state)
  /\ isTheSameChordOrStrength(pressedParamButtonId, state.transitionQueue[
         1
       ].asset)
  /\ UNCHANGED state

\* Same pattern pressed again -> fade what is sounding to silence.
theSamePatternWasPressed(pressedParamButtonId) ==
  /\ models(state)
  /\ isTheSamePattern(pressedParamButtonId, state.transitionQueue[1].asset)
  /\ state' =
       PatternSilenceTransitionState!make(<< PatternPlaybackAtItsLastPlayWithScheduledLongFadeout(state.transitionQueue[
                1
              ].asset)
         >>)

\* Any other press -> short crossfade into the patched asset.
theSamePatternWasNotPressed(pressedParamButtonId) ==
  /\ models(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         1
       ].asset)
  /\ state' =
       PatternPatternTransitionState!make(<< PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern(state.transitionQueue[
                1
              ].asset),
            IncomingPatternFadingIn(makePatchedFrom(state.transitionQueue[1].asset, pressedParamButtonId))
         >>)

getNewCleanedUpState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ models(state)
  /\ UNCHANGED state
====
