// xmlit: Generate XML documents using Typst syntax.
//
// Functions created with `make-tag` accept named arguments as XML attributes
// and positional string arguments as child content.
//
// Example:
//   #let foo = make-tag("foo")
//   #let bar = make-tag("bar")
//   #foo(bar(baz: "xx"))
//   // => <foo><bar baz="xx" /></foo>

/// Escape special XML characters in a string value.
#let xml-escape(s) = {
  s.replace("&", "&amp;")
   .replace("<", "&lt;")
   .replace(">", "&gt;")
   .replace("\"", "&quot;")
   .replace("'", "&apos;")
}

/// Serialize a single XML node (dictionary with `tag`, `attrs`, `children`)
/// or a plain string to an XML string.
#let to-xml(node) = {
  if type(node) == str {
    return xml-escape(node)
  }

  let tag = node.tag
  let attrs = node.at("attrs", default: (:))
  let children = node.at("children", default: ())

  // Build attribute string
  let attrs-str = attrs.pairs().map(((k, v)) => {
    " " + k + "=\"" + xml-escape(str(v)) + "\""
  }).join("")

  // Serialize children
  let inner = children.map(to-xml).join("")

  if inner == "" {
    "<" + tag + attrs-str + " />"
  } else {
    "<" + tag + attrs-str + ">" + inner + "</" + tag + ">"
  }
}

/// Create a function that produces an XML element with the given tag name.
/// Named arguments become XML attributes; positional arguments become child
/// elements (either strings or nodes returned by other `make-tag` functions).
///
/// Example:
///   #let ul = make-tag("ul")
///   #let li = make-tag("li")
///   #ul(li("item 1"), li("item 2"))
///   // => <ul><li>item 1</li><li>item 2</li></ul>
#let make-tag(tag) = (..args) => {
  let attrs = args.named()
  let children = args.positional()
  (tag: tag, attrs: attrs, children: children)
}
