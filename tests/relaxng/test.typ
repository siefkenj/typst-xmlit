// Tests for `create-from-relaxng`: grammar-derived tag functions and
// validation. Passes iff this file compiles without a failed assertion.

#import "/src/lib.typ": create-from-relaxng, elem, xml-to-string

#let grammar = "start = element foo { element bar { attribute baz { text } }* }"

// --- Factory shape ------------------------------------------------------------

// Returns (elements: <name -> tag function>, utils: (..grammar helpers..));
// destructure it directly.
#assert.eq(create-from-relaxng(grammar).keys(), ("elements", "utils"))
#let (utils, elements) = create-from-relaxng(grammar)
#assert.eq(utils.roots, ("foo",))
#assert.eq(elements.keys(), ("bar", "foo"))
#assert.eq(utils.keys(), ("render", "validate-and-render", "render-and-show-validation-errors", "validate", "roots"))

// Destructuring works as advertised.
#let (render, validate-and-render, validate) = utils
#let (foo, bar) = elements
#assert.eq(type(render), function)
#assert.eq(type(validate-and-render), function)
#assert.eq(type(validate), function)
#assert.eq(type(foo), function)
#assert.eq(type(bar), function)

// The generated tags are ordinary xmlit tag functions.
#assert.eq(
  xml-to-string(foo(bar(baz: "zz"))),
  "<foo><bar baz=\"zz\" /></foo>",
)

// A grammar element named like a helper no longer collides with it: the tag
// function lives in `elements`, the helper in `utils`.
#let (utils: clash-utils, elements: clash-elements) = create-from-relaxng(
  "start = element validate { text }",
)
#assert.eq(type(clash-elements.validate), function)
#assert.eq(xml-to-string((clash-elements.validate)("x")), "<validate>x</validate>")
#assert((clash-utils.validate)((clash-elements.validate)("x")).valid)

// --- Validation ----------------------------------------------------------------

// Valid document, composed in all three call styles.
#assert(validate(foo(bar(baz: "zz"))).valid)
#assert(validate(foo({ bar(baz: "zz"); bar(baz: "yy") })).valid)
#assert(validate(foo[#bar(baz: "xx")]).valid)
// Raw XML strings validate too.
#assert(validate("<foo><bar baz=\"zz\" /></foo>").valid)

// Invalid: unknown element. Message names the element and the expectation.
// Errors from content input carry a located, windowed source snippet (the
// same one used in validate-and-render's panic message), but NOT line/column
// -- those would be positions in the invisible, internally-generated compact
// string, which the user never wrote and can't usefully act on.
#let bad = validate(foo(elem("qux")))
#assert(not bad.valid)
#assert(bad.errors.first().message.contains("<qux>"))
#assert(bad.errors.first().message.contains("bar"))
#assert(bad.errors.first().at("line", default: none) == none)
#assert(bad.errors.first().at("column", default: none) == none)
#assert(bad.errors.first().at("snippet", default: none) != none)
#assert(bad.errors.first().snippet.contains("<qux"))

// Invalid: unknown attribute.
#let bad-attr = validate(foo(bar(baz: "zz", nope: "1")))
#assert(not bad-attr.valid)
#assert(bad-attr.errors.first().message.contains("nope"))
#assert(bad-attr.errors.first().snippet.contains("nope"))

// Invalid: wrong root element.
#assert(not validate(bar(baz: "zz")).valid)

// Invalid, from a raw XML string: also gets a snippet -- windowed directly
// around the byte offset in the given string itself (no element-path
// mapping needed there, unlike authored content, since the raw string IS
// both what was validated and what to excerpt). Unlike the content case,
// line/column ARE kept here: they're positions in the exact string the user
// wrote, so they remain directly useful.
#let bad-str = validate("<foo><qux /></foo>")
#assert(not bad-str.valid)
#assert(bad-str.errors.first().message.contains("<qux>"))
#assert(bad-str.errors.first().at("line", default: none) != none)
#assert(bad-str.errors.first().at("snippet", default: none) != none)
#assert(bad-str.errors.first().snippet.contains("<qux"))

// --- xsd datatypes (exercise the chrono-shim and regex-shim code paths) ---------

// (the xsd datatype prefix is predeclared in compact syntax)
#let dt-grammar = "
start = element log {
  attribute when { xsd:date },
  attribute code { xsd:string { pattern = \"[A-Z]{2}-[0-9]+\" } }
}
"
#let (utils: dt-utils, elements: dt-elements) = create-from-relaxng(dt-grammar)
#let dt-validate = dt-utils.validate
#let log = dt-elements.log
// Valid date (2024 is a leap year) and matching pattern.
#assert(dt-validate(log(when: "2024-02-29", code: "AB-123")).valid)
// Invalid date (2023 is not a leap year).
#assert(not dt-validate(log(when: "2023-02-29", code: "AB-123")).valid)
// Pattern facet violation.
#assert(not dt-validate(log(when: "2024-01-01", code: "nope")).valid)

// --- render template (no validation) ------------------------------------------------

// render never calls the validator: an otherwise-invalid document (unknown
// element, wrong root, ...) still renders without panicking.
#let invalid-rendered = render(bar(baz: "zz"))
#assert.eq(type(invalid-rendered), content)
#assert.eq(invalid-rendered.text, "<bar baz=\"zz\" />")

#let unknown-rendered = render(foo(elem("qux")))
#assert.eq(unknown-rendered.text, "<foo><qux /></foo>")

// pretty-print works the same way as on validate-and-render.
#assert.eq(
  render(foo(bar(baz: "zz")), pretty-print: true).text,
  "<foo>\n  <bar baz=\"zz\" />\n</foo>",
)

// `#show: utils.render` end-to-end.
#[
  #show: utils.render
  #foo[#bar(baz: "xx")]
]

// --- validate-and-render template -------------------------------------------------

// On valid input, validate-and-render returns renderable content (the XML
// source as raw).
#let rendered = validate-and-render(foo(bar(baz: "zz")))
#assert.eq(type(rendered), content)
#assert.eq(rendered.text, "<foo><bar baz=\"zz\" /></foo>")

// pretty-print option: the rendered source is indented (validation still uses
// the compact form under the hood).
#let rendered-pretty = validate-and-render(foo(bar(baz: "zz")), pretty-print: true)
#assert.eq(rendered-pretty.text, "<foo>\n  <bar baz=\"zz\" />\n</foo>")

// `#show: utils.validate-and-render` end-to-end (renders into the test
// document); `.with(pretty-print: true)` also works as a show rule.
#[
  #show: utils.validate-and-render
  #foo[#bar(baz: "xx")]
]
#[
  #show: utils.validate-and-render.with(pretty-print: true)
  #foo[#bar(baz: "xx")]
]

// --- render-and-show-validation-errors ------------------------------------------

#import "/src/lib.typ": xml-to-string-with-ranges
#import "/src/relaxng/relaxng.typ": locate-path, line-of

// The plugin's byte-offset error position maps to the deepest offending
// element, and that element maps to its line in the pretty-printed output.
#let g2 = "start = element recipe { element title { text }, element ingredient { text }+ }"
#let (utils: u2, elements: e2) = create-from-relaxng(g2)
#let (recipe, title, ingredient) = e2
#let bad-doc = recipe({ ingredient[Water] })   // <title> required first

#let compact = xml-to-string-with-ranges(bad-doc)
#let res = (u2.validate)(bad-doc)
#assert(not res.valid)
#let err = res.errors.first()
#let path = locate-path(compact.ranges, err.start)
// The offending element is the misplaced <ingredient>, not the <recipe> root.
#let hit = compact.ranges.find(r => r.path == path)
#assert.eq(compact.xml.slice(hit.start, hit.end), "<ingredient>Water</ingredient>")
// In the pretty rendering, <ingredient> is on line 2.
#let disp = xml-to-string-with-ranges(bad-doc, pretty-print: true)
#let drange = disp.ranges.find(r => r.path == path)
#assert.eq(line-of(disp.xml, drange.start), 2)

// On valid input it renders the source like `render`; no panic on invalid.
#let ok = (u2.render-and-show-validation-errors)(recipe({ title[T]; ingredient[Water] }))
#assert.eq(type(ok), content)

// End-to-end as a show rule over an invalid document: renders (does not panic).
#[
  #show: u2.render-and-show-validation-errors
  #recipe({ ingredient[Water] })
]

// --- format-errors (validate-and-render's panic-message builder) ---------------

// `panic()` can't be caught in plain Typst, so `format-errors` is tested
// directly as a pure function -- exercising exactly the string it feeds to
// `validate-and-render`'s panic without needing to trigger one.
#import "/src/relaxng/relaxng.typ": format-errors

// Small document: full context shown, no truncation markers.
#let small-compact = xml-to-string-with-ranges(bad-doc)
#let small-pretty = xml-to-string-with-ranges(bad-doc, pretty-print: true)
#let small-msg = format-errors(res, small-compact.ranges, small-pretty)
#assert(not small-msg.contains("…"), message: "small doc should show full context: " + small-msg)
#assert(small-msg.contains("<ingredient>Water</ingredient>"))
// No "(line, column)" suffix: format-errors is only ever used on authored
// content, where those positions are meaningless (see format-errors).
#assert(not small-msg.contains("(line"), message: "unexpected line/column suffix: " + small-msg)

// A long single-line MIXED-content element (a <p> full of prose, which
// pretty-printing never breaks across lines -- only all-element children get
// one-per-line treatment) with an invalid nested element buried in the
// middle. This is the critical regression case: line-count windowing alone
// would show the entire multi-hundred-character line; the snippet must stay
// bounded via character-level windowing within that line too.
#let long-grammar = "start = element article { element p { text } }"
#let (utils: long-utils, elements: long-elements) = create-from-relaxng(long-grammar)
#let (article, p) = long-elements
#let long-prose = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. "
#let long-doc = article(p(long-prose, elem("bogus", "oops"), long-prose))
#let long-compact = xml-to-string-with-ranges(long-doc)
#let long-pretty = xml-to-string-with-ranges(long-doc, pretty-print: true)
#let long-result = (long-utils.validate)(long-doc)
#let long-msg = format-errors(long-result, long-compact.ranges, long-pretty)
#assert(long-msg.len() < 800, message: "message was " + str(long-msg.len()) + " chars: " + long-msg)
#assert(long-msg.contains("…"))
#assert(long-msg.contains("<bogus>oops</bogus>"))
#assert(not long-msg.contains(long-prose), message: "full prose leaked into snippet: " + long-msg)

// The fully degenerate case: the ENTIRE document -- root tags included --
// pretty-prints to a single line with zero newlines (root itself is mixed
// content). Still must produce a bounded, local snippet, not the whole line.
#let flat-grammar = "start = element doc { mixed { element ok { text }* } }"
#let (utils: flat-utils, elements: flat-elements) = create-from-relaxng(flat-grammar)
#let (doc, ok) = flat-elements
#let flat-doc = doc(long-prose, elem("bogus", "oops"), long-prose)
#let flat-compact = xml-to-string-with-ranges(flat-doc)
#let flat-pretty = xml-to-string-with-ranges(flat-doc, pretty-print: true)
#assert(not flat-pretty.xml.contains("\n"), message: "expected zero newlines: " + flat-pretty.xml)
#let flat-result = (flat-utils.validate)(flat-doc)
#let flat-msg = format-errors(flat-result, flat-compact.ranges, flat-pretty)
#assert(flat-msg.len() < 800, message: "message was " + str(flat-msg.len()) + " chars: " + flat-msg)
#assert(flat-msg.contains("…"))
#assert(flat-msg.contains("<bogus>oops</bogus>"))
#assert(not flat-msg.contains(long-prose))

// Two independent, scattered errors -> two labeled entries, in source order.
#let multi-grammar = "start = element root { element a { attribute x { text } }, element b { text } }"
#let (utils: multi-utils, elements: multi-elements) = create-from-relaxng(multi-grammar)
#let (root, a, b) = multi-elements
#let multi-doc = root(a(x: "1", nope: "2", "t"), elem("bogus2"))
#let multi-compact = xml-to-string-with-ranges(multi-doc)
#let multi-pretty = xml-to-string-with-ranges(multi-doc, pretty-print: true)
#let multi-result = (multi-utils.validate)(multi-doc)
#assert(multi-result.errors.len() >= 2, message: "expected >=2 errors, got " + str(multi-result.errors.len()))
#let multi-msg = format-errors(multi-result, multi-compact.ranges, multi-pretty)
#assert(multi-msg.contains("nope"))
#assert(multi-msg.contains("<bogus2>"))
#assert(multi-msg.position("nope") < multi-msg.position("<bogus2>"), message: "errors not in source order: " + multi-msg)
