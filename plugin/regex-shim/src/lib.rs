//! Minimal `regex` stand-in backed by `regex-lite` (see Cargo.toml for why).
//!
//! Implements exactly the API surface relaxng-model uses: `Regex::new`,
//! `Regex::is_match`, `Regex::as_str`, and an `Error` type with a
//! constructible `Syntax(String)` variant. Anything else fails to compile,
//! which is the desired signal to revisit this shim.

#[derive(Debug, Clone)]
pub struct Regex(regex_lite::Regex);

#[derive(Debug, Clone)]
pub enum Error {
    /// A syntax (or any other compilation) error, with a message.
    Syntax(String),
}

impl core::fmt::Display for Error {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        match self {
            Error::Syntax(msg) => write!(f, "regex syntax error: {msg}"),
        }
    }
}

impl std::error::Error for Error {}

impl Regex {
    pub fn new(pattern: &str) -> Result<Regex, Error> {
        regex_lite::Regex::new(pattern)
            .map(Regex)
            .map_err(|e| Error::Syntax(e.to_string()))
    }

    pub fn is_match(&self, haystack: &str) -> bool {
        self.0.is_match(haystack)
    }

    pub fn as_str(&self) -> &str {
        self.0.as_str()
    }
}

impl core::fmt::Display for Regex {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        f.write_str(self.0.as_str())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn handles_the_fixed_xsd_datatype_patterns() {
        // The exact regexes relaxng-model compiles for built-in datatypes.
        let cases: &[(&str, &str, bool)] = &[
            (r"^[a-zA-Z]{1,8}(-[a-zA-Z0-9]{1,8})*$", "en-US", true),
            (
                r"^-?\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z(?:(?:\+|-)\d{2}:\d{2})?)?$",
                "2024-02-29T12:00:00Z",
                true,
            ),
            (r"^\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})?$", "23:59:59.5", true),
            (r"^([0-9a-fA-F]{2})*$", "deadbeef", true),
            (r"^([0-9a-fA-F]{2})*$", "xyz", false),
            (r"^[A-Za-z0-9+/\s]*={0,2}$", "aGVsbG8=", true),
            (r"^--\d{2}-\d{2}(Z|[+-]\d{2}:\d{2})?$", "--02-29", true),
        ];
        for (pat, input, expected) in cases {
            let re = Regex::new(pat).unwrap();
            assert_eq!(re.is_match(input), *expected, "{pat} vs {input}");
        }
    }

    #[test]
    fn unicode_classes_fail_loudly() {
        assert!(matches!(Regex::new(r"\p{L}+"), Err(Error::Syntax(_))));
    }
}
