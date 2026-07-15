// MUST FAIL: a bare dictionary interpolated into a markup body displays as
// `raw` with lang "typc"; the walker rejects it with a targeted
// "plain code value was interpolated into markup" error.

#import "/src/lib.typ": make-tag

#let foo = make-tag("foo")
// A dict-returning function simulating the mistake (real tag functions
// return metadata content, which is fine).
#let bad-bar(..args) = (tag: "bar", attrs: args.named(), children: ())

#foo[#bad-bar(baz: "zz")]
