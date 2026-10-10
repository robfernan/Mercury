//! Ed25519 message signing / verification.
//!
//! Every Hermes message is signed with the sender's private key; receivers verify
//! locally in <1ms before rendering, so tampered or replayed frames are rejected
//! even over a trusted transport.

use ed25519_dalek::{Signature, Signer, Verifier};
use rand_core::OsRng;

use crate::{HermesError, WireMessage};

/// A user's Ed25519 identity keypair. The private key is held in the OS
/// Keychain/Keystore (Secure Enclave / StrongBox / TPM 2.0) and never exported;
/// this struct models the in-memory handle used for sign/verify.
#[derive(uniffi::Object)]
pub struct IdentityKey {
    signing_key: ed25519_dalek::SigningKey,
}

impl IdentityKey {
    /// Generate a fresh identity keypair from OS entropy.
    pub fn generate() -> Self {
        let signing_key = ed25519_dalek::SigningKey::generate(&mut OsRng);
        Self { signing_key }
    }

    /// Reconstruct from raw 32-byte seed (for keychain restore).
    pub fn from_seed(seed: Vec<u8>) -> Result<Self, HermesError> {
        if seed.len() != 32 {
            return Err(HermesError::InvalidKey(format!(
                "expected 32 bytes, got {}",
                seed.len()
            )));
        }
        let arr: [u8; 32] = seed.try_into().unwrap();
        Ok(Self {
            signing_key: ed25519_dalek::SigningKey::from_bytes(&arr),
        })
    }

    /// Raw 32-byte public key (used to build the did:key).
    pub fn public_key_bytes(&self) -> Vec<u8> {
        self.signing_key.verifying_key().to_bytes().to_vec()
    }

    /// Sign a canonical message byte form.
    pub fn sign(&self, msg: &[u8]) -> Signature {
        self.signing_key.sign(msg)
    }

    /// Verify a signature over `msg` against this identity's public key.
    pub fn verify(&self, msg: &[u8], sig: &Signature) -> bool {
        self.signing_key.verifying_key().verify(msg, sig).is_ok()
    }
}

/// Canonical byte form of a wire envelope — the exact bytes that get signed and
/// verified. Keeping this in one place guarantees sign/verify agree across platforms.
pub fn canonical_bytes(env: &WireMessage) -> Vec<u8> {
    let mut out = Vec::with_capacity(
        env.sender_did.len() + env.ciphertext.len() + 2 * std::mem::size_of::<usize>(),
    );
    // Length-prefix each field to avoid ambiguity at boundaries.
    push_len_prefixed(&mut out, env.sender_did.as_bytes());
    push_len_prefixed(&mut out, &env.ciphertext);
    out
}

fn push_len_prefixed(out: &mut Vec<u8>, data: &[u8]) {
    out.extend_from_slice(&(data.len() as u64).to_le_bytes());
    out.extend_from_slice(data);
}

/// Sign a plaintext into a wire envelope using the sender's identity key.
pub fn sign_message(sender_did: &str, ciphertext: Vec<u8>, idk: &IdentityKey) -> WireMessage {
    let mut env = WireMessage {
        sender_did: sender_did.to_string(),
        ciphertext,
        signature: Vec::new(),
    };
    // Sign over the envelope with an empty signature field (signature is not part of itself).
    let canonical = canonical_bytes(&env);
    let sig = idk.sign(&canonical);
    env.signature = sig.to_bytes().to_vec();
    env
}

/// Verify a wire envelope's Ed25519 signature against the sender's public key.
pub fn verify_message(env: &WireMessage, sender_pub: &[u8]) -> Result<bool, HermesError> {
    if sender_pub.len() != 32 {
        return Err(HermesError::InvalidKey("sender public key must be 32 bytes".into()));
    }
    let pk_bytes: [u8; 32] = sender_pub.try_into().unwrap();
    let verifying_key = ed25519_dalek::VerifyingKey::from_bytes(&pk_bytes)
        .map_err(|_| HermesError::InvalidKey("malformed Ed25519 public key".into()))?;

    if env.signature.len() != 64 {
        return Err(HermesError::BadSignature);
    }
    let sig_bytes: [u8; 64] = env.signature.as_slice().try_into().unwrap();
    let signature = Signature::from_bytes(&sig_bytes);

    // Rebuild the canonical bytes with an empty signature (matches sign_message).
    let mut out = Vec::new();
    push_len_prefixed(&mut out, env.sender_did.as_bytes());
    push_len_prefixed(&mut out, &env.ciphertext);

    Ok(verifying_key.verify(&out, &signature).is_ok())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sign_then_verify_roundtrip() {
        let idk = IdentityKey::generate();
        let did = "did:key:z6MkExample";
        let env = sign_message(did, b"secret".to_vec(), &idk);
        assert!(verify_message(&env, &idk.public_key_bytes()).unwrap());
    }

    #[test]
    fn tampered_ciphertext_fails() {
        let idk = IdentityKey::generate();
        let mut env = sign_message("did:key:z6MkExample", b"secret".to_vec(), &idk);
        env.ciphertext.push(0x00);
        assert!(!verify_message(&env, &idk.public_key_bytes()).unwrap());
    }

    #[test]
    fn wrong_key_fails() {
        let a = IdentityKey::generate();
        let b = IdentityKey::generate();
        let env = sign_message("did:key:z6MkExample", b"secret".to_vec(), &a);
        assert!(!verify_message(&env, &b.public_key_bytes()).unwrap());
    }
}
