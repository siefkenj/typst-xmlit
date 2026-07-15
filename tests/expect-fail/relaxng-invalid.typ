// MUST FAIL: the `root` template from create-from-relaxng panics with a
// readable "XML failed RELAX NG validation" message when the composed
// document does not match the grammar (<qux> is not defined).

#import "/src/lib.typ": create-from-relaxng, elem

#let (root, foo) = create-from-relaxng(
  "start = element foo { element bar { attribute baz { text } }* }",
)

#show: root
#foo[#elem("qux")]
