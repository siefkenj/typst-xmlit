# Grammar fixtures

Real-world RELAX NG grammars used by the `relaxng-pretext` and
`relaxng-prefig` test suites.

| file | source |
|---|---|
| `pretext.rnc` | [PreTeXtBook/pretext](https://github.com/PreTeXtBook/pretext/tree/master/schema) `schema/pretext.rnc` |
| `pretext-dev.rnc` | same, `schema/pretext-dev.rnc` (includes `pretext.rnc`) |
| `pf-adapter.rnc` | same, `schema/pf-adapter.rnc` |
| `pf-preamble-adapter.rnc` | same, `schema/pf-preamble-adapter.rnc` |
| `pf_schema.rnc` | same, `schema/pf_schema.rnc` — byte-identical (modulo trailing whitespace) to [davidaustinm/prefigure](https://github.com/davidaustinm/prefigure/tree/main/prefig/resources/schema) `prefig/resources/schema/pf_schema.rnc` |

Include graph: `pretext.rnc` → `pf-adapter.rnc` / `pf-preamble-adapter.rnc`
→ `pf_schema.rnc`; `pretext-dev.rnc` → `pretext.rnc`.

Refresh with:

```sh
cd tests/grammars
for f in pretext.rnc pretext-dev.rnc pf-adapter.rnc pf-preamble-adapter.rnc pf_schema.rnc; do
  curl -sO "https://raw.githubusercontent.com/PreTeXtBook/pretext/master/schema/$f"
done
```
