#import "../src/lib.typ": *

#let p = make-tag("p", handlers: (
  // strong -> <alert> instead of <b>
  "strong": (c, convert, ctx) => ((tag: "alert", attrs: (:), children: convert(c.body)),),
  // Control how the _content_ of math is serialized.
  "math": (body, convert, ctx) => ("MATH: \"" + repr(body) + "\"",),
  // Control what tag is used for math blocks.
  "equation": (c, convert, ctx) => {
    let f = c.fields()
    let tag = if f.block { "md" } else { "m" }
    // Use the math handler we defined already.
    let math-handler = ctx.handlers.at("math")
    ((tag: tag, attrs: (:), children: math-handler(f.body, convert, ctx)),)
  },
))

// Becomes: `<p>A <alert>very important</alert> point about <m>MATH: "attach(base: [x], t: [2])"</m>. It can sometimes be solved with <md>MATH: "root(radicand: [⋅])"</md></p>`
#xml-to-string(p[
  A *very important* point about $x^2$. It can sometimes be solved with
  $
    sqrt(dot)
  $
])
