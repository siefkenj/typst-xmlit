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
#assert.eq(utils.keys(), ("validate-and-render", "validate", "roots"))

// Destructuring works as advertised.
#let (validate-and-render, validate) = utils
#let (foo, bar) = elements
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
#let bad = validate(foo(elem("qux")))
#assert(not bad.valid)
#assert(bad.errors.first().message.contains("<qux>"))
#assert(bad.errors.first().message.contains("bar"))
#assert(bad.errors.first().at("line", default: none) != none)

// Invalid: unknown attribute.
#let bad-attr = validate(foo(bar(baz: "zz", nope: "1")))
#assert(not bad-attr.valid)
#assert(bad-attr.errors.first().message.contains("nope"))

// Invalid: wrong root element.
#assert(not validate(bar(baz: "zz")).valid)

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
