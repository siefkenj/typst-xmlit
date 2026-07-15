# plugin/ — the RELAX NG WASM plugin

Rust sources for the Typst plugin behind `create-from-relaxng`. The compiled
artifact is built by `plugin/build.sh` to `src/relaxng/relaxng.wasm` (git-ignored,
not committed) and bundled into the published package by `make_dist.sh`; CI
builds it and hands it to the test job as an artifact. Typst users of the
published package never need this directory; it only matters when changing the
plugin.

## Layout

- `typst-relaxng/` — the plugin crate. Implements the
  [Typst plugin protocol](https://typst.app/docs/reference/foundations/plugin/#protocol)
  by hand (`src/protocol.rs`, no protocol dependency) and exports:
  - `list_elements(rnc) -> {"roots": [...], "elements": [...]}`
  - `validate(rnc, xml) -> {"valid": bool, "errors": [{message, start, end, line, column}]}`
- `relaxng_validator_wasm/` — git submodule
  ([siefkenj/relaxng_validator_wasm](https://github.com/siefkenj/relaxng_validator_wasm)),
  which itself contains the upstream
  [dholroyd/relaxng-rust](https://github.com/dholroyd/relaxng-rust) crates as a
  nested submodule. Clone with `git submodule update --init --recursive`.
- `chrono-shim/` — a parse-only `chrono` stand-in, applied via
  `[patch.crates-io]` in `typst-relaxng/Cargo.toml`. Real chrono's default
  `wasmbind` feature links wasm-bindgen/js-sys imports on
  wasm32-unknown-unknown, which the Typst plugin runtime cannot provide; the
  dependency tree's only chrono usage is `NaiveDate::parse_from_str` for xsd
  date validation, which the shim implements.

## Build

```sh
plugin/build.sh    # build (nightly if available) + wasm-opt + install
```

or manually:

```sh
cd plugin/typst-relaxng
cargo test                                          # native unit tests
cargo build --release --target wasm32-unknown-unknown
cp target/wasm32-unknown-unknown/release/typst_relaxng.wasm ../../src/relaxng/relaxng.wasm
```

### Binary size

The committed artifact is built by `build.sh` with every applicable shrink
(sizes as measured at time of writing):

| step | size |
|---|---|
| `opt-level = "s"` baseline | 3.01 MB |
| chrono-shim (drops wasm-bindgen glue) | 2.56 MB |
| `opt-level = "z"`, fat LTO, `codegen-units = 1`, `strip`, `panic = "abort"` | 1.58 MB |
| nightly `-Cpanic=immediate-abort` + `-Z build-std` (optional) | 1.36 MB |
| `wasm-opt -Oz` (binaryen) | 1.24 MB |
| regex-shim (regex-lite instead of regex) | **0.60 MB** |

`immediate-abort` removes panic-message formatting; user-facing errors are
unaffected because they are returned as protocol-level `Result`s, and plugin
panics were already opaque traps in Typst.

The regex-shim (`regex-shim/`, applied like the chrono-shim via
`[patch.crates-io]`) backs relaxng-model's datatype checks with `regex-lite`
instead of full `regex`, dropping the Unicode tables and DFA machinery. All
fixed xsd datatype regexes (dateTime, duration, hexBinary, ...) are covered by
regex-lite; user `pattern` facets using Unicode classes (`\p{...}`) fail
loudly at grammar compile time instead of being silently accepted
(`tests/relaxng/test.typ` exercises the datatype paths end-to-end).

The remaining bulk is the grammar compiler/validator itself plus serde_json.

Then run the Typst test suite from the repository root:

```sh
for t in tests/*/test.typ; do typst compile --root . "$t" /tmp/out.pdf; done
```

## Design notes

- Grammar compilation errors are returned as protocol-level errors (readable
  strings) rather than panics: the plugin compiles the grammar itself with
  `relaxng-model` (the wrapper's own compile path panics, which would trap the
  plugin opaquely).
- `validate` is two-tier: the **fast path** compiles the grammar once and runs
  a bare validator loop that stops at the first error. Only if the document is
  invalid does the **slow path** rerun it through the wrapper's diagnostic
  pipeline (recompile + expected-element/attribute sampling + error trimming)
  to produce good messages. Valid documents -- the common case -- pay for one
  compile and one pass. Typst additionally memoizes plugin calls by argument.
- Measured on the full PreTeXt grammar (76 KB rnc + 3 included files): one
  factory + one valid document validation ≈ 1 s total inside Typst's wasm
  interpreter.
- Element/root listing walks the compiled `relaxng-model` pattern tree;
  wildcard name classes (`NsName`/`AnyName`) are not enumerable and are
  skipped.
