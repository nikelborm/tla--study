---- MODULE Base ----
(*
  Everything the Machine/ files and the Elements/ files must agree on: the
  value sets, the string tags, the event sets, the record shape (`StateRecord`),
  the shared predicates, and the state variable itself. The per-variant state
  constructors are one per file in Machine/.

  EXTENDS only flows one way. A module sees Base, Base sees nothing of it, so
  anything two files share has to live here — including `VARIABLE state`,
  which cannot be declared in QueueShapes.tla for the Machine/ files to use.
*)
EXTENDS Naturals, Sequences

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
\* String constants. Every element kind the machine compares against lives here
\* exactly once — use this record, never a string literal. A typo in a field
\* name (e.g. Element.IncomingPayternFadingIn) fails loudly instead of
\* silently comparing false the way a misspelled literal would.
\*
\* State tags are also strings, but each one lives with its state variant:
\* Machine/<X>State.tla exports `Tag` next to the `make` constructor that stamps
\* it. Machine/States.tla instantiates every state variant once, and a branch
\* file `EXTENDS States` to reach them as `XState!Tag`, `XState!make(...)`.
\* The bare names are short on purpose: the instance supplies the namespace, so
\* two variants can both export `Tag`/`make` without colliding. (`EXTENDS` of the
\* state modules themselves would flatten them into one namespace, which is what
\* the old `<X>Tag` prefixes were working around.)
\* ---------------------------------------------------------------------------
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


\* helpers/theSameWasPressed.ts
isTheSameChordOrStrength(pressedParamButtonId, asset) ==
  \/ pressedParamButtonId.kind = EventKinds.chord /\
       pressedParamButtonId.value = asset.chord
  \/ pressedParamButtonId.kind = EventKinds.strength /\
       pressedParamButtonId.value = asset.strength

isTheSamePattern(pressedParamButtonId, asset) ==
  pressedParamButtonId.kind = EventKinds.pattern /\
    pressedParamButtonId.value = asset.pattern

\* The two negations below are ONE concept, and it already has a name in the codebase:
\* `arbitraryPressChangingTheSoundingAsset` in Pattern.spec.ts filters on exactly this
\* pair. Every branch that goes somewhere other than a no-op or a fade-to-silence needs
\* it, so it is stated once instead of twice in eleven branches.
thePressChangesTheSoundingAsset(pressedParamButtonId, asset) ==
  /\ ~isTheSameChordOrStrength(pressedParamButtonId, asset)
  /\ ~isTheSamePattern(pressedParamButtonId, asset)

\* TaggedPatternPointer.makePatchedFrom
makePatchedFrom(asset, pressedParamButtonId) ==
  CASE pressedParamButtonId.kind = EventKinds.pattern ->
  [asset EXCEPT !.pattern = pressedParamButtonId.value]
  [] pressedParamButtonId.kind = EventKinds.chord ->
  [asset EXCEPT !.chord = pressedParamButtonId.value]
  [] OTHER-> [asset EXCEPT !.strength = pressedParamButtonId.value]


\* Queue elements. `kind` is the element class, spelled exactly like the class in
\* Elements/, and `asset` is what it wraps. The constructors themselves are one
\* per file in Elements/.
StateRecord(tag, transitionQueue, chord, strength) ==
  [ tag |-> tag,
    transitionQueue |-> transitionQueue,
    chord |-> chord,
    strength |-> strength
  ]

\* `none` means "this state does not store a selection; it derives it from the
\* queue". Only SilenceState and PatternPatternSilenceTransitionState store it.
noStoredSelection == "noStoredSelection"

\* The one way to ask "is this state in that variant?". Each Machine/<X>State.tla
\* exports `Tag`, each branch file binds it once as `models(s)` through the
\* instance from States -- `isInState(PatternSilenceTransitionState!Tag, s)` --
\* and nothing else compares `state.tag` by hand.
isInState(tag, s) == s.tag = tag


\* `StateRecord` is the one place the record shape is written down. Each state
\* variant's constructor lives in Machine/<State>State.tla and is called `make`,
\* so every callsite reads `<State>!make(...)` and a caller never spells the tag
\* or a field the variant does not store. TLA+ modules cannot depend on each
\* other in a cycle — and the branches do (Pattern → PatternSilenceTransition →
\* Pattern) — which is why a constructor cannot share a file with the branches the
\* way the TS classes do.
VARIABLE state

\* A Machine/ file's Schema.Tuple, restated as a property instead of a type. The
\* tuple itself lives in that state's file; only the shape of the check is shared.
transitionQueueMatchesShape(s, expectedElementKinds) ==
  /\ Len(s.transitionQueue) = Len(expectedElementKinds)
  /\ \A i \in 1 .. Len(s.transitionQueue):
       s.transitionQueue[i].kind = expectedElementKinds[i]
====
