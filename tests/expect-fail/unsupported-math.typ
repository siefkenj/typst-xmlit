// MUST FAIL: math constructs that cannot be faithfully serialized (here a
// matrix) panic with a "cannot faithfully serialize math construct" error
// instead of degrading, preserving math-to-string's eval round-trip
// guarantee. Override the "math" handler to support them.

#import "/src/lib.typ": make-tag, xml-to-string

#let p = make-tag("p")
#xml-to-string(p[$mat(1, 2; 3, 4)$])
