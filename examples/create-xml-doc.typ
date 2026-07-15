#import "../src/lib.typ": make-tags, xml-to-string

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
