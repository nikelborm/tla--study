# Timed spec — design notes (Eva's design, not mine)

Status: not written yet. This file pins down the shape so the timed spec doesn't get
built twice. The untimed `QueueShapes.tla` stays as the baseline: it answers "which
queue shapes are reachable", this one answers "when, and in which order".

## What was wrong with the untimed model's cleanup

`QueueShapes.tla` models cleanup as a *class* of actions enabled at any moment, each one
transforming whatever transitionQueue the state happens to have, disposing
`transitionQueue[1]`. That is a faithful copy of `getNewCleanedUpState`, which disposes
`transitionQueue[0]` **by position**.

Two corrections to what I first wrote here, both from Eva:

1. **`CleanupFiberToolkit` is already in the state.** It is a field on
   `PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern` and on
   `PatternPlaybackAtItsLastPlayWithScheduledLongFadeout`, so the state *does* carry its
   own pending work. The problem is not location, it is that the field is a **capability**
   (an opaque fiber handle) instead of **data**: it cannot be compared, so
   `Pattern.spec.ts` needs `makeFakeCleanupFiberToolkit`; and it does not say *which*
   element it belongs to or *when* it fires. The refactor is "make it data", not "move it
   into the state".

2. **Scheduling IS an event** in the design, not a side effect. It goes through the same
   channel as user input and mutates the same scheduled map, so it belongs in the model's
   event set.

What is genuinely missing today: the *fired event* is anonymous. The element knows its
toolkit, but the timer fiber that fires knows nothing about which element it was created
for, so the handler falls back to position. The positional `transitionQueue[0].dispose()`
only works because the transitionQueue happens to be ordered by scheduling time — an
invariant nothing states and nothing enforces.

## Event type

```
Event =
  | press   { kind ∈ {pattern, chord, strength}, value, at }
  | cleanup { id, scheduledFor, executedAt, at }
```

- `at` — the second the machine actually **starts handling** it (the replacement for
  `GetAudioNow.run` inside `advance`; the timestamp is a property of the event, not a
  side effect the handler performs)
- `scheduledFor` — the deadline computed when the fadeout was scheduled
- `executedAt` — the second the timer service actually delivered it

`executedAt` and `at` are separate fields on purpose: they are equal iff the channel was
idle. `at − scheduledFor` is the **lateness**, and lateness is the thing that can cut
audio. `at − executedAt` is the queueing delay. Collapsing all three into one number
would throw away the only measurable quantity.

**Scheduling is an event too** (this is the part I got wrong). It does not come from the
user, but it goes through the same channel and it mutates the same scheduled map, so it
has to be in the model's event set, not smuggled into an action's side effects.

## State

```
state   — the AppPlaybackState (tag + transitionQueue + selection), unchanged in shape
now     — audio time in integer microseconds, relative to the current grid start
timers  — the timer service's map:  cleanupId ↦ { elementIndex, fireAt }
inbox   — the channel: a sequence of events not yet handled
```

`timers` is the timer service's **observable mirror** of the state, not a second copy of
the truth: the service reconciles it from `state` after every transition, and the
invariant is that the mirror never drifts (`timers = DerivedTimers(state)`). That is the
shape Eva described — a service observing the machine synchronously rather than a
fire-and-forget fiber. The deadline itself already exists in the state, inside `math`
(`patternPlaybackAntialiasingFadeout_ENDS_AT_SECONDS_SinceAudioContextInit`); what is
missing is a comparable identity plus the guarantee that the mirror is in sync.

## Invariants (in order of how much I want them)

1. **No stale timer.** Every entry in `timers` refers to an element that exists in
   `state`'s queue and still has a fade scheduled. Cancel removes the entry; a fired
   entry is consumed.
2. **Deadlines never move later.** For an existing `id`, `fireAt` is immutable. A
   transition may cancel an id and schedule a *new* id at a new time, but never rewrite
   an existing deadline. (`cancelShortFadeoutAndRestore` → `beginLongFadeoutToSilence`
   is exactly this: one id dies, another is born.)
3. **The earliest pending deadline belongs to `transitionQueue[1]`.** This is the
   invariant that makes the positional `transitionQueue[0].dispose()` correct, and it is
   what the redesign exists to guarantee instead of assume.
4. **Lateness is bounded.** `at − scheduledFor ≤ ε` for every cleanup. What ε is
   depends on the answer below about atomicity.
5. **The queue only ever shrinks by the element that fired.** `[1,2,3] → [2,3]` removes
   exactly the element whose timer fired, never another one.

Invariant 3 is provable **without modelling time at all**, if cleanups get monotone ids:
scheduling order = id order, and the queue order = scheduling order, so the minimal
pending id is always `transitionQueue[1]`'s. That is the cheap next step; see the bottom of this file.

## Open questions I cannot answer from the code

1. **Is the `[1,2,3] → [2,3]` transformation atomic, or does it have observable
   intermediate states?** You said cleanup "locks the state machine so that no new user
   inputs are handled while the transition is getting transformed". In a one-event-at-a-
   time machine, atomicity is free: one step is one step, and nothing can interleave. So
   the lock costs nothing to model **iff** the transformation really is a single step
   (`SubscriptionRef.updateEffect` makes it one today). If disposing audio is async and
   the state is briefly inconsistent, then the model needs an explicit `locked` flag and
   an input-rejection path, and invariant 4 becomes `ε` = however long disposal takes.
   Which is it?

2. **"reduce, not change, or increase the delays for new events"** — my reading, tell me
   if this is right:
   - *not change* → an already-scheduled deadline is never rewritten (invariant 2)
   - *reduce* → cancelling an entry can only make the earliest pending deadline earlier
   - *not increase* → observing a new state never pushes a new event's deadline later
     than what the transition itself computed
   If that is it, then the timer service is a pure function of the state:
   `timers' = reconcile(timers, state')`, and reconciliation is monotone-shrinking plus
   additions for newly scheduled fades.

3. **Who assigns the id?** The machine at scheduling time (so the id can live in the
   queue element, like `ScheduledPatternTransitionQueueElement`'s fade fields), or the
   timer service at scheduling time (so the machine never sees ids at all)? This decides
   whether `CleanupFiberToolkit` disappears *into* the state or stays a separate service.

## Cheapest next step (no time yet)

Give every scheduled cleanup a monotone id and a `pending` set in the untimed spec:

- `beginShortFadeout…` / `beginLongFadeoutToSilence` / `promoteTo…` allocate `nextId' = nextId + 1`
  and add `{id, elementIndex}` to `pending`
- `cancel…AndRestore` removes the entry
- cleanup is `\E id ∈ pending :` … and the action must assert that `id` is the minimal
  pending one **and** that it belongs to `transitionQueue[1]`

That reproduces invariants 1 and 3 with the time dimension erased, and it is a small diff
on the spec that already runs. If that invariant fails, the redesign is not optional.

## Naming policy (applies to every file here)

No abbreviations, and every name is the code's name. `QueueShapes.tla` already follows it:

| `.tla` | from the code |
| --- | --- |
| `"SilenceState"`, `"PatternPatternTransitionState"`, … | the class names, verbatim |
| `"PatternPlayback"`, `"PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern"`, `"PatternPlaybackAtItsLastPlayWithScheduledLongFadeout"`, `"IncomingPatternFadingIn"` | the `Elements/` class names, verbatim |
| `<StateClassName>_advance` | that class's `advance` method |
| `<StateClassName>_<conditionOrHandlerName>` | a branch of that method |
| `GetNewCleanedUpStateOn<StateClassName>` | one `if` inside `getNewCleanedUpState` |
| `state.transitionQueue` | the field |
| `pressedParamButtonId` | `PressedParamButtonId` |
| `cleanupEvent` | the cleanup variant |

The timed spec must follow the same rule, which means `timers` should probably be named
after whatever the timer service ends up being called in the code.
