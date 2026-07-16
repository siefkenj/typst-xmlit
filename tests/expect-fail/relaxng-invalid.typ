// MUST FAIL: the `validate-and-render` template from create-from-relaxng
// panics with a readable "XML failed RELAX NG validation" message when the
// composed document does not match the grammar (<qux> is not defined).

#import "/src/lib.typ": create-from-relaxng, elem

#let (utils, elements) = create-from-relaxng(
  "start = element foo { element bar { attribute baz { text } }* }",
)
#let (foo,) = elements

#show: utils.validate-and-render
#foo[#elem("qux")]
