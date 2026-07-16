// Tests for `xml-to-string`: faithful serialization of `xml()` reader output.
// Passes iff this file compiles without a failed assertion.

#import "/src/lib.typ": xml-to-string, esc-text, esc-attr

// --- Escaping helpers ------------------------------------------------------

// Text context: `&`, `<`, `>` (not quotes); `&` handled first.
#assert.eq(esc-text("a & b < c > d \" '"), "a &amp; b &lt; c &gt; d \" '")
// Attribute context: `&`, `<`, `"` (not `>` or `'`).
#assert.eq(esc-attr("a & b < c > \" '"), "a &amp; b &lt; c > &quot; '")

// --- Whole-document serialization ------------------------------------------

#let out = xml-to-string(xml("fixture.xml"))

#let expected = (
  "<root xmlns=\"urn:default\" id=\"r1\" note=\"a &amp; b &lt;c> &quot;q&quot;\">"
    // namespace changes to urn:html -> re-declared once on <table>; prefixes stripped.
    + "<table xmlns=\"urn:html\" class=\"tbl\">"
      // descendants inherit urn:html -> no repeated xmlns.
      + "<tr><td>Apples</td><td /></tr>"
    + "</table>"
    // <b> is back in the inherited urn:default -> no xmlns re-declared.
    + "Mixed <b>bold</b> text."
    // comment and PI are skipped; CDATA becomes escaped text.
    + "&lt;raw&gt; &amp; cdata"
    // attribute order (z, a, m) preserved; empty element self-closes.
    + "<e z=\"1\" a=\"2\" m=\"3\" />"
  + "</root>"
)

#assert.eq(out, expected)

// --- Targeted behaviours ---------------------------------------------------

// Accepts an array (direct `xml()` return) or a single node.
#assert.eq(
  xml-to-string(("hi",)),
  "hi",
)
#assert.eq(
  xml-to-string((namespace: none, tag: "x", attrs: (:), children: ())),
  "<x />",
)

// Comment/PI sentinel (tag == "") is dropped entirely.
#assert.eq(
  xml-to-string((namespace: none, tag: "", attrs: (:), children: ())),
  "",
)

// Going from a namespace back to none emits xmlns="".
#assert.eq(
  xml-to-string((
    namespace: "urn:x",
    tag: "a",
    attrs: (:),
    children: ((namespace: none, tag: "b", attrs: (:), children: ()),),
  )),
  "<a xmlns=\"urn:x\"><b xmlns=\"\" /></a>",
)

// Plain string node is text-escaped.
#assert.eq(xml-to-string("1 < 2 & 3"), "1 &lt; 2 &amp; 3")

// --- Pretty printing -------------------------------------------------------

#import "/src/lib.typ": make-tags

#let (root, a, b, p, em) = make-tags("root", "a", "b", "p", "em")

// Default (pretty-print: false) is unchanged.
#assert.eq(xml-to-string(root(a(), b())), "<root><a /><b /></root>")

// Element-only children get one-per-line, two-space indentation; nesting
// increases depth; empty elements stay self-closing.
#assert.eq(
  xml-to-string(root(a(b()), b(id: "2")), pretty-print: true),
  "<root>\n  <a>\n    <b />\n  </a>\n  <b id=\"2\" />\n</root>",
)

// Mixed content (any text child) stays inline -- no whitespace injected.
#assert.eq(
  xml-to-string(p[Some #em[bold] text], pretty-print: true),
  "<p>Some <em>bold</em> text</p>",
)

// An element-only subtree nested inside mixed content is still prettified;
// the surrounding mixed element stays inline.
#assert.eq(
  xml-to-string(p("intro: ", root(a(), b())), pretty-print: true),
  "<p>intro: <root>\n  <a />\n  <b />\n</root></p>",
)

// A single leaf element: nothing to indent.
#assert.eq(xml-to-string(a(), pretty-print: true), "<a />")

// Pretty-printing composes with extract-math. Here <p>'s only child is the
// <m> element (element-only, so it indents); <m> itself holds a text
// sentinel (mixed, so it stays inline).
#let (xml: pretty-str, math-items) = xml-to-string(root(p[$x^2$]), pretty-print: true, extract-math: true)
#assert.eq(pretty-str, "<root>\n  <p>\n    <m>⟦math-0⟧</m>\n  </p>\n</root>")
#assert.eq(math-items.len(), 1)

#import "/src/lib.typ": to-xml, make-tag  // legacy API still importable
#assert(type(make-tag) == function)
