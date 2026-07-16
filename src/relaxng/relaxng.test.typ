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

#let (utils, elements) = create-from-relaxng(grammar)
#let (article, title, section, em) = elements

= create-from-relaxng — visual smoke test

Grammar:
#block(fill: luma(245), inset: 8pt, radius: 4pt, raw(grammar.trim(), lang: "rnc", block: true))

Allowed roots: #raw(repr(utils.roots)). All elements: #raw(repr(elements.keys())).

The validated document below is rendered by the `validate-and-render`
template (via `#show: utils.validate-and-render`) — if it did not
conform to the grammar, compilation would have failed with a readable panic.

#show: utils.validate-and-render

#article[
  #title[A Very Valid Article]
  #section(label: "intro")[
    Welcome to the #em[first] section.
  ]
  #section(label: "body")[
    More #em[emphasized] prose here.
  ]
]
