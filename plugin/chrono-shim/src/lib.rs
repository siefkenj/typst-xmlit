//! Minimal `chrono` stand-in for the typst-relaxng wasm build.
//!
//! Implements only `NaiveDate::parse_from_str` with the `"%Y-%m-%d"` format,
//! which is the single chrono call in the dependency tree (relaxng-model's
//! xsd `date` datatype check). Any other usage fails to compile, which is the
//! desired signal to revisit this shim.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct NaiveDate;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ParseError;

impl core::fmt::Display for ParseError {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        f.write_str("invalid date")
    }
}

fn is_leap_year(y: i64) -> bool {
    (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
}

fn days_in_month(y: i64, m: u32) -> u32 {
    match m {
        1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
        4 | 6 | 9 | 11 => 30,
        2 => {
            if is_leap_year(y) {
                29
            } else {
                28
            }
        }
        _ => 0,
    }
}

impl NaiveDate {
    /// Parse a date string. Only the `"%Y-%m-%d"` format is supported.
    pub fn parse_from_str(s: &str, fmt: &str) -> Result<NaiveDate, ParseError> {
        assert_eq!(
            fmt, "%Y-%m-%d",
            "chrono-shim only implements the %Y-%m-%d format"
        );

        // Optional leading minus for negative (BCE) years.
        let (neg, rest) = match s.strip_prefix('-') {
            Some(r) => (true, r),
            None => (false, s),
        };

        let mut parts = rest.splitn(3, '-');
        let (Some(y), Some(m), Some(d), None) =
            (parts.next(), parts.next(), parts.next(), parts.next())
        else {
            return Err(ParseError);
        };

        // Year: at least 4 digits (chrono accepts >= 1 digit for %Y, but xsd
        // dates are zero-padded; accept 1+ digits to stay permissive).
        if y.is_empty() || !y.bytes().all(|b| b.is_ascii_digit()) {
            return Err(ParseError);
        }
        let year: i64 = y.parse().map_err(|_| ParseError)?;
        let year = if neg { -year } else { year };

        // Month and day: 1-2 digits each.
        for p in [m, d] {
            if p.is_empty() || p.len() > 2 || !p.bytes().all(|b| b.is_ascii_digit()) {
                return Err(ParseError);
            }
        }
        let month: u32 = m.parse().map_err(|_| ParseError)?;
        let day: u32 = d.parse().map_err(|_| ParseError)?;

        if !(1..=12).contains(&month) || day == 0 || day > days_in_month(year, month) {
            return Err(ParseError);
        }
        Ok(NaiveDate)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_valid_dates() {
        for s in ["2024-02-29", "1999-12-31", "0001-01-01", "-0044-03-15"] {
            assert!(NaiveDate::parse_from_str(s, "%Y-%m-%d").is_ok(), "{s}");
        }
    }

    #[test]
    fn rejects_invalid_dates() {
        for s in [
            "2023-02-29", // not a leap year
            "2024-13-01",
            "2024-00-10",
            "2024-01-32",
            "2024-1",
            "not-a-date",
            "",
        ] {
            assert!(NaiveDate::parse_from_str(s, "%Y-%m-%d").is_err(), "{s}");
        }
    }
}
