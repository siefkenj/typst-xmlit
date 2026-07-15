# typst-xmlit

Tools for generating, validating, and outputting XML using Typst syntax.

## Authoring XML

Create functions which return XML elements with `make-tag`/`make-tags`.
Use the resulting functions using standard typst syntax. Named arguments are converted to attributes and positional arguments
are treated as children.

```typst
#import "@preview/xmlit:0.1.0": make-tags, xml-to-string

#{
  let (foo, bar) = make-tags("foo", "bar")

  // Typst native XML parsing
  let xml1 = xml(bytes(`<foo><bar baz="zz" />text</foo>`.text))

  // Construct XML by passing using function arguments
  let xml2 = foo(bar(baz: "zz"), "text")

  // Construct XML by passing using a code block
  let xml3 = foo({
    bar(baz: "zz")
    "text"
  })

  // Construct XML by passing content
  let xml4 = foo[#bar(baz: "zz")text]

  [
    // All versions render as `<foo><bar baz="zz" />text</foo>`
    #xml-to-string(xml1)

    #xml-to-string(xml2)

    #xml-to-string(xml3)

    #xml-to-string(xml4)
  ]
}
```

### Markup in bodies

Inside content (`[...]` blocks) markup is automatically converted into tags:

 - `*bold*` → `<b>bold</b>`
 - `_emph_` → `<em>emph</em>`
 - `` `code` `` → `<c>code</c>`
 - `$x^2$` → `<m>x^2</m>`
 - `$ ... $` → `<md>…</md>`

This mapping can be overwritten by providing `handlers` to the make-tag function.

```typst
#let p = make-tag("p", handlers: (
  // strong -> <alert> instead of <b>
  "strong": (c, convert, ctx) => ((tag: "alert", attrs: (:), children: convert(c.body)),),
  // serialize equation bodies yourself (the default emits Typst math source,
  // e.g. $x^2$ -> "x^2", that evals back to the same expression; unsupported
  // constructs like matrices degrade to a repr fallback)
  "math": (body, convert, ctx) => ("...",),
))
#p[A *very important* point about $x^2$.]
```

A handler is called as `handler(element, convert, ctx)`: `convert` turns any
child value (e.g. the element's body) into an array of XML nodes using the
same handler table, and `ctx.handlers` is the merged handler table, for
handlers that delegate to another slot (the built-in `equation` handler
dispatches to `"math"` this way; the `"math"` slot receives the equation's
*body* rather than an element).

Unmapped markup (e.g. headings) raises an error naming the element and the
`handlers:` entry that would map it.

## Typechecked authoring from a RELAX NG grammar

`create-from-relaxng` derives tag functions from a RELAX NG grammar (compact
syntax, `.rnc`) and validates the composed document — via a bundled WASM
plugin (see [plugin/](plugin/README.md)):

```typst
#import "@preview/xmlit:0.1.0": create-from-relaxng

#let (root, foo, bar) = create-from-relaxng(
  "start = element foo { element bar { attribute baz { text } }* }",
)

#show: root

#foo[#bar(baz: "xx")]
```

The returned dictionary has one tag function per element defined in the
grammar, plus:

- `root` — a template (`#show: root`) that serializes its body, validates it
  against the grammar, and renders the XML source. Invalid documents fail
  compilation with a readable panic, e.g.:

  ```
  XML failed RELAX NG validation:
  - element <qux> is not allowed here. Expected element(s): bar. (line 1, column 7)
  Document was: <foo><qux /></foo>
  ```

- `validate` — validate content or an XML string without panicking; returns
  `(valid: bool, errors: (..))`.
- `roots` / `elements` — the allowed document-root names and all element names.

These reserved keys win over grammar elements with the same names. A
`handlers:` argument is forwarded to every generated tag (see above).

## Serializing

`xml-to-string` accepts authored trees (the return value of a tag function or
any markup content), plain node dictionaries/strings/arrays, and — faithfully —
the output of Typst's built-in `xml()` reader:

```typst
#xml-to-string(xml("doc.xml"))
```

Attribute order is preserved, text/attribute contexts are escaped correctly,
empty elements self-close, and default-namespace declarations are re-emitted
only where the namespace actually changes.

## Testing

Tests run with [tytanic](https://github.com/typst-community/tytanic):

```sh
tt run
```

See [Development](#development) for the full testing story.

## Development

Clone with submodules (the RELAX NG plugin vendors its Rust dependencies):

```sh
git clone --recursive <repo>
# or, after a plain clone:
git submodule update --init --recursive
```

The dev container ships everything needed: `typst`, `tt` (tytanic), the Rust
toolchain with the `wasm32-unknown-unknown` target, and `wasm-opt` (binaryen).

### Tests

The suite has three layers:

1. **Unit tests** — `tests/<name>/test.typ`, discovered and run by
   [tytanic](https://github.com/typst-community/tytanic). They are
   assert-based, compile-only tests: a test passes iff it compiles.

   ```sh
   tt list             # show the suites
   tt run              # run everything
   tt run relaxng      # run one suite
   ```

   The `relaxng-pretext` and `relaxng-prefig` suites exercise the real
   PreTeXt and PreFigure grammars (fixtures and provenance in
   `tests/grammars/`).

2. **Expected failures** — `tests/expect-fail/*.typ`. Each file must FAIL to
   compile with the specific error named in its header comment. Deliberately
   not named `test.typ`, so tytanic ignores them; check them with the loop in
   `tests/expect-fail/README.md`.

3. **Visual smoke tests** — co-located `src/**/*.test.typ` files. Compile one
   and eyeball the output:

   ```sh
   typst compile --root . src/relaxng/relaxng.test.typ out.pdf
   ```

The plugin also has native Rust tests: `cd plugin/typst-relaxng && cargo test`.

### Rebuilding the WASM plugin

The compiled plugin is committed at `src/relaxng/relaxng.wasm`; rebuild it
after changing `plugin/typst-relaxng`:

```sh
plugin/build.sh    # build + wasm-opt + install into src/relaxng/
```

See [plugin/README.md](plugin/README.md) for the architecture, the
chrono/regex shims, and binary-size notes.
