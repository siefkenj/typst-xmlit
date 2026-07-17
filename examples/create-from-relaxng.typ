// Derive XML element constructors from a RELAX NG grammar (compact syntax),
// then compose documents that are typechecked against it. `create-from-relaxng`
// returns `(elements, utils)`: `elements` maps each grammar element name to its
// tag function, and `utils` holds `validate-and-render` (a `#show:` template),
// `render-and-show-validation-errors` (renders + highlights errors in place
// instead of panicking), `validate` (non-panicking), and `roots`.

#import "../src/lib.typ": create-from-relaxng, elem

#set page(height: auto, margin: 2cm)

// A tiny grammar: a recipe with a required title, one-or-more ingredients,
// and zero-or-more steps.
#let grammar = "
start = element recipe {
  attribute servings { text },
  element title { text },
  element ingredient { text }+,
  element step { text }*
}
"

#let (utils, elements) = create-from-relaxng(grammar)
#let (recipe, title, ingredient, step) = elements

= Typechecked XML from a RELAX NG grammar

The grammar:
#block(fill: luma(245), inset: 8pt, radius: 4pt, raw(grammar.trim(), lang: "rnc", block: true))

Allowed document roots: #raw(repr(utils.roots)). \
Defined elements: #raw(repr(elements.keys())).

== A valid document

To validate and show a document, use
`#show: utils.validate-and-render`, which serializes the body and validates
it against the grammar (panicking on any error).

#{
  // Validate the document and then render it
  show: utils.validate-and-render.with(pretty-print: true)
  recipe(servings: "4", {
    title[Pancakes]
    ingredient[2 cups flour]
    ingredient[1 cup milk]
    ingredient[2 eggs]
    step[Whisk the ingredients together.]
    step[Cook on a hot griddle until golden.]
  })
}

== Catching an invalid document

`utils.validate` checks a document without panicking, returning `(valid, errors)`. Here the required
`<title>` is missing before the ingredients. Each error also carries a `snippet` showing the source
in question.

#let bad = recipe(serving: "2", {
  ingredient[Water]
})

#let result = (utils.validate)(bad)

#block(
  fill: rgb("#fdeaea"),
  inset: 8pt,
  radius: 4pt,
  width: 100%,
  [
    valid: #raw(repr(result.valid))
    #for e in result.errors [
      - #e.message
        #if e.at("snippet", default: none) != none [
          #set text(fill: red.darken(30%))
          #raw(e.snippet, block: true)
        ]
    ]
  ],
)

== Showing errors in place

`#show: utils.render-and-show-validation-errors` renders the same source but, instead of panicking,
highlights the offending element and shows the message right next to it---handy when authoring.

#[
  #show: utils.render-and-show-validation-errors
  #recipe(serving: "2", {
    ingredient[Water]
  })
]
