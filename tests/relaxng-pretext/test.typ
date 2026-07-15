// Test suite: create-from-relaxng against the real PreTeXt grammar
// (https://github.com/PreTeXtBook/pretext, schema/pretext.rnc + the
// PreFigure adapter files it references).
// Passes iff this file compiles without a failed assertion.

#import "/src/lib.typ": create-from-relaxng, elem

#let vfs = (
  // First entry = grammar entry point.
  "pretext.rnc": read("/tests/grammars/pretext.rnc"),
  "pf-adapter.rnc": read("/tests/grammars/pf-adapter.rnc"),
  "pf-preamble-adapter.rnc": read("/tests/grammars/pf-preamble-adapter.rnc"),
  "pf_schema.rnc": read("/tests/grammars/pf_schema.rnc"),
)

// PreTeXt has no <b>; map *strong* markup to PreTeXt's <alert> instead.
#let made = create-from-relaxng(
  vfs,
  handlers: (
    "strong": (c, ctx) => ((tag: "alert", attrs: (:), children: (ctx.convert)(c.body)),),
  ),
)

// --- Factory shape -----------------------------------------------------------

// PreTeXt's start rule allows whole documents and many fragment roots
// (modular source files), and defines hundreds of elements.
#assert("pretext" in made.roots)
#assert("chapter" in made.roots)
#assert(made.elements.len() > 350)
#for name in ("article", "book", "theorem", "proof", "p", "m", "md", "em", "alert", "c") {
  assert(name in made.elements, message: "missing element: " + name)
}

#let (root, validate, pretext, book, article, chapter, title, p) = made

// --- Valid documents ----------------------------------------------------------

// Minimal article.
#assert(validate(pretext(article(title("T"), p("Hello")))).valid)

// Minimal book (needs a chapter).
#assert(validate(pretext(book(title("B"), chapter(title("One"), p("Text"))))).valid)

// Fragment root: a chapter on its own is a valid document (modular source).
#assert(validate(chapter(title("Solo"), p("ok"))).valid)

// Markup body: _emph_ -> <em> (a real PreTeXt element), *strong* -> <alert>
// via the factory handler, `code` -> <c>, math -> <m>. All PreTeXt-valid.
#assert(validate(pretext(article(
  title("Markup"),
  p[Some _emphasis_, an *important point*, code `f(x)`, and math $x^2$.],
))).valid)

// --- Invalid documents ----------------------------------------------------------

// <p> directly inside <pretext> is not allowed; error names the element.
#let bad = validate(pretext(p("stray")))
#assert(not bad.valid)
#assert(bad.errors.first().message.contains("<p>"))

// Unknown element inside a paragraph.
#assert(not validate(pretext(article(title("T"), p(elem("not-pretext"))))).valid)

// Unknown attribute on <p>; error names the attribute.
#let bad-attr = validate(pretext(article(title("T"), p(zap: "1", "x"))))
#assert(not bad-attr.valid)
#assert(bad-attr.errors.first().message.contains("zap"))

// <b> is NOT a PreTeXt element -- without the strong->alert handler override
// the default mapping would produce an invalid document.
#assert(not validate(pretext(article(title("T"), p(elem("b", "bold"))))).valid)

// --- pretext-dev.rnc (multi-file include of pretext.rnc) -------------------------

#let dev = create-from-relaxng((
  "pretext-dev.rnc": read("/tests/grammars/pretext-dev.rnc"),
  "pretext.rnc": read("/tests/grammars/pretext.rnc"),
  "pf-adapter.rnc": read("/tests/grammars/pf-adapter.rnc"),
  "pf-preamble-adapter.rnc": read("/tests/grammars/pf-preamble-adapter.rnc"),
  "pf_schema.rnc": read("/tests/grammars/pf_schema.rnc"),
))
#assert("pretext" in dev.roots)
#assert((dev.validate)((dev.pretext)((dev.article)((dev.title)("T"), (dev.p)("dev")))).valid)

// --- root template ----------------------------------------------------------------

#assert.eq(type(root(pretext(article(title("T"), p("ok"))))), content)
