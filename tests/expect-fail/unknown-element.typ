// MUST FAIL: content with no registered handler (here a heading) produces a
// "no handler for content element `heading`" error suggesting a handlers:
// entry.

#import "/src/lib.typ": make-tag

#let foo = make-tag("foo")

#foo[= A heading]
