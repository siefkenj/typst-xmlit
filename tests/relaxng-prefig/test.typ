// Test suite: create-from-relaxng against the real PreFigure grammar
// (https://github.com/davidaustinm/prefigure, prefig/resources/schema/
// pf_schema.rnc; the copy in tests/grammars comes from PreTeXtBook/pretext
// and is identical modulo trailing whitespace).
// Passes iff this file compiles without a failed assertion.

#import "/src/lib.typ": create-from-relaxng, elem

#let made = create-from-relaxng(read("/tests/grammars/pf_schema.rnc"))

// --- Factory shape -----------------------------------------------------------

#assert.eq(made.roots, ("diagram",))
#assert(made.elements.len() > 50)
#for name in ("diagram", "coordinates", "circle", "point", "line", "grid", "label", "caption") {
  assert(name in made.elements, message: "missing element: " + name)
}

#let (root, validate, diagram, coordinates, circle, point, line, grid, caption) = made

// --- Valid documents ----------------------------------------------------------

// Smallest possible diagram: only the required dimensions attribute.
#assert(validate(diagram(dimensions: "(300, 300)")).valid)

// A realistic diagram with nested graphical elements.
#let figure = diagram(
  dimensions: "(300, 300)",
  margins: "5",
  coordinates(
    bbox: "(-5, -5, 5, 5)",
    grid(),
    circle(center: "(0, 0)", radius: "2"),
    point(p: "(1, 1)"),
    line(endpoints: "((0,0), (2,2))"),
  ),
  caption("A circle, a point, and a line."),
)
#assert(validate(figure).valid)

// Content-block composition works the same.
#assert(validate(diagram(dimensions: "(300, 300)")[
  #coordinates(bbox: "(-1, -1, 1, 1)")[
    #circle(center: "(0, 0)", radius: "0.5")
  ]
]).valid)

// --- Invalid documents ----------------------------------------------------------

// Missing the required dimensions attribute.
#let bad = validate(diagram())
#assert(not bad.valid)

// Wrong root element.
#assert(not validate(circle(center: "(0,0)", radius: "1")).valid)

// Unknown element inside the diagram; error names it and lists expectations.
#let bad-child = validate(diagram(dimensions: "(300, 300)", elem("nonsense")))
#assert(not bad-child.valid)
#assert(bad-child.errors.first().message.contains("<nonsense>"))
#assert(bad-child.errors.first().message.contains("Expected element(s)"))

// Unknown attribute.
#assert(not validate(diagram(dimensions: "(300, 300)", zap: "1")).valid)

// --- root template ----------------------------------------------------------------

#assert.eq(type(root(diagram(dimensions: "(300, 300)"))), content)
