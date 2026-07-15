// Tests for `create-from-relaxng`: grammar-derived tag functions and
// validation. Passes iff this file compiles without a failed assertion.

#import "/src/lib.typ": create-from-relaxng, elem, xml-to-string

#let grammar = "start = element foo { element bar { attribute baz { text } }* }"

// --- Factory shape ------------------------------------------------------------

#let made = create-from-relaxng(grammar)
#assert.eq(made.roots, ("foo",))
#assert.eq(made.elements, ("bar", "foo"))

// Destructuring works as advertised.
#let (root, validate, foo, bar) = made
#assert.eq(type(root), function)
#assert.eq(type(foo), function)
#assert.eq(type(bar), function)

// The generated tags are ordinary xmlit tag functions.
#assert.eq(
  xml-to-string(foo(bar(baz: "zz"))),
  "<foo><bar baz=\"zz\" /></foo>",
)

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
#let dt = create-from-relaxng(dt-grammar)
// Valid date (2024 is a leap year) and matching pattern.
#assert((dt.validate)((dt.log)(when: "2024-02-29", code: "AB-123")).valid)
// Invalid date (2023 is not a leap year).
#assert(not (dt.validate)((dt.log)(when: "2023-02-29", code: "AB-123")).valid)
// Pattern facet violation.
#assert(not (dt.validate)((dt.log)(when: "2024-01-01", code: "nope")).valid)

// --- root template ---------------------------------------------------------------

// On valid input, root returns renderable content (the XML source as raw).
#let rendered = root(foo(bar(baz: "zz")))
#assert.eq(type(rendered), content)

// `#show: root` end-to-end (renders into the test document).
#[
  #show: root
  #foo[#bar(baz: "xx")]
]
