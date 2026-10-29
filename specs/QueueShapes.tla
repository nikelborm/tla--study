------------------------------ MODULE QueueShapes ------------------------------
(*
  A model of the AppPlaybackState machine, ignoring TIME.

  Every action below corresponds 1:1 to a branch of `advance()` in one of the
  `Machine/*.ts` files, or to `getNewCleanedUpState` in CleanupFiberMakerLayer.ts.

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

  3. `Effect.die(...)` is modelled as `state.tag = "died"`: the fiber is dead and
     the SubscriptionRef is never updated again, so the machine stops responding.
     Death is a tag rather than a flag so that every `advance` branch disables
     itself automatically (none of them match that tag) instead of carrying a
     `~halted` guard. The transition queue is dropped at death; the pre-death
     state is already in the trace.

  4. Slow strums: Silence + chord goes to `slowstrum`, and every input while a
     slow strum sounds dies. That is exactly what the code does today.

  Run it:  ./run-tlc.sh QueueShapes.tla -config QueueShapes.cfg
*)
EXTENDS Naturals, Sequences, TLC

(* A CONSTANT is the TLA+ version of "make this model configurable". Slow strums
   are the known deferred hole in the machine, so being able to switch them off
   lets you ask the more interesting question: how does the machine die when you
   press only the buttons that are supposed to work? *)
CONSTANT SlowStrums

ASSUME SlowStrums \in BOOLEAN

(*
  How many VALUES a dimension needs is set by the number of equality classes
  that must be distinguishable in ONE state, not by the number of real buttons.

  A queue holds at most 3 elements, so a press can be: equal to element 1, equal
  to element 2, equal to element 3, or equal to none of them. That is 4 classes,
  for the dimensions where a 4th ("none of those") value can exist.

  - pattern: 8 buttons exist, so the 4th class is real -> 4 values
  - chord:   8 buttons exist, so the 4th class is real -> 4 values
  - strength: only 3 buttons exist, so when the queue already holds all three
    distinct strengths there IS no "none of those" -> 3 values

  Using 8/8/3 here would only add isomorphic copies of behaviours already
  covered (the machine never counts patterns, it only compares them), and would
  cost (192/48)^3 = 64x more states for nothing.
*)
Patterns == { "p1", "p2", "p3", "p4" }
Chords == { "c1", "c2", "c3", "c4" }
Strengths == { "s1", "s2", "s3" }

\* ---------------------------------------------------------------------------
\* String constants. Every tag and kind the machine compares against lives here
\* exactly once — use these records, never a string literal. A typo in a field
\* name (e.g. Element.IncomingPayternFadingIn) fails loudly instead of
\* silently comparing false the way a misspelled literal would.
\* ---------------------------------------------------------------------------
State ==
  [ Silence |-> "SilenceState",
    Pattern |-> "PatternState",
    SlowStrum |-> "SlowStrumState",
    PatternPatternTransition |-> "PatternPatternTransitionState",
    PatternSilencePatternTransition |-> "PatternSilencePatternTransitionState",
    PatternPatternPatternTransition |-> "PatternPatternPatternTransitionState",
    PatternSilenceTransition |-> "PatternSilenceTransitionState",
    PatternPatternSilenceTransition |-> "PatternPatternSilenceTransitionState",
    Defect |-> "defect"
  ]

Element ==
  [ PatternPlayback |-> "PatternPlayback",
    PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern |->
      "PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern",
    PatternPlaybackAtItsLastPlayWithScheduledLongFadeout |->
      "PatternPlaybackAtItsLastPlayWithScheduledLongFadeout",
    IncomingPatternFadingIn |-> "IncomingPatternFadingIn"
  ]

EventKinds ==
  [ pattern |-> "pattern",
    chord |-> "chord",
    strength |-> "strength",
    cleanup |-> "cleanup"
  ]

\* The chord/strength the machine starts with (Init). A literal that must also
\* exist exactly once.
InitialSelection == [ chord |-> "c1", strength |-> "s1" ]

TaggedPatternPointer_makeSimple(pattern, chord, strength) ==
  [ pattern |-> pattern, chord |-> chord, strength |-> strength ]

TaggedPatternPointers == [pattern:Patterns, chord:Chords, strength:Strengths ]

\* The event type. One union of mutually exclusive variants, exactly like the
\* stream that feeds `advance()` in AppPlaybackStateService: the three MIDI buses
\* merged into `PressedParamButtonId`, plus the cleanup timer.
\*
\* `kind` is a singleton set in each variant, so the four variants are disjoint by
\* construction: an event IS one of these, never a mix.
\*
\* When time arrives, the two payloads that get added are:
\*   press   -> at      (the timestamp the machine reads instead of GetAudioNow)
\*   cleanup -> fireAt  (the absolute second it was scheduled for)
\* They are not the same kind of number: `at` is delivered by the environment,
\* `fireAt` is decided when the fadeout is scheduled. That is why the cleanup event
\* is in here but "schedule a cleanup" is not: scheduling is a side effect of an
\* action, not something the environment can hand you.
Event(k) == [ kind |-> k ]

PatternPresses == [kind:{ EventKinds.pattern }, value:Patterns ]
ChordPresses == [kind:{ EventKinds.chord }, value:Chords ]
StrengthPresses == [kind:{ EventKinds.strength }, value:Strengths ]
CleanupEvents == { Event(EventKinds.cleanup) }

PressedParamButtonIds == PatternPresses \cup ChordPresses \cup StrengthPresses

Events == PressedParamButtonIds \cup CleanupEvents


\* `Next` deliberately does NOT quantify over `Events` in one go. It quantifies over
\* the two variants separately, because the press path reads `.value` and a cleanup
\* event has no value to read. The one-quantifier version needs a guard inside the
\* dispatcher, and a guard is a conjunction, which makes TLC stop naming the branch
\* it took: traces would say `<Handle line 500>` instead of the branch name.
\* Losing the branch name in every counterexample is not worth the tidier shape.
\* helpers/theSameWasPressed.ts
theSameChordOrStrengthWasPressed(pressedParamButtonId, asset) ==
  \/ pressedParamButtonId.kind = EventKinds.chord /\
       pressedParamButtonId.value = asset.chord
  \/ pressedParamButtonId.kind = EventKinds.strength /\
       pressedParamButtonId.value = asset.strength

theSamePatternWasPressed(pressedParamButtonId, asset) ==
  pressedParamButtonId.kind = EventKinds.pattern /\
    pressedParamButtonId.value = asset.pattern

\* The two negations below are ONE concept, and it already has a name in the codebase:
\* `arbitraryPressChangingTheSoundingAsset` in Pattern.spec.ts filters on exactly this
\* pair. Every branch that goes somewhere other than a no-op or a fade-to-silence needs
\* it, so it is stated once instead of twice in eleven branches.
thePressChangesTheSoundingAsset(pressedParamButtonId, asset) ==
  /\ ~theSameChordOrStrengthWasPressed(pressedParamButtonId, asset)
  /\ ~theSamePatternWasPressed(pressedParamButtonId, asset)

\* TaggedPatternPointer.makePatchedFrom
makePatchedFrom(asset, pressedParamButtonId) ==
  CASE pressedParamButtonId.kind = EventKinds.pattern ->
  [asset EXCEPT !.pattern = pressedParamButtonId.value]
  [] pressedParamButtonId.kind = EventKinds.chord ->
  [asset EXCEPT !.chord = pressedParamButtonId.value]
  [] OTHER-> [asset EXCEPT !.strength = pressedParamButtonId.value]

\* Queue elements. `kind` is the element class, spelled exactly like the class in
\* Elements/, and `asset` is what it wraps.
PatternPlayback(asset) == [ kind |-> Element.PatternPlayback, asset |-> asset ]

PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern(asset) ==
  [ kind |->
      Element.PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern,
    asset |-> asset
  ]

PatternPlaybackAtItsLastPlayWithScheduledLongFadeout(asset) ==
  [ kind |-> Element.PatternPlaybackAtItsLastPlayWithScheduledLongFadeout,
    asset |-> asset
  ]

IncomingPatternFadingIn(asset) ==
  [ kind |-> Element.IncomingPatternFadingIn, asset |-> asset ]

StateRecord(tag, transitionQueue, chord, strength) ==
  [ tag |-> tag,
    transitionQueue |-> transitionQueue,
    chord |-> chord,
    strength |-> strength
  ]

\* `none` means "this state does not store a selection; it derives it from the
\* queue". Only SilenceState and PatternPatternSilenceTransitionState store it.
noStoredSelection == "noStoredSelection"

\* Every state variant has its own constructor, so a caller never spells the tag or
\* a field the variant does not store. `StateRecord` stays as the one place the
\* record shape is written down.
SilenceState(chord, strength) ==
  StateRecord(State.Silence, <<>>, chord, strength)

PatternState(transitionQueue) ==
  StateRecord(State.Pattern, transitionQueue, noStoredSelection, noStoredSelection)

SlowStrumState(chord, strength) ==
  StateRecord(State.SlowStrum, <<>>, chord, strength)

PatternPatternTransitionState(transitionQueue) ==
  StateRecord(State.PatternPatternTransition, transitionQueue, noStoredSelection, noStoredSelection)

PatternSilencePatternTransitionState(transitionQueue) ==
  StateRecord(State.PatternSilencePatternTransition, transitionQueue, noStoredSelection, noStoredSelection)

PatternPatternPatternTransitionState(transitionQueue) ==
  StateRecord(State.PatternPatternPatternTransition, transitionQueue, noStoredSelection, noStoredSelection)

PatternSilenceTransitionState(transitionQueue) ==
  StateRecord(State.PatternSilenceTransition, transitionQueue, noStoredSelection, noStoredSelection)

PatternPatternSilenceTransitionState(transitionQueue, chord, strength) ==
  StateRecord(State.PatternPatternSilenceTransition, transitionQueue, chord, strength)

Defect == StateRecord(State.Defect, <<>>, noStoredSelection, noStoredSelection)

VARIABLE state

Init == state = SilenceState(InitialSelection.chord, InitialSelection.strength)

\* ---------------------------------------------------------------------------
\* SilenceState.advance  (Machine/Silence🏁.ts)
\* ---------------------------------------------------------------------------
SilenceState_onPattern(pressedParamButtonId) ==
  /\ state.tag = State.Silence
  /\ pressedParamButtonId.kind = EventKinds.pattern
  /\ state' =
       PatternState(<< PatternPlayback(TaggedPatternPointer_makeSimple(pressedParamButtonId.value, state.chord, state.strength))
         >>)

SilenceState_onChord(pressedParamButtonId) ==
  /\ SlowStrums
  /\ state.tag = State.Silence
  /\ pressedParamButtonId.kind = EventKinds.chord
  /\ state' = SlowStrumState(pressedParamButtonId.value, state.strength)

SilenceState_onStrength(pressedParamButtonId) ==
  /\ state.tag = State.Silence
  /\ pressedParamButtonId.kind = EventKinds.strength
  /\ state' = SilenceState(state.chord, pressedParamButtonId.value)

\* SlowStrumState.advance: any input dies.
SlowStrumState_advance_EffectDie(pressedParamButtonId) ==
  /\ SlowStrums
  /\ state.tag = State.SlowStrum
  /\ state' = Defect

\* ---------------------------------------------------------------------------
\* PatternState.advance  (Machine/Pattern⏳.ts)
\* ---------------------------------------------------------------------------
PatternState_theSameChordOrStrengthWasPressed(pressedParamButtonId) ==
  /\ state.tag = State.Pattern
  /\ theSameChordOrStrengthWasPressed(pressedParamButtonId, state.transitionQueue[
         1
       ].asset)
  /\ UNCHANGED state

\* Same pattern pressed again -> fade what is sounding to silence.
PatternState_theSamePatternWasPressed(pressedParamButtonId) ==
  /\ state.tag = State.Pattern
  /\ theSamePatternWasPressed(pressedParamButtonId, state.transitionQueue[1].asset)
  /\ state' =
       PatternSilenceTransitionState(<< PatternPlaybackAtItsLastPlayWithScheduledLongFadeout(state.transitionQueue[
                1
              ].asset)
         >>)

\* Any other press -> short crossfade into the patched asset.
PatternState_theSamePatternWasNotPressed(pressedParamButtonId) ==
  /\ state.tag = State.Pattern
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         1
       ].asset)
  /\ state' =
       PatternPatternTransitionState(<< PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern(state.transitionQueue[
                1
              ].asset),
            IncomingPatternFadingIn(makePatchedFrom(state.transitionQueue[1].asset, pressedParamButtonId))
         >>)

\* ---------------------------------------------------------------------------
\* PatternPatternTransitionState.advance  (Machine/PatternPatternTransition⏳.ts)
\* The real code picks the safe/unsafe pair by comparing `now` to
\* `patternPlaybackAntialiasingFadeout_STARTS... - schedulingSafeBufferInSeconds`.
\* The safe/unsafe split is `now` against a scheduled fadeout time. Time is erased
\* here, so both variants of the split are present as separate branches and the
\* model may take either.
\* ---------------------------------------------------------------------------
PatternPatternTransitionState_theSameChordOrStrengthWasPressed(pressedParamButtonId) ==
  /\ state.tag = State.PatternPatternTransition
  /\ theSameChordOrStrengthWasPressed(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ UNCHANGED state

PatternPatternTransitionState_whenFadingOutPlaybackIsStillSafeToRevive_onPressedThePatternOfTheIncomingOne(pressedParamButtonId) ==
  /\ state.tag = State.PatternPatternTransition
  /\ theSamePatternWasPressed(pressedParamButtonId, state.transitionQueue[2].asset)
  /\ state' =
       PatternSilenceTransitionState(<< PatternPlaybackAtItsLastPlayWithScheduledLongFadeout(state.transitionQueue[
                1
              ].asset)
         >>)

PatternPatternTransitionState_whenFadingOutPlaybackIsStillSafeToRevive_onFadingOutAssetBroughtBack(pressedParamButtonId) ==
  /\ state.tag = State.PatternPatternTransition
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId) =
       state.transitionQueue[1].asset
  /\ state' =
       PatternState(<< PatternPlayback(state.transitionQueue[1].asset) >>)

PatternPatternTransitionState_whenFadingOutPlaybackIsStillSafeToRevive_onPressedAnyOtherPattern(pressedParamButtonId) ==
  /\ state.tag = State.PatternPatternTransition
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId) #
       state.transitionQueue[1].asset
  /\ state' =
       PatternPatternTransitionState(<< state.transitionQueue[1],
            IncomingPatternFadingIn(makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId))
         >>)

PatternPatternTransitionState_whenFadingOutPlaybackIsUnsafeToRevive_onPressedThePatternOfTheIncomingOne(pressedParamButtonId) ==
  /\ state.tag = State.PatternPatternTransition
  /\ theSamePatternWasPressed(pressedParamButtonId, state.transitionQueue[2].asset)
  /\ state' =
       PatternPatternSilenceTransitionState(<< state.transitionQueue[1],
            PatternPlaybackAtItsLastPlayWithScheduledLongFadeout(state.transitionQueue[
                2
              ].asset)
         >>, state.transitionQueue[2].asset.chord, state.transitionQueue[
           2
         ].asset.strength)

PatternPatternTransitionState_whenFadingOutPlaybackIsUnsafeToRevive_onPressedAnyOtherPattern(pressedParamButtonId) ==
  /\ state.tag = State.PatternPatternTransition
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

\* ---------------------------------------------------------------------------
\* PatternSilencePatternTransitionState.advance  (Machine/PatternSilencePatternTransition.ts)
\* The split is `now <= patternPlaybackAntialiasingFadein_STARTS_AT_SECONDS_SinceAudioContextInit
\* - schedulingSafeBufferInSeconds`. Time is erased, so both sides are branches.
\* ---------------------------------------------------------------------------
PatternSilencePatternTransitionState_theSameChordOrStrengthWasPressed(pressedParamButtonId) ==
  /\ state.tag = State.PatternSilencePatternTransition
  /\ theSameChordOrStrengthWasPressed(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ UNCHANGED state

PatternSilencePatternTransitionState_theSamePatternWasPressed_incomingFadeInIsStillRevocable(pressedParamButtonId) ==
  /\ state.tag = State.PatternSilencePatternTransition
  /\ theSamePatternWasPressed(pressedParamButtonId, state.transitionQueue[2].asset)
  /\ state' =
       PatternSilenceTransitionState(<< PatternPlaybackAtItsLastPlayWithScheduledLongFadeout(state.transitionQueue[
                1
              ].asset)
         >>)

PatternSilencePatternTransitionState_theSamePatternWasNotPressed_desiredAssetIsTheDyingOne(pressedParamButtonId) ==
  /\ state.tag = State.PatternSilencePatternTransition
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         2
       ].asset)
  /\ makePatchedFrom(state.transitionQueue[2].asset, pressedParamButtonId) =
       state.transitionQueue[1].asset
  /\ state' =
       PatternState(<< PatternPlayback(state.transitionQueue[1].asset) >>)

PatternSilencePatternTransitionState_theSamePatternWasPressed_incomingFadeInIsNoLongerRevocable(pressedParamButtonId) ==
  /\ state.tag = State.PatternSilencePatternTransition
  /\ theSamePatternWasPressed(pressedParamButtonId, state.transitionQueue[2].asset)
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

PatternSilencePatternTransitionState_theSamePatternWasNotPressed_incomingFadeInIsNoLongerRevocable(pressedParamButtonId) ==
  /\ state.tag = State.PatternSilencePatternTransition
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

PatternSilencePatternTransitionState_theSamePatternWasNotPressed_incomingFadeInIsStillRevocable(pressedParamButtonId) ==
  /\ state.tag = State.PatternSilencePatternTransition
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

\* ---------------------------------------------------------------------------
\* PatternPatternPatternTransitionState.advance  (Machine/PatternPatternPatternTransition.ts)
\* ---------------------------------------------------------------------------
PatternPatternPatternTransitionState_theSameChordOrStrengthWasPressed(pressedParamButtonId) ==
  /\ state.tag = State.PatternPatternPatternTransition
  /\ theSameChordOrStrengthWasPressed(pressedParamButtonId, state.transitionQueue[
         3
       ].asset)
  /\ UNCHANGED state

\* ⚠️ This is the branch that builds a PatternPatternSilenceTransitionState out of
\* `middle`, which is a SHORT-fading element, not a long-fading one. The model
\* keeps the code as-is; `TransitionQueueShapesMatchTags` is what objects.
PatternPatternPatternTransitionState_theSamePatternWasPressed_incomingFadeInIsStillRevocable(pressedParamButtonId) ==
  /\ state.tag = State.PatternPatternPatternTransition
  /\ theSamePatternWasPressed(pressedParamButtonId, state.transitionQueue[3].asset)
  /\ state' =
       PatternPatternSilenceTransitionState(<< state.transitionQueue[1],
            state.transitionQueue[2]
         >>, state.transitionQueue[3].asset.chord, state.transitionQueue[
           3
         ].asset.strength)

\* "a 4th input" -> die
PatternPatternPatternTransitionState_theSamePatternWasPressed_incomingFadeInIsNoLongerRevocable_EffectDie(pressedParamButtonId) ==
  /\ state.tag = State.PatternPatternPatternTransition
  /\ theSamePatternWasPressed(pressedParamButtonId, state.transitionQueue[3].asset)
  /\ state' = Defect

\* "a 4th input" -> die
PatternPatternPatternTransitionState_theSamePatternWasNotPressed_incomingFadeInIsNoLongerRevocable_EffectDie(pressedParamButtonId) ==
  /\ state.tag = State.PatternPatternPatternTransition
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         3
       ].asset)
  /\ state' = Defect

PatternPatternPatternTransitionState_theSamePatternWasNotPressed_incomingFadeInIsStillRevocable(pressedParamButtonId) ==
  /\ state.tag = State.PatternPatternPatternTransition
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         3
       ].asset)
  /\ state' =
       PatternPatternPatternTransitionState(<< state.transitionQueue[1],
            state.transitionQueue[2],
            IncomingPatternFadingIn(makePatchedFrom(state.transitionQueue[3].asset, pressedParamButtonId))
         >>)

\* ---------------------------------------------------------------------------
\* PatternSilenceTransitionState.advance  (Machine/PatternSilenceTransition.ts)
\* The split is `now <= patternPlaybackAntialiasingFadeout_STARTS_AT_SECONDS_SinceAudioContextInit
\* - schedulingSafeBufferInSeconds`. Time is erased, so both sides are branches.
\* ---------------------------------------------------------------------------
PatternSilenceTransitionState_theSameChordOrStrengthWasPressed(pressedParamButtonId) ==
  /\ state.tag = State.PatternSilenceTransition
  /\ theSameChordOrStrengthWasPressed(pressedParamButtonId, state.transitionQueue[
         1
       ].asset)
  /\ UNCHANGED state

PatternSilenceTransitionState_theSamePatternWasPressed_fadingLoopFadeoutIsStillRevocable(pressedParamButtonId) ==
  /\ state.tag = State.PatternSilenceTransition
  /\ theSamePatternWasPressed(pressedParamButtonId, state.transitionQueue[1].asset)
  /\ state' =
       PatternState(<< PatternPlayback(state.transitionQueue[1].asset) >>)

PatternSilenceTransitionState_theSamePatternWasPressed_fadingLoopFadeoutIsNoLongerRevocable_EffectDie(pressedParamButtonId) ==
  /\ state.tag = State.PatternSilenceTransition
  /\ theSamePatternWasPressed(pressedParamButtonId, state.transitionQueue[1].asset)
  /\ state' = Defect

PatternSilenceTransitionState_theSamePatternWasNotPressed(pressedParamButtonId) ==
  /\ state.tag = State.PatternSilenceTransition
  /\ thePressChangesTheSoundingAsset(pressedParamButtonId, state.transitionQueue[
         1
       ].asset)
  /\ state' =
       PatternSilencePatternTransitionState(<< state.transitionQueue[1],
            IncomingPatternFadingIn(makePatchedFrom(state.transitionQueue[1].asset, pressedParamButtonId))
         >>)

\* ---------------------------------------------------------------------------
\* PatternPatternSilenceTransitionState.advance  (Machine/PatternPatternSilenceTransition.ts)
\* ---------------------------------------------------------------------------
PatternPatternSilenceTransitionState_onStrength(pressedParamButtonId) ==
  /\ state.tag = State.PatternPatternSilenceTransition
  /\ pressedParamButtonId.kind = EventKinds.strength
  /\ state' =
       PatternPatternSilenceTransitionState(state.transitionQueue, state.chord, pressedParamButtonId.value)

PatternPatternSilenceTransitionState_onChord_EffectDie(pressedParamButtonId) ==
  /\ state.tag = State.PatternPatternSilenceTransition
  /\ pressedParamButtonId.kind = EventKinds.chord
  /\ state' = Defect

PatternPatternSilenceTransitionState_onPattern(pressedParamButtonId) ==
  /\ state.tag = State.PatternPatternSilenceTransition
  /\ pressedParamButtonId.kind = EventKinds.pattern
  /\ state' =
       PatternPatternPatternTransitionState(<< state.transitionQueue[1],
            PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern(state.transitionQueue[
                2
              ].asset),
            IncomingPatternFadingIn(TaggedPatternPointer_makeSimple(pressedParamButtonId.value, state.chord, state.strength))
         >>)

\* ---------------------------------------------------------------------------
\* Cleanup event  (getNewCleanedUpState in CleanupFiberMakerLayer.ts)
\* Same over-approximation as before: the real event arrives at a fixed offset after
\* the fadeout was scheduled, here it may arrive at any moment. In the timed spec it
\* becomes `now = fireAt` for one of the pending cleanups.
\* ---------------------------------------------------------------------------
GetNewCleanedUpStateOnSilenceState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ state.tag = State.Silence
  /\ UNCHANGED state

GetNewCleanedUpStateOnPatternState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ state.tag = State.Pattern
  /\ UNCHANGED state

GetNewCleanedUpStateOnSlowStrumState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ state.tag = State.SlowStrum
  /\ UNCHANGED state

GetNewCleanedUpStateOnPatternPatternTransitionState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ state.tag = State.PatternPatternTransition
  /\ state' =
       PatternState(<< PatternPlayback(state.transitionQueue[2].asset) >>)

GetNewCleanedUpStateOnPatternSilencePatternTransitionState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ state.tag = State.PatternSilencePatternTransition
  /\ state' =
       PatternState(<< PatternPlayback(state.transitionQueue[2].asset) >>)

GetNewCleanedUpStateOnPatternPatternPatternTransitionState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ state.tag = State.PatternPatternPatternTransition
  /\ state' =
       PatternPatternTransitionState(<< state.transitionQueue[2],
            state.transitionQueue[3]
         >>)

GetNewCleanedUpStateOnPatternSilenceTransitionState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ state.tag = State.PatternSilenceTransition
  /\ state' =
       SilenceState(state.transitionQueue[1].asset.chord, state.transitionQueue[1].asset.strength)

GetNewCleanedUpStateOnPatternPatternSilenceTransitionState(cleanupEvent) ==
  /\ cleanupEvent.kind = EventKinds.cleanup
  /\ state.tag = State.PatternPatternSilenceTransition
  /\ state' =
       PatternSilenceTransitionState(<< PatternPlaybackAtItsLastPlayWithScheduledLongFadeout(state.transitionQueue[
                2
              ].asset)
         >>)

\* ---------------------------------------------------------------------------
\* Dispatch. Two entry points, because the app has two consumers of the state:
\* `advance()` consumes presses, `getNewCleanedUpState()` consumes the timer. Both
\* switch on the state tag. Keeping them apart is not cosmetic: they consume
\* different variants of `Events`, and a cleanup event has no `value` to read.
\* ---------------------------------------------------------------------------
\* SilenceState.advance
SilenceState_advance(pressedParamButtonId) ==
  \/ SilenceState_onPattern(pressedParamButtonId)
  \/ SilenceState_onChord(pressedParamButtonId)
  \/ SilenceState_onStrength(pressedParamButtonId)

\* PatternState.advance
PatternState_advance(pressedParamButtonId) ==
  \/ PatternState_theSameChordOrStrengthWasPressed(pressedParamButtonId)
  \/ PatternState_theSamePatternWasPressed(pressedParamButtonId)
  \/ PatternState_theSamePatternWasNotPressed(pressedParamButtonId)

\* SlowStrumState.advance
SlowStrumState_advance(pressedParamButtonId) ==
  \/ SlowStrumState_advance_EffectDie(pressedParamButtonId)

\* PatternPatternTransitionState.advance
PatternPatternTransitionState_advance(pressedParamButtonId) ==
  \/ PatternPatternTransitionState_theSameChordOrStrengthWasPressed(pressedParamButtonId)
  \/ PatternPatternTransitionState_whenFadingOutPlaybackIsStillSafeToRevive_onPressedThePatternOfTheIncomingOne(pressedParamButtonId)
  \/ PatternPatternTransitionState_whenFadingOutPlaybackIsUnsafeToRevive_onPressedThePatternOfTheIncomingOne(pressedParamButtonId)
  \/ PatternPatternTransitionState_whenFadingOutPlaybackIsStillSafeToRevive_onFadingOutAssetBroughtBack(pressedParamButtonId)
  \/ PatternPatternTransitionState_whenFadingOutPlaybackIsStillSafeToRevive_onPressedAnyOtherPattern(pressedParamButtonId)
  \/ PatternPatternTransitionState_whenFadingOutPlaybackIsUnsafeToRevive_onPressedAnyOtherPattern(pressedParamButtonId)

\* PatternSilencePatternTransitionState.advance
PatternSilencePatternTransitionState_advance(pressedParamButtonId) ==
  \/ PatternSilencePatternTransitionState_theSameChordOrStrengthWasPressed(pressedParamButtonId)
  \/ PatternSilencePatternTransitionState_theSamePatternWasPressed_incomingFadeInIsStillRevocable(pressedParamButtonId)
  \/ PatternSilencePatternTransitionState_theSamePatternWasPressed_incomingFadeInIsNoLongerRevocable(pressedParamButtonId)
  \/ PatternSilencePatternTransitionState_theSamePatternWasNotPressed_incomingFadeInIsStillRevocable(pressedParamButtonId)
  \/ PatternSilencePatternTransitionState_theSamePatternWasNotPressed_desiredAssetIsTheDyingOne(pressedParamButtonId)
  \/ PatternSilencePatternTransitionState_theSamePatternWasNotPressed_incomingFadeInIsNoLongerRevocable(pressedParamButtonId)

\* PatternPatternPatternTransitionState.advance
PatternPatternPatternTransitionState_advance(pressedParamButtonId) ==
  \/ PatternPatternPatternTransitionState_theSameChordOrStrengthWasPressed(pressedParamButtonId)
  \/ PatternPatternPatternTransitionState_theSamePatternWasPressed_incomingFadeInIsStillRevocable(pressedParamButtonId)
  \/ PatternPatternPatternTransitionState_theSamePatternWasPressed_incomingFadeInIsNoLongerRevocable_EffectDie(pressedParamButtonId)
  \/ PatternPatternPatternTransitionState_theSamePatternWasNotPressed_incomingFadeInIsStillRevocable(pressedParamButtonId)
  \/ PatternPatternPatternTransitionState_theSamePatternWasNotPressed_incomingFadeInIsNoLongerRevocable_EffectDie(pressedParamButtonId)

\* PatternSilenceTransitionState.advance
PatternSilenceTransitionState_advance(pressedParamButtonId) ==
  \/ PatternSilenceTransitionState_theSameChordOrStrengthWasPressed(pressedParamButtonId)
  \/ PatternSilenceTransitionState_theSamePatternWasPressed_fadingLoopFadeoutIsStillRevocable(pressedParamButtonId)
  \/ PatternSilenceTransitionState_theSamePatternWasPressed_fadingLoopFadeoutIsNoLongerRevocable_EffectDie(pressedParamButtonId)
  \/ PatternSilenceTransitionState_theSamePatternWasNotPressed(pressedParamButtonId)

\* PatternPatternSilenceTransitionState.advance
PatternPatternSilenceTransitionState_advance(pressedParamButtonId) ==
  \/ PatternPatternSilenceTransitionState_onStrength(pressedParamButtonId)
  \/ PatternPatternSilenceTransitionState_onChord_EffectDie(pressedParamButtonId)
  \/ PatternPatternSilenceTransitionState_onPattern(pressedParamButtonId)

Advance(pressedParamButtonId) ==
  \/ SilenceState_advance(pressedParamButtonId)
  \/ PatternState_advance(pressedParamButtonId)
  \/ SlowStrumState_advance(pressedParamButtonId)
  \/ PatternPatternTransitionState_advance(pressedParamButtonId)
  \/ PatternSilencePatternTransitionState_advance(pressedParamButtonId)
  \/ PatternPatternPatternTransitionState_advance(pressedParamButtonId)
  \/ PatternSilenceTransitionState_advance(pressedParamButtonId)
  \/ PatternPatternSilenceTransitionState_advance(pressedParamButtonId)

GetNewCleanedUpState(cleanupEvent) ==
  \/ GetNewCleanedUpStateOnSilenceState(cleanupEvent)
  \/ GetNewCleanedUpStateOnPatternState(cleanupEvent)
  \/ GetNewCleanedUpStateOnSlowStrumState(cleanupEvent)
  \/ GetNewCleanedUpStateOnPatternPatternTransitionState(cleanupEvent)
  \/ GetNewCleanedUpStateOnPatternSilencePatternTransitionState(cleanupEvent)
  \/ GetNewCleanedUpStateOnPatternPatternPatternTransitionState(cleanupEvent)
  \/ GetNewCleanedUpStateOnPatternSilenceTransitionState(cleanupEvent)
  \/ GetNewCleanedUpStateOnPatternPatternSilenceTransitionState(cleanupEvent)

\* The machine is dead: the fiber is gone and the SubscriptionRef is never updated
\* again, so it stutters forever. Death is a tag, not a flag, which is why every
\* `advance` branch disables itself the moment it happens: none of them match it.
StuttersAfterEffectDie ==
  /\ state.tag = State.Defect
  /\ UNCHANGED state

Next ==
  \/ ( \E pressedParamButtonId \in PressedParamButtonIds:
         Advance(pressedParamButtonId)
     )
  \/ ( \E cleanupEvent \in CleanupEvents: GetNewCleanedUpState(cleanupEvent) )
  \/ StuttersAfterEffectDie


\* ===========================================================================
\* Invariants
\* ===========================================================================
\* "The machine never dies." Almost certainly FALSE for the current code — it is
\* here as a question, not as a claim. Uncomment it in a config to make TLC give
\* you the shortest input sequence that kills the playback.
NeverReachedEffectDie == state.tag # State.Defect

\* "At most one element of the queue is fading in at any moment." True by
\* construction here; it is in the default config as the worked example of how
\* little it takes to add a question.
AtMostOneIncomingPatternFadingIn ==
  \A i, j \in 1 .. Len(state.transitionQueue):
    state.transitionQueue[i].kind = Element.IncomingPatternFadingIn /\
        state.transitionQueue[j].kind = Element.IncomingPatternFadingIn =>
      i = j


\* TLA+ has no "is P reachable?" operator that a beginner should use. The idiom
\* is: check `~P` as an INVARIANT. If TLC reports a violation, then a state where
\* P is true IS reachable, and the printed trace is the proof.
\* ===========================================================================
\* A full queue whose three elements have three pairwise different patterns.
\* This is exactly the layout a 2-values-per-dimension model cannot even write
\* down. See README §4d.
FullTransitionQueueWithThreeDistinctPatterns ==
  /\ state.tag = State.PatternPatternPatternTransition
  /\ state.transitionQueue[1].asset.pattern #
       state.transitionQueue[2].asset.pattern
  /\ state.transitionQueue[1].asset.pattern #
       state.transitionQueue[3].asset.pattern
  /\ state.transitionQueue[2].asset.pattern #
       state.transitionQueue[3].asset.pattern

NoFullTransitionQueueWithThreeDistinctPatterns ==
  ~FullTransitionQueueWithThreeDistinctPatterns

====
