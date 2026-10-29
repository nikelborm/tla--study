---- MODULE Pattern ----
\* ---------------------------------------------------------------------------
\* PatternState.advance  (Machine/Pattern⏳.ts)
\* ---------------------------------------------------------------------------
EXTENDS Base,
        PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern,
        PatternPlaybackAtItsLastPlayWithScheduledLongFadeout,
        IncomingPatternFadingIn,
        PatternState,
        PatternPatternTransitionState,
        PatternSilenceTransitionState

\* Machine/Pattern⏳.ts: PatternQueue = Schema.Tuple([PatternPlayback]).
expectedElementKinds == << Element.PatternPlayback >>

is(s) == isInState(PatternTag, s)

transitionQueueShapesMatchTag ==
  is(state) => transitionQueueMatchesShape(state, expectedElementKinds)

theSameChordOrStrengthWasPressed(pressedParamButtonId) ==
  /\ is(state)
  /\ isTheSameChordOrStrength(pressedParamButtonId, state.transitionQueue[
         1
       ].asset)
  /\ UNCHANGED state

\* Same pattern pressed again -> fade what is sounding to silence.
theSamePatternWasPressed(pressedParamButtonId) ==
  /\ is(state)
  /\ isTheSamePattern(pressedParamButtonId, state.transitionQueue[1].asset)
  /\ state' =
       PatternSilenceTransitionState(<< PatternPlaybackAtItsLastPlayWithScheduledLongFadeout(state.transitionQueue[
                1
              ].asset)
         >>)

\* Any other press -> short crossfade into the patched asset.
theSamePatternWasNotPressed(pressedParamButtonId) ==
  /\ is(state)
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         1
       ].asset)
  /\ state' =
       PatternPatternTransitionState(<< PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern(state.transitionQueue[
                1
              ].asset),
            IncomingPatternFadingIn(makePatchedFrom(state.transitionQueue[1].asset, pressedParamButtonId))
         >>)

getNewCleanedUpState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ is(state)
  /\ UNCHANGED state
====
