// Render an XML tree as source text -- but with every equation typeset as
// real math instead of its serialized source. Uses `extract-math: true`,
// which returns the XML string with `⟦math-N⟧` text sentinels plus a
// dictionary of the actual equation content, and then interleaves the two.

#import "../src/lib.typ": make-tags, xml-to-string

#let (p, section) = make-tags("p", "section")

/// Render `node` as XML source text with each `⟦math-N⟧` sentinel replaced
/// by the corresponding typeset equation.
#let render-with-math(node) = {
  let (xml-str, math) = xml-to-string(node, extract-math: true)
  let pos = 0
  for m in xml-str.matches(regex("⟦(math-[0-9]+)⟧")) {
    raw(xml-str.slice(pos, m.start), lang: "xml")
    math.at(m.captures.first())
    pos = m.end
  }
  raw(xml-str.slice(pos), lang: "xml")
}

// Renders as: `<p>An equation: ` + typeset x² + `</p>`
#render-with-math(p[An equation: $x^2$])

// Inline and display math, nested elements -- display math breaks the line,
// just as it would in a normal document.
#render-with-math(section[
  #p[The area of a circle is $pi r^2$ and the identity $e^(i pi) = -1$ holds.]
  #p[Solving requires
    $ integral_0^1 x^2 dif x = 1/3 $
    as an intermediate step.]
])
