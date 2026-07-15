// Visual test for create-from-relaxng (co-located; compile and eyeball):
//
//   typst compile --root . src/relaxng/relaxng.test.typ relaxng.test.pdf

#import "relaxng.typ": create-from-relaxng

#set page(paper: "us-letter", margin: 2cm)

#let grammar = "
start = element article {
  element title { text },
  element section {
    attribute label { text },
    mixed { element em { text }* }
  }*
}
"

#let (root, validate, roots, elements, article, title, section, em) = create-from-relaxng(grammar)

= create-from-relaxng — visual smoke test

Grammar:
#block(fill: luma(245), inset: 8pt, radius: 4pt, raw(grammar.trim(), lang: "rnc", block: true))

Allowed roots: #raw(repr(roots)). All elements: #raw(repr(elements)).

The validated document below is rendered by the `root` template (via
`#show: root`) — if it did not conform to the grammar, compilation would
have failed with a readable panic.

#show: root

#article[
  #title[A Very Valid Article]
  #section(label: "intro")[
    Welcome to the #em[first] section.
  ]
  #section(label: "body")[
    More #em[emphasized] prose here.
  ]
]
