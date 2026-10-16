//! FTS5 search query normalization and tokenization helper.

#[uniffi::export]
pub fn normalize_search_query(raw_query: String) -> String {
    let sanitized: String = raw_query
        .chars()
        .map(|c| if c.is_alphanumeric() || c.is_whitespace() { c } else { ' ' })
        .collect();
    
    sanitized
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}
