#import "../src/lib.typ": *

#let p = make-tag("p", handlers: (
  // strong -> <alert> instead of <b>
  "strong": (c, convert, ctx) => ((tag: "alert", attrs: (:), children: convert(c.body)),),
  // serialize equation bodies yourself (the default emits Typst math source,
  // e.g. $x^2$ -> "x^2", that evals back to the same expression; unsupported
  // constructs like matrices degrade to a repr fallback)
  // "math": (body, convert, ctx) => ("...",),
))


#repr(xml-to-string(p[A *very important* point about $x^2$.]))