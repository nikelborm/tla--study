# TLA+ study — for `AppPlaybackState`

Everything here is about one question:

> Is the `AppPlaybackState` machine allowed to do that, ever?

# 1. What TLA+ actually is (5 minutes)

TLA+ is a language for writing down a **state machine** and a **model checker** (TLC)
that enumerates every state the machine can reach.

That is the whole idea. There is no compiler, no runtime, no library. You write:

| Piece | Meaning | Your machine |
| --- | --- | --- |
| `VARIABLES` | what a state consists of | `state` (tag + queue + selection) |
| `Init` | which states the machine starts in | `SilenceState.default` |
| `Next` | which state pairs are legal steps | one disjunct per `advance()` branch |
| `Spec == Init /\ [][Next]_vars` | "start in `Init`, then keep taking `Next` steps" | the machine's whole life |
| `INVARIANT` | a predicate that must be true in **every reachable state** | "the queue never has 3 elements" |
| `PROPERTY` | a statement about the whole behaviour (needs fairness) | "it eventually stops being silent" |

Then TLC does a breadth-first search from `Init` through `Next`, and it **dedupes
states by their full value**. So it is exhaustive over everything reachable — no
sampling, no heuristics, no test cases you forgot to write. When an invariant
fails, it hands you the *shortest* behaviour that breaks it.

Three things you have to internalise, because they are where TLA+ bites:

1. **You check a model, not the code.** The model is a second implementation and it
   can be wrong in both directions (too strict → false alarms; too loose → misses
   bugs). Its trustworthiness lives entirely in the abstraction, which is a design
   decision you make and must be able to defend.
2. **State space is finite only because you made it finite.** 8 patterns × 8 chords
   × 3 strengths × queue positions is fine. Adding millisecond-precision time is
   not — you have to coarsen it (see rung 3 in §5).
3. **There are no floats.** `Reals` is a stub; TLC has integers. Your timing math has
   to be re-expressed in integer microseconds, or checked some other way (§4).

Terminology you'll see and can ignore for now: *safety vs liveness*, *refinement*,
*stuttering*, *fairness*, *symmetry*, *auxiliary variables*. You need none of them
to do what you asked for.

# 2. Run it

```sh
./run-tlc.sh specs/QueueShapes.tla -config specs/QueueShapes.cfg
```

`tla2tools.jar` is already in `.tools/`. It needs Java 11+; the system `java` is 8, so
`run-tlc.sh` points at `/usr/lib/jvm/java-17-openjdk/bin/java` explicitly.

Expected output for the default config:

```
Model checking completed. No error has been found.
2834018 states generated, 149833 distinct states found, 0 states left on queue.
The depth of the complete state graph search is 12.
```

"149833 distinct states, 0 left on queue" is the deliverable: **that is the exhaustive
set of states this abstraction can reach.** 11 is the longest behaviour it can have.
Ten seconds on one core. Sizes are the honest currency here: the 2-values-per-dimension
version of this same spec was 1 948 states, and going to 8×8×3 real assets instead would
be about 64× on top of this and buy nothing (see §3).

```
README.md                        this file
run-tlc.sh                       java -cp .tools/tla2tools.jar tlc2.TLC
.tools/tla2tools.jar             TLC + SANY + pcal.trans, v1.7.4
specs/QueueShapes.tla            the model
specs/QueueShapes.cfg            the run that is expected to pass
specs/QueueShapes.finding-*.cfg  four runs that are expected to FAIL, on purpose
specs/QueueShapes.reachable-triple.cfg
                                 a reachability query, also "fails on purpose"
```

# 3. What's in `specs/QueueShapes.tla`

It is your machine with **time erased**, one action per branch of `advance()`, in the
same order as the TypeScript:

Naming rule: **no abbreviations, and every name is the code's name.** State tags are the
class names verbatim, element kinds are the class names from `Elements/`, and actions are
`<StateClassName>_<methodOrConditionOrHandlerName>`.

| `.tla` | TypeScript |
| --- | --- |
| `Events`, `PressedParamButtonIds`, `CleanupEvents` | `PressedParamButtonId` ∪ the cleanup timer |
| `Advance(pressedParamButtonId)` | `oldState.advance(pressedParamButtonId)` |
| `SilenceState_onPattern/onChord/onStrength` | `Silence🏁.advance`, via `matchParamButtonId` |
| `PatternState_*` | `Pattern⏳.advance` |
| `PatternPatternTransitionState_*` | `PatternPatternTransition⏳.advance`, via `matchOnPressedParamButton` |
| `PatternSilencePatternTransitionState_*` | `PatternSilencePatternTransition.advance` |
| `PatternPatternPatternTransitionState_*` | `PatternPatternPatternTransition.advance` |
| `PatternSilenceTransitionState_*` | `PatternSilenceTransition.advance` |
| `PatternPatternSilenceTransitionState_*` | `PatternPatternSilenceTransition.advance` |
| `<StateClassName>_advance` | that class's `advance` |
| `GetNewCleanedUpState(cleanupEvent)` → `GetNewCleanedUpStateOn<StateClassName>` | `getNewCleanedUpState` — one leaf per `if` in it |
| `state' = DefectState!make` | `Effect.die(...)` |
| `theSameChordOrStrengthWasPressed`, `theSamePatternWasPressed` | `helpers/theSameWasPressed.ts` |
| `makePatchedFrom` | `TaggedPatternPointer.makePatchedFrom` |
| `TaggedPatternPointer_makeSimple` | `TaggedPatternPointer.makeSimple` |
| `transitionQueue` | `transitionQueue` |

The event type is one union of disjoint variants (`kind` is a singleton set in each, so an
event is never a mix). It has **two consumers**, not one, because the app has two:
`advance()` for presses and `getNewCleanedUpState()` for the timer. `Next` therefore
quantifies over the two variants separately. That is not laziness — a cleanup event has
no `value` field for the press path to read, and closing that hole with a guard makes
TLC stop naming the branch it took (traces degrade to `<Handle line 500>`). The reason
is written next to `Events` in the spec.

Deliberate abstractions, all written down at the top of the file:

- **Assets are 4×4×3 = 48, not 8×8×3 = 192.** The number of values a dimension needs
  is set by the number of *equality classes that must be distinguishable in one state*,
  not by the number of real buttons. A queue holds at most 3 elements, so one press can
  be: equal to element 1, equal to element 2, equal to element 3, or equal to none of
  them — **4 classes**, for the dimensions where a 4th value can exist. Patterns and
  chords have 8 buttons, so the 4th class is real → 4 values. Strengths have only 3
  buttons, so once the queue holds all three distinct strengths there is no "none of
  those" → 3 values. Nothing is lost by not writing 8: the machine never counts
  patterns, it only compares them, so the extra 4 are isomorphic copies.
  Using fewer than 4 is *not* safe, and §4d is the proof: at 2 patterns per dimension
  there are queue layouts the model cannot even express.
- **Time is replaced by `\E revocable \in BOOLEAN`.** Every place where the real code
  compares `now` against a scheduled fadeout time becomes a free choice. That makes
  the model a strict **over-approximation**:
  - an invariant that holds here holds in reality ✔
  - a counterexample here *might* be impossible in reality — you replay it against the
    timing rules to find out
- **Cleanup may arrive at any moment** instead of at `fadeoutEnds + buffer`. Same
  trade: coarsest possible over-approximation.
- **Death is a tag, not a flag.** `Effect.die` sets `state' = DefectState!make`,
  so every `advance` branch disables itself the moment the fiber dies (none of them match
  that tag) and one `StuttersAfterEffectDie` action carries the machine forever. That is
  why no branch in the spec is littered with guards. It also dropped the state count
  from 295 044 to 149 833: the old version stored a second copy of *every* state.
- **Slow strums are a dead end**, because that is what the code does today. They are
  behind `CONSTANT SlowStrums`, so you can switch them off in a config and ask what
  happens when the user only presses the buttons that are supposed to work. That is
  the TLA+ way of saying "run the model under a different assumption": one line in a
  `.cfg`, no code change.

### Adding your own invariant (this is the whole workflow)

1. Write an operator at the bottom of the `.tla` file that returns `TRUE`/`FALSE` and
   mentions only `state`. This one is already in the file:

   ```tla
   \* "At most one element of the transitionQueue is fading in at any moment."
   AtMostOneIncomingPatternFadingIn ==
     \A i, j \in 1..Len(state.transitionQueue) :
       IncomingPatternFadingIn!models(state.transitionQueue[i]) /\
       IncomingPatternFadingIn!models(state.transitionQueue[j]) => i = j
   ```

2. Add its name under `INVARIANTS` in a `.cfg` file (copy one of the `finding-*` ones).
3. Run TLC. `No error has been found` means **no reachable state in this abstraction
   violates it** — that is the strongest thing this tool can tell you.
4. If it fails, read the trace bottom-up. The action names are your TS branch names;
   the values are your assets. That is the bug report.

Nothing else is needed. You never "run" a spec in the sense of executing it; you only
ever ask TLC questions about it.

# 4. What it found

### 4a. `./run-tlc.sh specs/QueueShapes.tla -config specs/QueueShapes.finding-shape.cfg`

```
Error: Invariant TransitionQueueShapesMatchTags is violated.
State 4: PatternPatternTransitionState_whenFadingOutPlaybackIsUnsafeToRevive_onPressedAnyOtherPattern
State 5: PatternPatternPatternTransitionState_theSamePatternWasPressed_incomingFadeInIsStillRevocable  <-- here
```

`Machine/PatternPatternPatternTransition.ts:57` builds a
`PatternPatternSilenceTransitionState` out of `[oldest, middle]`, but that state's
`Schema.Tuple` is `[ShortFadingOut, LongFadingOut]` and `middle` is a `ShortFadingOut`.

**Honestly: TLA+ did not discover this, only reproduced it.** `tsc` already says so:

```
$ node_modules/.bin/tsc --noEmit -p tsconfig.json
Machine/PatternPatternPatternTransition.ts(57,11): error TS2741: Property
  'cancelLongFadeoutAndRestore' is missing in type
  'PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern' but required in type
  'PatternPlaybackAtItsLastPlayWithScheduledLongFadeout'.
```

Those are the only **4** type errors in the whole app (`tsconfig.json` includes
`**/*.ts`), all in `AppPlaybackStateService`, and all of them reachable behaviour:

| location | what |
| --- | --- |
| `PatternPatternPatternTransition.ts:57` | `ppp` → `pps` passes a short-fading element where a long-fading one is required |
| `CleanupFiberMakerLayer.ts:107` | `middle._tag === '...ShortFadeout...'` — always true, the `else` branch is unreachable *and* ill-typed |
| `PatternSilenceTransition.ts:95` | same dead `_tag` comparison on a one-element tuple |
| `PatternSilenceTransition.ts:101` | the unreachable `else` of that comparison, also ill-typed |

Lesson to take: **for shape/type invariants, use `tsc`.** TLA+ is not a type checker
and you should not spend a day of learning on something a 200 ms command tells you.
(Notice the type errors also make `Cleanup`'s `ppp` branch *dead code* — the model
follows the runtime behaviour, `ppp → pp`, not the dead branch.)

### 4b. `./run-tlc.sh specs/QueueShapes.tla -config specs/QueueShapes.finding-selection.cfg`

```
Error: Invariant StoredSelectionMatchesTheDestinationPlayback is violated.
State 3: PatternState_theSamePatternWasNotPressed
State 4: PatternPatternTransitionState_whenFadingOutPlaybackIsUnsafeToRevive_onPressedThePatternOfTheIncomingOne
State 5: PatternPatternSilenceTransitionState_onStrength
```

`PatternPatternSilenceTransitionState` stores `chord`/`strength` as fields, and
`Machine/PatternPatternSilenceTransition.ts` updates them on a strength press without
touching the queue.

**This one needs your judgement, not mine.** Two readings:

- *It's intended.* The stored fields are the "pending selection": what the *next*
  pattern press will be patched onto. The long-fading element is already scheduled
  and must not change. Under this reading my invariant is simply **wrong** and should
  be deleted.
- *It's a bug.* `inferSelection`/`inferPlaying` are supposed to report the truth about
  what is sounding; if the fields can drift from `queue[2]`, they cannot.

Which one is true decides whether this invariant stays. I'm not going to guess.

### 4c. `./run-tlc.sh specs/QueueShapes.tla -config specs/QueueShapes.finding-die-no-slowstrums.cfg`

This one is a genuine TLA+ result. A unit test only finds what you thought to assert;
nobody would guess "three taps" as a case to write down. TLC found it because it was
looking at *reachability*, not at any single call:

```
Error: Invariant NeverReachedEffectDie is violated.
State 2: SilenceState_onPattern
State 3: PatternState_theSamePatternWasPressed
State 4: PatternSilenceTransitionState_theSamePatternWasPressed_fadingLoopFadeoutIsNoLongerRevocable_EffectDie
```

**Three presses of the same pattern button kill the machine.** `PatternState.advance`
turns a re-press into `ps` (fade to silence, scheduled at `nextTick - shift`). Then
`PatternSilenceTransition.advance` dies on the *next* re-press of the same pattern if
`now > fadeout_STARTS - schedulingSafeBufferInSeconds`.

Read the numbers yourself: `transitionTimeInSeconds = 0.001` and
`schedulingSafeBufferInSeconds = 0.03`, so the die window is the ~30 ms before the tick
the fadeout targets, plus the ~1 ms it takes for the fadeout to end. In other words:
**triple-tap one pattern button, and if the third tap lands in the last ~30 ms before a
grid tick, the playback fiber dies.** That is a real input a person can produce with a
finger, and `Effect.die` there is not a graceful failure.

The model cannot tell you *how wide* the window is — time is erased in this spec. It
tells you the exact button sequence, which is the part you would otherwise have had to
guess. Rung 3.2 in §5 is how you'd get the width out of it.

### 4d. Why 2 values per dimension is not enough — `specs/QueueShapes.reachable-triple.cfg`

TLA+ has no "is this reachable?" operator that a beginner should touch. The idiom is
to check the **negation** as an invariant: if TLC reports a violation of `~P`, then a
state satisfying `P` exists, and the printed trace is the proof.

`NoFullQueueWithThreeDistinctPatterns` asks: *is there a full queue whose three
elements have three pairwise different patterns?*

- at **4 patterns**: **violated** → yes, reachable:
  `SilenceState_onPattern → PatternState_theSamePatternWasNotPressed →`
  `PatternPatternTransitionState_whenFadingOutPlaybackIsUnsafeToRevive_onPressedAnyOtherPattern` and now the queue is
  `[short(p1), short(p2), incoming(p3)]`
- at **2 patterns**: **no error** → the layout does not exist in the model, because
  three pairwise-distinct patterns cannot be *written down* with two values

That is the difference between "all branches were taken" and "all states were
represented". Branch coverage is not the thing to optimise for — you can pass it with
two values per dimension while silently pruning whole queue layouts, and every
invariant about those layouts then becomes vacuously true. Which is exactly why the
model uses 4/4/3.

# 5. The path (only what you need, nothing else)
Your machine is **deterministic, single-threaded, event-per-event**. That deletes more
than half of TLA+ from your path. Do not read about concurrency, refinement, fairness,
or liveness until you want them.

**Rung 1 — the language (~3 sittings).** Read in this order:

1. <https://learntla.com/core/operators.html> — values and operators. Skim; keep as reference.
2. <https://learntla.com/core/pluscal.html> — "Writing Specifications". **This is the one
   that matters.** Everything else is decoration.
3. <https://learntla.com/core/invariants.html> — what an invariant is and how TLC uses it.
4. <https://learntla.com/core/nondeterminism.html> — because your safe/unsafe branches
   are nondeterminism until time is modelled.

Skip: `setup` (you have `run-tlc.sh`), `concurrency`, `temporal-logic`,
`action-properties`, `refinement`, `modules`.

**Rung 2 — read your own spec.** Open `specs/QueueShapes.tla` next to
`Machine/PatternPatternTransition⏳.ts` and follow one press all the way through. Then
break something on purpose: change
`PatternPatternTransitionState_whenFadingOutPlaybackIsStillSafeToRevive_onPressedAnyOtherPattern` to keep
`state.transitionQueue[1]` out of
the queue and watch TLC produce the trace. That is the whole feedback loop, and it is
the only way this sticks.

**Rung 3 — the questions you actually care about.** In order of value/cost:

1. *Is the `die` reachable?* Already answered, see §4c. The follow-up that matters is
   *the window and the aftermath*: with `now` in the state you can check that the delay
   handed to `Effect.delay` is never negative or ~0 ms, and that a human double-tap
   can actually land inside the window. Start here — it is the cheapest timed spec and
   it answers a question you cannot answer by reading `timingsMath.ts`.
2. *Can cleanup fire before its fadeout ends?* Same timed spec, richer invariants.
   The design I'd use is **time as a finite set of instants, derived from the state
   itself** — not free-running microseconds:
   - every branch compares `now` against something of the form
     `boundary − shift − buffer` or `boundary − shift`, where `boundary` is a tick
   - so for the current state there are only a handful of *interesting* instants:
     each element's `fadeoutStart − buffer`, `fadeoutStart`, `fadeoutEnd`, and the
     ticks in between. Everything between two consecutive interesting instants
     behaves identically, so one representative per cell loses nothing
   - `Cleanup` always lands exactly on a `fadeoutEnd`, which is one of those instants

   The zones stay **derived, not stored**. Keep one `now` and write the zones as
   operators over it:

   ```tla
   PhaseOf(e, now) ==
     CASE now <= e.math.fadeoutStart - Buffer -> "cancellable"
       [] now <  e.math.fadeoutStart          -> "lockedBeforeFade"
       [] now <= e.math.fadeoutEnd            -> "fading"
       [] OTHER                               -> "done"
   ```

   That way "the oldest is still at full volume while the incoming is only scheduled"
   is representable *because it is real* (it is the initial state of every
   pattern→pattern transition), and "the outgoing is fading while the incoming has not
   started" is representable only where it is real (pattern boundaries, see below),
   without anyone hand-writing a table of legal phase pairs.

   One thing to notice while deriving the zones: mid-pattern the outgoing and incoming
   windows are **identical** (`[T−τ/2, T+τ/2]`, a true crossfade), but on a **pattern
   boundary** they are **butt-jointed** (`[T−τ, T]` then `[T, T+τ]`, no overlap). So
   "p1 fading out and p2 fading in" does not happen at all on a boundary — the zone set
   depends on `nextTick % ticksPerTrack == 0`. 1 in 8 transitions is the butt-joint
   case, so this is not a corner to skip.

   Then check:   - `Cleanup` never fires while `now < fadeoutEnds` of the element it disposes
   - `fadeoutEnds <= fadeinEnds` and `fadeoutStarts >= now` at scheduling time
   - `secondsSinceNowUpUntilAntialiasingFadeoutEnds >= 0` — a negative here becomes a
     negative `Effect.delay`, which fires immediately and cuts the sound
   - the audible-state question: no element goes from full volume to disposed without a
     fade, i.e. a disposal in the "unsafe buffer but before the fade started" zone is
     flagged
   State space still gets big; that is when you read
   <https://learntla.com/topics/optimization.html>.
3. *`matchOnPressedParamButton` exhaustiveness/mutual exclusivity.* This does **not**
   need TLA+. It is a truth table over `(revocable, samePattern, broughtBack)` — eight
   rows, an `Effect` test, done. (Your own `// TODO: feed arbitrary inputs into it and
   test for mutual exclusivity` is exactly this.) TLA+ would also answer it, at 100×
   the cost.

**The topic page to read when rung 3 starts:** <https://learntla.com/topics/state-machines.html>
(PlusCal-first, but it is the closest thing to your situation).

**Reference, not reading:** [Specifying Systems](https://lamport.azurewebsites.net/tla/book.html)
(Lamport's book, free PDF — chapter 2 is the state-machine chapter), and the
[TLA+ Examples repo](https://github.com/tlaplus/Examples) for idioms.

**If you'd rather write PlusCal than raw TLA+:** `learntla` teaches PlusCal first
because it reads like code (`while (TRUE) { either ... or ... }`) and compiles down to
what I wrote. Translation is `java -cp .tools/tla2tools.jar pcal.trans File.tla`. Say
the word and I'll convert this spec — it would look more like your `advance()` bodies.

# 6. Is TLA+ even the right tool here? (the honest version)

Your four goals, scored:

| goal | TLA+ | better tool |
| --- | --- | --- |
| encode the machine | good | — |
| exhaustive branch coverage | good, *over the abstraction* | `tsc` exhaustiveness + a 9-row truth table |
| "this invariant can never happen" | **good** — this is the actual use case | — |
| validate `timingsMath.ts` | *awkward* — no floats, and you re-implement the arithmetic to check the arithmetic | property test in TS with exact rationals/int µs |

The thing that makes TLA+ worth the time for you is **not** branch coverage. It is:

- **Reachability with a story.** "Is there any sequence of presses, at any times,
  after which the machine is in a state where X?" TLC answers with the shortest such
  sequence, in your own vocabulary (`..._onPressedAnyOtherPattern`,
  `PatternPatternTransitionState`). A test suite
  never gives you that; you have to guess the sequence first.
- **The time dimension.** Once `now` is in the state, questions like "the cleanup
  always lands after the fadeout" become finite checks instead of arguments in your
  head.

And the thing that argues *against* it, which you should weigh:

- The machine is **synchronous and deterministic**. That means you can also get
  exhaustiveness by writing a BFS in TypeScript over the *real* `advance()` and the
  *real* `timingsMath.ts`, deduping on `Schema.encodeSync(...)` output. Same guarantee,
  zero drift, runs in your existing vitest. It will not explain a bug as nicely, and
  it cannot check a design you haven't written yet — but it cannot lie about your code
  either.

My recommendation, if you want one: **use both, for different jobs.** TLA+ for the
questions you cannot state as a test yet (rung 3.1 and 3.2), and a TS BFS explorer as
the permanent regression guard that keeps the spec honest. They cross-check each other,
which is exactly what you want when the spec is a second implementation.

Not worth your time here: Alloy (integer arithmetic is 4-bit by default — useless for
ms timings), XState (draws, doesn't verify), Apalache (worth it only once TLC is too
slow, and it wants you to stay in a subset of TLA+ anyway).
