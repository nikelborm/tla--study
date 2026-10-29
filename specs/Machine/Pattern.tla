---- MODULE Pattern ----
\* ---------------------------------------------------------------------------
\* PatternState.advance  (Machine/Pattern⏳.ts)
\* ---------------------------------------------------------------------------
EXTENDS Base, States, Elements

\* Machine/Pattern⏳.ts: PatternQueue = Schema.Tuple([PatternPlayback]).
expectedElementKinds == << PatternPlayback!Tag >>

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
       PatternSilenceTransitionState!make(<< PatternPlaybackAtItsLastPlayWithScheduledLongFadeout!make(state.transitionQueue[
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
       PatternPatternTransitionState!make(<< PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern!make(state.transitionQueue[
                1
              ].asset),
            IncomingPatternFadingIn!make(makePatchedFrom(state.transitionQueue[1].asset, pressedParamButtonId))
         >>)

getNewCleanedUpState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ models(state)
  /\ UNCHANGED state
====
