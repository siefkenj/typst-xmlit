// MUST FAIL: same as relaxng-invalid.typ, but on a document whose body is a
// single long run of mixed-content prose -- pretty-printing never breaks a
// line between text and its sibling elements (only all-element children get
// one-per-line treatment), so this stays one very long line even in the
// "pretty" rendering. The panic message must still show only a short, local
// snippet around the offending <bogus> element, NOT the whole paragraph --
// this is the core behavior `format-errors` exists to guarantee regardless
// of document size/shape (see its docstring in src/relaxng/relaxng.typ).

#import "/src/lib.typ": create-from-relaxng, elem

#let (utils, elements) = create-from-relaxng(
  "start = element article { element p { text } }",
)
#let (article, p) = elements

#let long-prose = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. "

#show: utils.validate-and-render
#article(p(long-prose, elem("bogus", "oops"), long-prose))
