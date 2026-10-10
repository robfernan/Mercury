//! Hermes shared crypto core.
//!
//! One Rust library, compiled once and bound natively into Dart (Flutter),
//! Kotlin and Swift via uniffi. It owns the heavy compute + crypto so behavior
//! is bit-identical across all six platforms:
//!
//! - Double Ratchet (direct messages) — forward secrecy + post-compromise security
//! - Hybrid post-quantum key exchange (ML-KEM + X25519) for groups/calls
//! - Ed25519 message signing / verification (<1ms verify target)
//! - CRDT state reconciliation (Lamport timestamps + LWW registers)
//!
//! FTS5 full-text search is executed in the client's SQLite via Drift; this core
//! provides canonical query normalization so ranking is consistent everywhere.

pub mod crdt;
pub mod ed25519;
pub mod hybrid_kex;
pub mod ratchet;
pub mod search;

uniffi::setup_scaffolding!();

/// A small, uniffi-friendly error type surfaced to Dart/Kotlin/Swift.
#[derive(Debug, thiserror::Error)]
pub enum HermesError {
    #[error("invalid key material: {0}")]
    InvalidKey(String),
    #[error("signature verification failed")]
    BadSignature,
    #[error("decryption failed (AEAD tag mismatch)")]
    DecryptFailed,
    #[error("ratchet out of sync: {0}")]
    RatchetDesync(String),
    #[error("crdt merge conflict resolved by lww")]
    CrdtConflict,
}

/// Canonical message envelope that travels over the wire. The server stores this
/// opaquely; it never sees `plaintext`.
#[derive(uniffi::Record)]
pub struct WireMessage {
    /// Sender's did:key (public identity).
    pub sender_did: String,
    /// AEAD ciphertext + nonce (XChaCha20-Poly1305 over the ratchet message key).
    pub ciphertext: Vec<u8>,
    /// Ed25519 signature over the canonical byte form of this envelope.
    pub signature: Vec<u8>,
}

/// Result of verifying + decrypting a wire message on receive.
#[derive(uniffi::Record)]
pub struct DecryptedMessage {
    pub plaintext: String,
    /// True when the Ed25519 signature verified against the sender's public key.
    pub signature_valid: bool,
}
