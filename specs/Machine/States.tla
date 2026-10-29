---- MODULE States ----
\* One instance per state variant. A module that needs one just `EXTENDS States`
\* and reaches it as `<State>!Tag` / `<State>!make(...)`.
\*
\* This file exists so the state variants can keep short internal names (`Tag`,
\* `make`) without every branch file repeating the INSTANCE block. The instance
\* name is the namespace; `EXTENDS` only brings the instances into scope.
\*
\* State modules themselves must NOT EXTEND States -- States instantiates them,
\* so that would be a cycle. They EXTEND Base.
EXTENDS Base

DefectState == INSTANCE DefectState
PatternState == INSTANCE PatternState
SlowStrumState == INSTANCE SlowStrumState
PatternPatternTransitionState == INSTANCE PatternPatternTransitionState
PatternSilenceTransitionState == INSTANCE PatternSilenceTransitionState
PatternPatternPatternTransitionState == INSTANCE PatternPatternPatternTransitionState
PatternPatternSilenceTransitionState == INSTANCE PatternPatternSilenceTransitionState
PatternSilencePatternTransitionState == INSTANCE PatternSilencePatternTransitionState
SilenceState == INSTANCE SilenceState
====
