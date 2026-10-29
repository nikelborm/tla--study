---- MODULE Elements ----
\* One instance per element variant. A module that needs one just `EXTENDS
\* Elements` and reaches it as `<Element>!Tag` / `<Element>!make(...)`.
\*
\* This file exists so the element variants can keep short internal names (`Tag`,
\* `make`) without every Machine/ file repeating the INSTANCE block. The instance
\* name is the namespace; `EXTENDS` only brings the instances into scope. It is
\* the same arrangement as Machine/States.tla, one level down.
\*
\* Element modules themselves must NOT EXTEND Elements -- Elements instantiates
\* them, so that would be a cycle. They EXTEND Base.
EXTENDS Base

PatternPlayback == INSTANCE PatternPlayback
PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern == INSTANCE PatternPlaybackScheduledWithShortFadeoutBeforeAnotherPattern
PatternPlaybackAtItsLastPlayWithScheduledLongFadeout == INSTANCE PatternPlaybackAtItsLastPlayWithScheduledLongFadeout
IncomingPatternFadingIn == INSTANCE IncomingPatternFadingIn
====
