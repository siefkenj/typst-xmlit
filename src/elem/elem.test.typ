// and eyeball the rendered output; not run by tytanic).
//
//   typst compile --root . src/elem/elem.test.typ elem.test.pdf

#import "elem.typ": elem, make-tag, make-tags
#import "../xml-to-string/xml-to-string.typ": xml-to-string

#set page(paper: "us-letter", margin: 2cm)

#let show-xml(title, value) = [
  == #title
  #block(
    fill: luma(245),
    inset: 8pt,
    radius: 4pt,
    width: 100%,
    raw(xml-to-string(value), lang: "xml", block: true),
  )
]

#let (article, sec, p, m-tag) = make-tags("article", "section", "p", "m")

= xmlit authoring

Each block below shows the serialized XML for one authoring style. All three "call style" blocks
must render the *same* XML.

#show-xml("Positional style", article(sec(title: "Intro"), p("Hello & <world>")))

#show-xml("Code-block style", article({
  sec(title: "Intro")
  p("Hello & <world>")
}))

#show-xml("Markup style", article[#sec(title: "Intro")#p[Hello & <;world>]])

#show-xml("Prose with markup mappings", p[
  Some *bold* text, some _emphasis_, inline `code`, and "smart quotes".
])

#show-xml(
  "Math boundaries (payload evals back to the same expression)",
  p[Inline $x^2$ and display
    $ integral_0^1 x dif x $
    math.],
)

#let todo-math-p = make-tag("p", handlers: ("math": (body, convert, ctx) => ("TODO: math",)))
#show-xml("Custom math handler", todo-math-p[Euler: $e^(i pi) = -1$])

#let alert-p = make-tag(
  "p",
  handlers: ("strong": (c, convert, ctx) => ((tag: "alert", attrs: (:), children: convert(c.body)),)),
)
#show-xml([Custom markup mapping (strong -> alert)], alert-p[A *very important* point.])

#show-xml("Generic elem constructor", elem("foo", elem("bar", baz: "zz")))
