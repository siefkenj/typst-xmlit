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

#import "/src/lib.typ": to-xml, make-tag  // legacy API still importable
#assert(type(make-tag) == function)
