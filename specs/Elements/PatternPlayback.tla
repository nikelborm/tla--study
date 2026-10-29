---- MODULE PatternPlayback ----
(*
  Elements/PatternPlayback.ts

  `Tag` is the class name, exactly as the code spells it, so no other file has to
  spell the string. A queue element is one record: `kind` names the class, `asset`
  is what it wraps.

  The element-to-element steps are written by the state actions that perform
  them. TLA+ modules cannot import each other in a cycle, and the element graph
  has one (a last-play element goes back to a plain playback on cleanup), so no
  element file can own all the edges that leave it.
*)
EXTENDS Base

Tag == "PatternPlayback"

make(asset) == [ kind |-> Tag, asset |-> asset ]

models(element) == isInElement(Tag, element)
====
