//! Typst plugin: RELAX NG grammar introspection + XML validation.
//!
//! Exports (Typst plugin protocol):
//!
//! - `list_elements(rnc) -> json`
//!   Compiles a RELAX NG *compact syntax* grammar and returns
//!   `{"roots": [...], "elements": [...]}` -- the element names allowed as
//!   the document root, and every named element defined in the grammar.
//!
//! - `validate(rnc, xml) -> json`
//!   Validates an XML document against the grammar and returns
//!   `{"valid": true, "errors": []}` or
//!   `{"valid": false, "errors": [{"message", "start", "end", "line", "column"}]}`.
//!
//! Both functions return a protocol-level error (readable string) if the
//! grammar itself fails to compile.

mod protocol;

use std::cell::RefCell;
use std::collections::HashSet;
use std::path::Path;
use std::rc::Rc;

use relaxng_model::model::{DefineRule, NameClass, Pattern};
use relaxng_model::{Compiler, Syntax};
use relaxng_validator_wasm::{check_simple, ValidationError, VirtualFileSystem};

// ---------------------------------------------------------------------------
// Protocol entry points
// ---------------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn list_elements(rnc_len: usize) -> i32 {
    let buf = protocol::read_args(rnc_len);
    protocol::respond(impl_list_elements(&buf))
}

#[no_mangle]
pub extern "C" fn validate(rnc_len: usize, xml_len: usize) -> i32 {
    let buf = protocol::read_args(rnc_len + xml_len);
    let (rnc, xml) = buf.split_at(rnc_len);
    protocol::respond(impl_validate(rnc, xml))
}

// ---------------------------------------------------------------------------
// Grammar compilation
// ---------------------------------------------------------------------------

type StartRule = Rc<RefCell<Option<DefineRule>>>;

/// The grammar argument is either raw RELAX NG compact syntax (single file)
/// or -- when it starts with `{` -- a JSON object mapping file names to file
/// contents (a virtual file system for grammars with `include`/`external`
/// references). The first key is the entry point.
///
/// Returns the parsed VFS and the entry-point file name. Since compiling
/// consumes the VFS, callers that need to compile twice call this twice.
fn parse_grammar(grammar: &str) -> Result<(VirtualFileSystem, String), String> {
    if grammar.trim_start().starts_with('{') {
        let vfs: VirtualFileSystem = serde_json::from_str(grammar)
            .map_err(|e| format!("invalid grammar VFS JSON: {e}"))?;
        let entry = vfs
            .first_key()
            .ok_or_else(|| "grammar VFS JSON object has no entries".to_string())?
            .to_string();
        Ok((vfs, entry))
    } else {
        Ok((
            VirtualFileSystem::from_single("main.rnc", grammar),
            "main.rnc".to_string(),
        ))
    }
}

fn compile(grammar: &str) -> Result<StartRule, String> {
    let (vfs, entry) = parse_grammar(grammar)?;
    // Syntax::Auto: `.rng` files parse as XML syntax, everything else compact.
    let mut compiler = Compiler::new(vfs, Syntax::Auto);
    compiler
        .compile(Path::new(&entry))
        .map(|compiled| compiled.start)
        .map_err(|e| format!("failed to compile RELAX NG grammar: {e:?}"))
}

fn utf8(bytes: &[u8], what: &str) -> Result<String, String> {
    String::from_utf8(bytes.to_vec()).map_err(|_| format!("{what} is not valid UTF-8"))
}

// ---------------------------------------------------------------------------
// list_elements: walk the compiled model
// ---------------------------------------------------------------------------

fn name_class_names(nc: &NameClass, out: &mut Vec<String>) {
    match nc {
        NameClass::Named { name, .. } => out.push(name.clone()),
        NameClass::Alt { a, b } => {
            name_class_names(a, out);
            name_class_names(b, out);
        }
        // NsName / AnyName wildcards are not enumerable as factory functions.
        _ => {}
    }
}

/// Recursively collect element names. `top` is true while we have not yet
/// descended into any element -- those names are the allowed document roots.
/// `visited` guards against reference cycles; keyed by (define, top) so a
/// define reached both at top level and deeper is examined in both roles.
fn walk_pattern(
    pattern: &Pattern,
    top: bool,
    roots: &mut Vec<String>,
    all: &mut Vec<String>,
    visited: &mut HashSet<(usize, bool)>,
) {
    match pattern {
        Pattern::Element(nc, inner, _, _) => {
            let mut names = Vec::new();
            name_class_names(nc, &mut names);
            if top {
                roots.extend(names.iter().cloned());
            }
            all.extend(names);
            walk_pattern(inner, false, roots, all, visited);
        }
        Pattern::Ref(_, _, pat_ref) => {
            let key = (Rc::as_ptr(&pat_ref.0) as usize, top);
            if visited.insert(key) {
                if let Some(rule) = pat_ref.0.borrow().as_ref() {
                    walk_pattern(rule.pattern(), top, roots, all, visited);
                }
            }
        }
        Pattern::Choice(children, _)
        | Pattern::Interleave(children, _)
        | Pattern::Group(children, _) => {
            for child in children {
                walk_pattern(child, top, roots, all, visited);
            }
        }
        Pattern::Mixed(inner, _)
        | Pattern::Optional(inner, _)
        | Pattern::ZeroOrMore(inner, _)
        | Pattern::OneOrMore(inner, _)
        | Pattern::List(inner, _) => {
            walk_pattern(inner, top, roots, all, visited);
        }
        // Attribute patterns cannot contain elements.
        Pattern::Attribute(..) => {}
        Pattern::DatatypeName {
            except: Some(inner),
            ..
        } => walk_pattern(inner, top, roots, all, visited),
        _ => {}
    }
}

fn impl_list_elements(rnc: &[u8]) -> Result<Vec<u8>, String> {
    let rnc = utf8(rnc, "grammar")?;
    let start = compile(&rnc)?;
    let borrowed = start.borrow();
    let rule = borrowed
        .as_ref()
        .ok_or_else(|| "grammar has no start rule".to_string())?;

    let mut roots = Vec::new();
    let mut all = Vec::new();
    let mut visited = HashSet::new();
    walk_pattern(rule.pattern(), true, &mut roots, &mut all, &mut visited);

    for list in [&mut roots, &mut all] {
        list.sort_unstable();
        list.dedup();
    }

    #[derive(serde::Serialize)]
    struct Response {
        roots: Vec<String>,
        elements: Vec<String>,
    }
    serde_json::to_vec(&Response {
        roots,
        elements: all,
    })
    .map_err(|e| e.to_string())
}

// ---------------------------------------------------------------------------
// validate: run the validator and produce readable messages
// ---------------------------------------------------------------------------

#[derive(serde::Serialize)]
struct OutError {
    message: String,
    start: Option<usize>,
    end: Option<usize>,
    line: Option<usize>,
    column: Option<usize>,
}

#[derive(serde::Serialize)]
struct ValidateResponse {
    valid: bool,
    errors: Vec<OutError>,
}

/// 1-based (line, column) of byte offset `pos` in `doc`.
fn line_col(doc: &str, pos: usize) -> (usize, usize) {
    let prefix = &doc[..pos.min(doc.len())];
    let line = prefix.matches('\n').count() + 1;
    let column = prefix.len() - prefix.rfind('\n').map(|i| i + 1).unwrap_or(0) + 1;
    (line, column)
}

fn json_str<'a>(v: &'a serde_json::Value, pointer: &str) -> Option<&'a str> {
    v.pointer(pointer).and_then(|x| x.as_str())
}

fn json_usize(v: &serde_json::Value, pointer: &str) -> Option<usize> {
    v.pointer(pointer).and_then(|x| x.as_u64()).map(|x| x as usize)
}

fn expected_suffix(expected_elements: &[String], expected_attributes: &[String]) -> String {
    if !expected_elements.is_empty() {
        format!(" Expected element(s): {}.", expected_elements.join(", "))
    } else if !expected_attributes.is_empty() {
        format!(" Expected attribute(s): {}.", expected_attributes.join(", "))
    } else {
        String::new()
    }
}

fn format_error(err: &ValidationError, doc: &str) -> OutError {
    let mut span: Option<(usize, usize)> = None;
    let message = match err {
        ValidationError::Xml { message } => format!("XML parse error: {message}"),
        ValidationError::NotAllowed {
            token,
            expected_elements,
            expected_attributes,
        } => {
            let token_type = json_str(token, "/type").unwrap_or("");
            let suffix = expected_suffix(expected_elements, expected_attributes);
            match token_type {
                "ElementStart" => {
                    let local = json_str(token, "/local/text").unwrap_or("?");
                    span = json_usize(token, "/span/start").zip(json_usize(token, "/span/end"));
                    format!("element <{local}> is not allowed here.{suffix}")
                }
                "Attribute" => {
                    let local = json_str(token, "/local/text").unwrap_or("?");
                    span = json_usize(token, "/span/start").zip(json_usize(token, "/span/end"));
                    format!("attribute \"{local}\" is not allowed on this element.{suffix}")
                }
                "Text" => {
                    span = json_usize(token, "/text/start").zip(json_usize(token, "/text/end"));
                    format!("text content is not allowed here.{suffix}")
                }
                "ElementEnd" => {
                    span = json_usize(token, "/span/start").zip(json_usize(token, "/span/end"));
                    format!("element ends here but required content is missing.{suffix}")
                }
                other => format!("token ({other}) is not allowed here.{suffix}"),
            }
        }
        ValidationError::UndefinedNamespacePrefix { prefix } => {
            let name = json_str(prefix, "/text").unwrap_or("?");
            span = json_usize(prefix, "/start").zip(json_usize(prefix, "/end"));
            format!("undefined namespace prefix \"{name}\"")
        }
        ValidationError::UndefinedEntity { name, span: s } => {
            span = Some((s.start, s.end));
            format!("undefined entity \"{name}\"")
        }
        ValidationError::InvalidOrUnclosedEntity { span: s } => {
            span = Some((s.start, s.end));
            "invalid or unclosed entity".to_string()
        }
        ValidationError::TextBufferOverflow => "internal text buffer limit exceeded".to_string(),
        ValidationError::TooManyPatterns => "internal pattern limit exceeded".to_string(),
    };

    let (line, column) = match span {
        Some((start, _)) => {
            let (l, c) = line_col(doc, start);
            (Some(l), Some(c))
        }
        None => (None, None),
    };
    OutError {
        message,
        start: span.map(|s| s.0),
        end: span.map(|s| s.1),
        line,
        column,
    }
}

/// Fast validation: a bare validator loop over an already-compiled grammar.
/// Stops at the first error -- no diagnostics, no expected-element sampling.
/// Returns Ok(true) if the document is valid.
fn fast_validate(start: StartRule, doc: &str) -> Result<bool, String> {
    let tokenizer = xmlparser::Tokenizer::from(doc);
    let mut validator = relaxng_validator::Validator::new(start, tokenizer)
        .map_err(|e| format!("failed to set up validator: {e:?}"))?;
    while let Some(item) = validator.validate_next() {
        if item.is_err() {
            return Ok(false);
        }
    }
    Ok(true)
}

fn impl_validate(rnc: &[u8], xml: &[u8]) -> Result<Vec<u8>, String> {
    let rnc = utf8(rnc, "grammar")?;
    let xml = utf8(xml, "XML document")?;

    // Fast path: compile once ourselves (readable errors -- the wrapper's own
    // compile path panics, which would trap the plugin) and run a bare
    // validation loop. Valid documents -- the common case -- pay for exactly
    // one grammar compile and one document pass.
    let start = compile(&rnc)?;
    let response = if fast_validate(start, &xml)? {
        ValidateResponse {
            valid: true,
            errors: Vec::new(),
        }
    } else {
        // Slow path: rerun through the wrapper's diagnostic pipeline
        // (recompiles the grammar; samples expected elements/attributes and
        // trims redundant errors) to produce good messages.
        let (vfs, entry) = parse_grammar(&rnc)?;
        match check_simple(vfs, &entry, &xml) {
            Ok(()) => ValidateResponse {
                // Should not happen (same engine underneath); trust the
                // diagnostic run.
                valid: true,
                errors: Vec::new(),
            },
            Err(errors) => ValidateResponse {
                valid: false,
                errors: errors.iter().map(|e| format_error(e, &xml)).collect(),
            },
        }
    };
    serde_json::to_vec(&response).map_err(|e| e.to_string())
}

// ---------------------------------------------------------------------------
// Native tests (cargo test on the host target)
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    const GRAMMAR: &str = r#"
start = element foo { element bar { attribute baz { text } }* }
"#;

    #[test]
    fn lists_elements_and_roots() {
        let out = impl_list_elements(GRAMMAR.as_bytes()).unwrap();
        let v: serde_json::Value = serde_json::from_slice(&out).unwrap();
        assert_eq!(v["roots"], serde_json::json!(["foo"]));
        assert_eq!(v["elements"], serde_json::json!(["bar", "foo"]));
    }

    #[test]
    fn validates_good_document() {
        let out = impl_validate(GRAMMAR.as_bytes(), br#"<foo><bar baz="zz" /></foo>"#).unwrap();
        let v: serde_json::Value = serde_json::from_slice(&out).unwrap();
        assert_eq!(v["valid"], serde_json::json!(true));
    }

    #[test]
    fn reports_bad_document_with_message() {
        let out = impl_validate(GRAMMAR.as_bytes(), br#"<foo><qux /></foo>"#).unwrap();
        let v: serde_json::Value = serde_json::from_slice(&out).unwrap();
        assert_eq!(v["valid"], serde_json::json!(false));
        let msg = v["errors"][0]["message"].as_str().unwrap();
        assert!(msg.contains("<qux>"), "message was: {msg}");
        assert!(msg.contains("bar"), "expected-elements hint missing: {msg}");
    }

    #[test]
    fn reports_grammar_error_readably() {
        let err = impl_validate(b"start = element foo {", b"<foo />").unwrap_err();
        assert!(err.contains("compile"), "error was: {err}");
    }

    #[test]
    fn supports_multi_file_vfs_grammars() {
        // Literal JSON text: the first key is the entry point, and the VFS
        // preserves document order (serde_json's json! macro would sort keys).
        let vfs = r#"{
            "main.rnc": "start = element outer { external \"inner.rnc\" }",
            "inner.rnc": "element inner { text }"
        }"#;

        let out = impl_list_elements(vfs.as_bytes()).unwrap();
        let v: serde_json::Value = serde_json::from_slice(&out).unwrap();
        assert_eq!(v["roots"], serde_json::json!(["outer"]));
        assert_eq!(v["elements"], serde_json::json!(["inner", "outer"]));

        let out = impl_validate(vfs.as_bytes(), b"<outer><inner>x</inner></outer>").unwrap();
        let v: serde_json::Value = serde_json::from_slice(&out).unwrap();
        assert_eq!(v["valid"], serde_json::json!(true));

        let missing = r#"{"main.rnc": "start = element outer { external \"nope.rnc\" }"}"#;
        let err = impl_list_elements(missing.as_bytes()).unwrap_err();
        assert!(err.contains("nope.rnc"), "error was: {err}");
    }
}
