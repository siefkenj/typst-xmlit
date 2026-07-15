// Tests for the authoring API: make-tag / make-tags / elem and the content
// walker. Passes iff this file compiles without a failed assertion.

#import "/src/lib.typ": (
  make-tag, make-tags, elem, convert, content-to-children, xml-to-string,
)

#let (foo, bar) = make-tags("foo", "bar")

// --- Basics ------------------------------------------------------------------

// Tag functions return metadata content carrying the node.
#assert.eq(bar(baz: "zz").value, (tag: "bar", attrs: (baz: "zz"), children: ()))

// Positional style serializes as expected; empty elements self-close.
#assert.eq(
  xml-to-string(foo(bar(baz: "zz"), "text")),
  "<foo><bar baz=\"zz\" />text</foo>",
)

// Generic constructor mirrors html.elem.
#assert.eq(
  xml-to-string(elem("foo", elem("bar", baz: "zz"))),
  "<foo><bar baz=\"zz\" /></foo>",
)

// Numbers/booleans stringify; none is dropped; arrays flatten.
#assert.eq(
  xml-to-string(foo(1, none, (bar(), 2.5), true)),
  "<foo>1<bar />2.5true</foo>",
)

// Attribute and text escaping.
#assert.eq(
  xml-to-string(foo(attr: "a<b\"c&d", "1 < 2 & 3")),
  "<foo attr=\"a&lt;b&quot;c&amp;d\">1 &lt; 2 &amp; 3</foo>",
)

// --- The three call styles produce identical trees ---------------------------

#let via-positional = foo(bar(baz: "zz"), "text")
#let via-code-block = foo({
  bar(baz: "zz")
  "text"
})
#let via-markup = foo[#bar(baz: "zz")text]

#assert.eq(via-positional.value, via-code-block.value)
#assert.eq(via-positional.value, via-markup.value)
#assert.eq(xml-to-string(via-markup), "<foo><bar baz=\"zz\" />text</foo>")

// --- Markup bodies ------------------------------------------------------------

// Edge whitespace of a content body is trimmed; interior spaces survive
// (Typst merges plain prose into a single text node).
#assert.eq(foo[ hello world ].value.children, ("hello world",))
// ...but explicitly passed strings are kept verbatim.
#assert.eq(foo(" hello ").value.children, (" hello ",))

// Smart quotes turn back into plain quote characters.
#assert.eq(foo["q" 'x'].value.children, ("\"", "q", "\"", " ", "'", "x", "'"))

// Default markup mappings: strong -> <b>, emph -> <em>.
#assert.eq(
  xml-to-string(foo[*bold* and _emph_]),
  "<foo><b>bold</b> and <em>emph</em></foo>",
)

// Inline raw -> <c>, block raw -> <pre>; raw text is not markup-processed.
#assert.eq(
  xml-to-string(foo[`code<x>`]),
  "<foo><c>code&lt;x&gt;</c></foo>",
)

// A set rule inside a body wraps the rest in `styled`; the walker unwraps it.
#assert.eq(
  foo[#set text(fill: red)
    word].value.children,
  ("word",),
)

// Nesting: a tag call in the body of another tag's markup body.
#assert.eq(
  xml-to-string(foo[a #bar[b] c]),
  "<foo>a <bar>b</bar> c</foo>",
)

// --- Math ---------------------------------------------------------------------

// $...$ -> <m>, $ ... $ -> <md>.
#let with-math = foo[$x^2$ and $ y $].value
#assert.eq(with-math.children.first().tag, "m")
#assert.eq(with-math.children.last().tag, "md")

// The default math payload is a best-effort Typst-flavored linear string.
#let m-node = with-math.children.first()
#assert.eq(m-node.children, ("x^2",))
#assert.eq(with-math.children.last().children, ("y",))

// More of the default math serializer, via xml-to-string.
#assert.eq(xml-to-string(foo[$x^10$]), "<foo><m>x^10</m></foo>")
#assert.eq(xml-to-string(foo[$x^(a+1)$]), "<foo><m>x^(a+1)</m></foo>")
#assert.eq(xml-to-string(foo[$1/2$]), "<foo><m>1/2</m></foo>")
#assert.eq(xml-to-string(foo[$(x + 1)/2$]), "<foo><m>(x + 1)/2</m></foo>")
#assert.eq(xml-to-string(foo[$sqrt(x + 1)$]), "<foo><m>sqrt(x + 1)</m></foo>")
#assert.eq(xml-to-string(foo[$x'_1$]), "<foo><m>x'_1</m></foo>")
#assert.eq(xml-to-string(foo[$a_(i j)$]), "<foo><m>a_(i j)</m></foo>")

// The round-trip property for supported constructs: eval-ing the serialized
// output reproduces the original expression exactly. This test list is the
// enforcement of that property -- extend it alongside the serializer.
#import "/src/lib.typ": math-to-string
#let assert-round-trips(eq) = {
  let s = math-to-string(eq.body)
  assert.eq(
    repr(eval("$" + s + "$").body),
    repr(eq.body),
    message: "did not round-trip: " + s,
  )
}
#assert-round-trips($x^2$)
#assert-round-trips($x^10 + 1.5$)
#assert-round-trips($(x + 1)/2$)
#assert-round-trips($sqrt(x + 1)$)
#assert-round-trips($root(3, x)$)
#assert-round-trips($pi r^2$)
#assert-round-trips($x'' _1$)
#assert-round-trips($e^(i pi) = -1$)
#assert-round-trips($x dif x$)
#assert-round-trips($integral_0^1 x^2 dif x$)
#assert-round-trips($lim_(x -> 0) (sin x)/x$)
#assert-round-trips($"hello world" + x$)
#assert-round-trips($f(x, y)$)
#assert-round-trips($abs(x)$)

// Unsupported constructs (matrices, cases, ...) do NOT panic; they degrade
// to a repr fallback, which is visible but not valid math source.
#let degraded = xml-to-string(foo[$mat(1, 2; 3, 4)$])
#assert(degraded.starts-with("<foo><m>"))
#assert(degraded.contains("mat("))

// A custom "math" handler replaces the placeholder.
#let mfoo = make-tag("foo", handlers: ("math": (body, convert, ctx) => ("MATH",)))
#assert.eq(
  xml-to-string(mfoo[$x^2$]),
  "<foo><m>MATH</m></foo>",
)

// --- Custom handlers ------------------------------------------------------------

// Override a built-in mapping: strong -> <alert>.
#let afoo = make-tag(
  "foo",
  handlers: ("strong": (c, convert, ctx) => ((tag: "alert", attrs: (:), children: convert(c.body)),)),
)
#assert.eq(
  xml-to-string(afoo[*bold*]),
  "<foo><alert>bold</alert></foo>",
)

// make-tags forwards handlers to every created tag.
#let (hfoo, hbar) = make-tags(
  "foo", "bar",
  handlers: ("math": (body, convert, ctx) => ("M",)),
)
#assert.eq(xml-to-string(hfoo(hbar[$x$])), "<foo><bar><m>M</m></bar></foo>")

// --- Walker exports -------------------------------------------------------------

#assert.eq(convert("text"), ("text",))
#assert.eq(content-to-children[a #bar() b], ("a", " ", (tag: "bar", attrs: (:), children: ()), " ", "b"))

// xml-to-string also accepts bare markup content (no wrapping element).
#assert.eq(xml-to-string[plain #bar() text], "plain <bar /> text")
