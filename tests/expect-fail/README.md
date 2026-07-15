# Expected-failure probes

Each `.typ` file in this directory MUST FAIL to compile with the specific
`xmlit:` error named in its header comment. They are intentionally not named
`test.typ`, so neither tytanic nor a `tests/*/test.typ` glob picks them up.

Check them with:

```sh
for f in tests/expect-fail/*.typ; do
  if typst compile --root . "$f" /dev/null -f pdf 2>/dev/null; then
    echo "UNEXPECTED PASS: $f"
  else
    echo "ok (fails as expected): $f"
  fi
done
```
