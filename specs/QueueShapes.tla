------------------------------ MODULE QueueShapes ------------------------------
(*
  A model of the AppPlaybackState machine, ignoring TIME.

  Every action in Machine/ corresponds 1:1 to a branch of `advance()` in one of
  the `Machine/*.ts` files, or to `getNewCleanedUpState` in CleanupFiberMakerLayer.ts.
  This file only holds the graph: Init, the list of transitions, the invariants.

  Deliberate abstractions (things the model refuses to know):

  1. Assets are triples of 4 patterns x 4 chords x 3 strengths = 48 assets.
     What a dimension needs is the number of EQUALITY CLASSES that must be
     distinguishable in one state, not the number of real buttons: a press can
     equal queue element 1, 2, 3, or none of them. Hence 4/4/3, not 8/8/3.
     See the comment above the value sets.

  2. Time is not modelled at all. Every branch the real code picks by comparing
     `now` against a scheduled fadeout time is instead chosen NONDETERMINISTICALLY
     here: both the `...IsStillRevocable` and the `...IsNoLongerRevocable` branch are
     present as alternatives, and the model may take either. That makes this model a
     strict OVER-approximation: it contains behaviours that cannot happen in reality.
       - An invariant that HOLDS here holds in reality too.  <-- the useful part
       - A counterexample found here may be unreachable in reality. You then
         have to replay it against the timing rules to see if it is real.
     Modelling time properly is the next spec (see README, rung 3).

  3. `Effect.die(...)` is modelled as `state.tag = "defect"`: the fiber is dead and
     the SubscriptionRef is never updated again, so the machine stops responding.
     Death is a tag rather than a flag so that every `advance` branch disables
     itself automatically (none of them match that tag) instead of carrying a
     `~halted` guard. The transition queue is dropped at death; the pre-death
     state is already in the trace.

  4. Slow strums: Silence + chord goes to `slowstrum`, and every input while a
     slow strum sounds dies. That is exactly what the code does today.

  Run it:  ./run-tlc.sh specs/QueueShapes.tla -config specs/QueueShapes.cfg
*)
EXTENDS Naturals, Sequences, TLC, Base, SilenceState, Defect

\* One instance per Machine/ file. The instance name is the namespace: that is
\* what lets Machine/Silence.tla call its branches `onPattern` instead of
\* `SilenceState_onPattern`. No Machine/ file declares a variable of its own --
\* they all EXTEND Base, so every instance binds the same `state`.
Silence == INSTANCE Silence
Pattern == INSTANCE Pattern
SlowStrum == INSTANCE SlowStrum
PatternPatternTransition == INSTANCE PatternPatternTransition
PatternSilencePatternTransition == INSTANCE PatternSilencePatternTransition
PatternPatternPatternTransition == INSTANCE PatternPatternPatternTransition
PatternSilenceTransition == INSTANCE PatternSilenceTransition
PatternPatternSilenceTransition == INSTANCE PatternPatternSilenceTransition

Init == state = SilenceState(InitialSelection.chord, InitialSelection.strength)

\* The machine is dead: the fiber is gone and the SubscriptionRef is never updated
\* again, so it stutters forever. Death is a tag, not a flag, which is why every
\* `advance` branch disables itself the moment it happens: none of them match it.
StuttersAfterEffectDie ==
  /\ isDefect(state)
  /\ UNCHANGED state


\* `Next` deliberately does NOT quantify over `Events` in one go. It quantifies over
\* the two variants separately, because the press path reads `.value` and a cleanup
\* event has no value to read. The one-quantifier version needs a guard inside the
\* dispatcher, and a guard is a conjunction, which makes TLC stop naming the branch
\* it took: traces would say `<Handle line 500>` instead of the branch name.
\* Losing the branch name in every counterexample is not worth the tidier shape.
\* That is also why every branch is spelled out here instead of behind a
\* per-state `advance`: TLC names the operator it took in a counterexample, and
\* it cannot see inside an INSTANCE. Listing `Silence!onPattern` here is what
\* keeps traces speaking in branch names.
\* ---------------------------------------------------------------------------
\* Cleanup event  (getNewCleanedUpState in CleanupFiberMakerLayer.ts)
\* Same over-approximation as before: the real event arrives at a fixed offset after
\* the fadeout was scheduled, here it may arrive at any moment. In the timed spec it
\* becomes `now = fireAt` for one of the pending cleanups.
\* ---------------------------------------------------------------------------
Next ==
  \/ \E pressedParamButtonId \in PressedParamButtonIds:
       \/ Silence!onPattern(pressedParamButtonId)
       \/ Silence!onChord(pressedParamButtonId)
       \/ Silence!onStrength(pressedParamButtonId)
       \/ Pattern!theSameChordOrStrengthWasPressed(pressedParamButtonId)
       \/ Pattern!theSamePatternWasPressed(pressedParamButtonId)
       \/ Pattern!theSamePatternWasNotPressed(pressedParamButtonId)
       \/ SlowStrum!advance_EffectDie(pressedParamButtonId)
       \/ PatternPatternTransition!theSameChordOrStrengthWasPressed(pressedParamButtonId)
       \/ PatternPatternTransition!whenFadingOutPlaybackIsStillSafeToRevive_onPressedThePatternOfTheIncomingOne(pressedParamButtonId)
       \/ PatternPatternTransition!whenFadingOutPlaybackIsStillSafeToRevive_onFadingOutAssetBroughtBack(pressedParamButtonId)
       \/ PatternPatternTransition!whenFadingOutPlaybackIsStillSafeToRevive_onPressedAnyOtherPattern(pressedParamButtonId)
       \/ PatternPatternTransition!whenFadingOutPlaybackIsUnsafeToRevive_onPressedThePatternOfTheIncomingOne(pressedParamButtonId)
       \/ PatternPatternTransition!whenFadingOutPlaybackIsUnsafeToRevive_onPressedAnyOtherPattern(pressedParamButtonId)
       \/ PatternSilencePatternTransition!theSameChordOrStrengthWasPressed(pressedParamButtonId)
       \/ PatternSilencePatternTransition!theSamePatternWasPressed_incomingFadeInIsStillRevocable(pressedParamButtonId)
       \/ PatternSilencePatternTransition!theSamePatternWasNotPressed_desiredAssetIsTheDyingOne(pressedParamButtonId)
       \/ PatternSilencePatternTransition!theSamePatternWasPressed_incomingFadeInIsNoLongerRevocable(pressedParamButtonId)
       \/ PatternSilencePatternTransition!theSamePatternWasNotPressed_incomingFadeInIsNoLongerRevocable(pressedParamButtonId)
       \/ PatternSilencePatternTransition!theSamePatternWasNotPressed_incomingFadeInIsStillRevocable(pressedParamButtonId)
       \/ PatternPatternPatternTransition!theSameChordOrStrengthWasPressed(pressedParamButtonId)
       \/ PatternPatternPatternTransition!theSamePatternWasPressed_incomingFadeInIsStillRevocable(pressedParamButtonId)
       \/ PatternPatternPatternTransition!theSamePatternWasPressed_incomingFadeInIsNoLongerRevocable_EffectDie(pressedParamButtonId)
       \/ PatternPatternPatternTransition!theSamePatternWasNotPressed_incomingFadeInIsNoLongerRevocable_EffectDie(pressedParamButtonId)
       \/ PatternPatternPatternTransition!theSamePatternWasNotPressed_incomingFadeInIsStillRevocable(pressedParamButtonId)
       \/ PatternSilenceTransition!theSameChordOrStrengthWasPressed(pressedParamButtonId)
       \/ PatternSilenceTransition!theSamePatternWasPressed_fadingLoopFadeoutIsStillRevocable(pressedParamButtonId)
       \/ PatternSilenceTransition!theSamePatternWasPressed_fadingLoopFadeoutIsNoLongerRevocable_EffectDie(pressedParamButtonId)
       \/ PatternSilenceTransition!theSamePatternWasNotPressed(pressedParamButtonId)
       \/ PatternPatternSilenceTransition!onStrength(pressedParamButtonId)
       \/ PatternPatternSilenceTransition!onChord_EffectDie(pressedParamButtonId)
       \/ PatternPatternSilenceTransition!onPattern(pressedParamButtonId)
  \/ \E cleanupEvent \in CleanupEvents:
       \/ Silence!getNewCleanedUpState(cleanupEvent)
       \/ Pattern!getNewCleanedUpState(cleanupEvent)
       \/ SlowStrum!getNewCleanedUpState(cleanupEvent)
       \/ PatternPatternTransition!getNewCleanedUpState(cleanupEvent)
       \/ PatternSilencePatternTransition!getNewCleanedUpState(cleanupEvent)
       \/ PatternPatternPatternTransition!getNewCleanedUpState(cleanupEvent)
       \/ PatternSilenceTransition!getNewCleanedUpState(cleanupEvent)
       \/ PatternPatternSilenceTransition!getNewCleanedUpState(cleanupEvent)
  \/ StuttersAfterEffectDie

\* The machine's whole life: start in Init, then keep taking Next steps.
\* Every .cfg in this directory refers to this name under SPECIFICATION.
Spec == Init /\ [][Next]_state


\* ===========================================================================
\* Invariants
\* ===========================================================================
\* "The machine never dies." Almost certainly FALSE for the current code — it is
\* here as a question, not as a claim. Uncomment it in a config to make TLC give
\* you the shortest input sequence that kills the playback.
NeverReachedEffectDie == ~isDefect(state)

\* "At most one element of the queue is fading in at any moment." True by
\* construction here; it is in the default config as the worked example of how
\* little it takes to add a question.
AtMostOneIncomingPatternFadingIn ==
  \A i, j \in 1 .. Len(state.transitionQueue):
    state.transitionQueue[i].kind = Element.IncomingPatternFadingIn /\
        state.transitionQueue[j].kind = Element.IncomingPatternFadingIn =>
      i = j

\* Each Machine/ file owns the Schema.Tuple of its state: "if the machine is in
\* my state, my queue holds exactly these kinds". The root only asks every state
\* to answer, the same way `Next` asks every state for its branches. `Defect` has
\* no branch file to hang the predicate on, so its one-liner is the same check,
\* inlined.
TransitionQueueShapesMatchTags ==
  /\ Silence!transitionQueueShapesMatchTag
  /\ Pattern!transitionQueueShapesMatchTag
  /\ SlowStrum!transitionQueueShapesMatchTag
  /\ PatternPatternTransition!transitionQueueShapesMatchTag
  /\ PatternSilencePatternTransition!transitionQueueShapesMatchTag
  /\ PatternPatternPatternTransition!transitionQueueShapesMatchTag
  /\ PatternSilenceTransition!transitionQueueShapesMatchTag
  /\ PatternPatternSilenceTransition!transitionQueueShapesMatchTag
  /\ isDefect(state) => transitionQueueMatchesShape(state, <<>>)

\* No reachable state ever needs a 4th queue slot.
TransitionQueueNeverExceedsThree == Len(state.transitionQueue) <= 3

\* The two states that STORE a selection (SilenceState, PatternPatternSilence-
\* TransitionState) must store the same selection that the destination playback
\* has. `inferSelection` reads these fields, so a mismatch means the UI reports
\* one asset while another one is being scheduled.
StoredSelectionMatchesTheDestinationPlayback ==
  PatternPatternSilenceTransition!is(state) =>
    /\ state.chord    = state.transitionQueue[2].asset.chord
    /\ state.strength = state.transitionQueue[2].asset.strength


\* TLA+ has no "is P reachable?" operator that a beginner should use. The idiom
\* is: check `~P` as an INVARIANT. If TLC reports a violation, then a state where
\* P is true IS reachable, and the printed trace is the proof.
\* ===========================================================================
\* A full queue whose three elements have three pairwise different patterns.
\* This is exactly the layout a 2-values-per-dimension model cannot even write
\* down. See README §4d.
FullTransitionQueueWithThreeDistinctPatterns ==
  /\ PatternPatternPatternTransition!is(state)
  /\ state.transitionQueue[1].asset.pattern #
       state.transitionQueue[2].asset.pattern
  /\ state.transitionQueue[1].asset.pattern #
       state.transitionQueue[3].asset.pattern
  /\ state.transitionQueue[2].asset.pattern #
       state.transitionQueue[3].asset.pattern

NoFullTransitionQueueWithThreeDistinctPatterns ==
  ~FullTransitionQueueWithThreeDistinctPatterns
====
