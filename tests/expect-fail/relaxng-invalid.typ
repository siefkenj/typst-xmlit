// MUST FAIL: the `validate-and-render` template from create-from-relaxng
// panics with a readable "XML failed RELAX NG validation" message when the
// composed document does not match the grammar (<qux> is not defined). The
// message includes a small line-numbered snippet of the pretty-printed
// source around the error, with the offending element underlined, e.g.:
//
//   XML failed RELAX NG validation:
//   - element <qux> is not allowed here. Expected element(s): bar.
//     1 | <foo>
//   > 2 |   <qux />
//           ^^^^^^^
//     3 | </foo>
//
// No "(line, column)" is shown: those would be positions in the invisible,
// internally-generated XML string, not anything the user actually wrote.
//
// See relaxng-invalid-large.typ for the same behavior on a document whose
// pretty-printed form is one very long, unbroken line.

#import "/src/lib.typ": create-from-relaxng, elem

#let (utils, elements) = create-from-relaxng(
  "start = element foo { element bar { attribute baz { text } }* }",
)
#let (foo,) = elements

#show: utils.validate-and-render
#foo[#elem("qux")]
