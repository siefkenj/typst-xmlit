// Build an SVG document with xmlit tag functions -- computing shapes with
// Typst code -- serialize it with `xml-to-string`, and display the result
// with `image`.

#import "../src/lib.typ": make-tags, xml-to-string

// `make-tags` returns the tag functions positionally, so bindings can be
// renamed freely (`text-el` avoids shadowing Typst's `text`).
#let (svg, g, circle, rect, text-el) = make-tags("svg", "g", "circle", "rect", "text")

// A ring of overlapping translucent petals, positions and colors computed
// in Typst.
#let petals = range(12).map(i => {
  let angle = i * 30deg
  circle(
    cx: str(100 + calc.round(55 * calc.cos(angle), digits: 2)),
    cy: str(100 + calc.round(55 * calc.sin(angle), digits: 2)),
    r: "32",
    fill: color.hsl(angle, 80%, 55%).to-hex(),
    opacity: "0.55",
  )
})

#let doc = svg(
  xmlns: "http://www.w3.org/2000/svg",
  viewBox: "0 0 200 200",
  // Children: a background, the computed petal array (arrays flatten), a
  // center disc, and a label.
  rect(width: "200", height: "200", rx: "12", fill: "#f8f4ec"),
  g(petals),
  circle(cx: "100", cy: "100", r: "26", fill: "#333"),
  text-el(
    x: "100",
    y: "105",
    fill: "white",
    font-size: "13",
    font-family: "sans-serif",
    text-anchor: "middle",
    "xmlit",
  ),
)

= Building SVG with xmlit

The rendered document:

#align(center, image(bytes(xml-to-string(doc)), format: "svg", width: 6cm))

...and the generated source it was rendered from (with `pretty-print: true`):

#block(
  fill: luma(245),
  inset: 8pt,
  radius: 4pt,
  width: 100%,
  raw(xml-to-string(doc, pretty-print: true), lang: "xml", block: true),
)
