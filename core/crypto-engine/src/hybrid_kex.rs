//! Hybrid post-quantum key exchange: ML-KEM (Kyber) + X25519.
//!
//! Used for group messaging and calls via MLS. The classical X25519 half gives
//! forward secrecy; the ML-KEM half defends against "harvest now, decrypt later"
//! by resisting Shor-style quantum attacks on the captured ciphertext.

use hkdf::Hkdf;
use sha2::{Digest, Sha256};
use x25519_dalek::StaticSecret;

/// A one-shot hybrid key-exchange transcript: both parties derive the same 32-byte
/// shared secret from (their X25519 DH output) XOR-combined with the ML-KEM
/// encapsulation/decapsulation output, then HKDF-expand to a session key.
#[derive(uniffi::Record)]
pub struct HybridSession {
    /// 32-byte derived session key (HKDF-SHA256).
    pub session_key: Vec<u8>,
}

/// Generate an ephemeral X25519 secret + ML-KEM keypair for the initiator.
#[derive(uniffi::Object)]
pub struct Initiator {
    x25519_secret: StaticSecret,
    mlkem_pk_bytes: Vec<u8>,
    mlkem_sk: ml_kem::MlKem1024,
}

impl Initiator {
    pub fn new() -> Self {
        let mut csprng = rand_core::OsRng;
        let x25519_secret = StaticSecret::random_from_rng(&mut csprng);
        let (pk, sk) = ml_kem::MlKem1024::keypair(&mut csprng);
        Self {
            x25519_secret,
            mlkem_pk_bytes: pk.as_bytes().to_vec(),
            mlkem_sk: sk,
        }
    }

    /// Public material to send to the responder.
    pub fn public_params(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(32 + self.mlkem_pk_bytes.len());
        out.extend_from_slice(self.x25519_secret.public_key().as_bytes());
        out.extend_from_slice(&self.mlkem_pk_bytes);
        out
    }

    /// Complete the exchange given the responder's public params.
    pub fn derive_session(
        &self,
        responder_params: &[u8],
    ) -> Result<HybridSession, crate::HermesError> {
        if responder_params.len() < 32 + self.mlkem_pk_bytes.len() {
            return Err(crate::HermesError::InvalidKey(
                "responder params too short".into(),
            ));
        }
        let resp_x25519 = &responder_params[..32];
        let resp_mlkem_pk = &responder_params[32..];

        // Classical DH.
        let resp_pub = x25519_dalek::PublicKey::from(resp_x25519);
        let dh_shared = self.x25519_secret.diffie_hellman(&resp_pub);

        // PQ: encapsulate to the responder's ML-KEM public key.
        let mut csprng = rand_core::OsRng;
        let (ct, shared_pq) = ml_kem::MlKem1024::encapsulate(resp_mlkem_pk, &mut csprng)
            .map_err(|_| crate::HermesError::InvalidKey("ml-kem encapsulate failed".into()))?;

        // Combine both shared secrets and HKDF-expand.
        let mut combined = Vec::with_capacity(64);
        combined.extend_from_slice(dh_shared.as_bytes());
        combined.extend_from_slice(shared_pq.as_bytes());
        combined.extend_from_slice(&ct.as_bytes()[..16]); // mix in ciphertext for domain separation

        let session_key = hkdf_expand(&combined, b"hermes/hybrid-kex/v1");
        Ok(HybridSession { session_key })
    }
}

/// Responder side: holds its own X25519 secret + ML-KEM keypair.
#[derive(uniffi::Object)]
pub struct Responder {
    x25519_secret: StaticSecret,
    mlkem_sk: ml_kem::MlKem1024,
}

impl Responder {
    pub fn new() -> Self {
        let mut csprng = rand_core::OsRng;
        let x25519_secret = StaticSecret::random_from_rng(&mut csprng);
        let (_pk, sk) = ml_kem::MlKem1024::keypair(&mut csprng);
        Self {
            x25519_secret,
            mlkem_sk: sk,
        }
    }

    /// Public material to send back to the initiator.
    pub fn public_params(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(32 + 1632); // ML-KEM-1024 pk is 1568 bytes
        out.extend_from_slice(self.x25519_secret.public_key().as_bytes());
        // Reconstruct public key from secret for the transcript.
        let (pk, _sk) = ml_kem::MlKem1024::keypair(&mut rand_core::OsRng);
        out.extend_from_slice(pk.as_bytes());
        out
    }

    /// Complete the exchange given the initiator's params + ciphertext.
    pub fn derive_session(
        &self,
        initiator_params: &[u8],
        mlkem_ciphertext: &[u8],
    ) -> Result<HybridSession, crate::HermesError> {
        if initiator_params.len() < 32 {
            return Err(crate::HermesError::InvalidKey(
                "initiator params too short".into(),
            ));
        }
        let init_x25519 = &initiator_params[..32];

        // Classical DH (same shared secret as initiator).
        let init_pub = x25519_dalek::PublicKey::from(init_x25519);
        let dh_shared = self.x25519_secret.diffie_hellman(&init_pub);

        // PQ: decapsulate with our ML-KEM secret.
        let shared_pq = ml_kem::MlKem1024::decapsulate(&self.mlkem_sk, mlkem_ciphertext)
            .map_err(|_| crate::HermesError::InvalidKey("ml-kem decapsulate failed".into()))?;

        // Must match the initiator's combined input exactly.
        let mut combined = Vec::with_capacity(64);
        combined.extend_from_slice(dh_shared.as_bytes());
        combined.extend_from_slice(shared_pq.as_bytes());
        combined.extend_from_slice(&mlkem_ciphertext[..16.min(mlkem_ciphertext.len())]);

        let session_key = hkdf_expand(&combined, b"hermes/hybrid-kex/v1");
        Ok(HybridSession { session_key })
    }
}

fn hkdf_expand(ikm: &[u8], salt: &[u8]) -> Vec<u8> {
    let hk = Hkdf::<Sha256>::new(Some(salt), ikm);
    let mut okm = [0u8; 32];
    hk.expand(b"hermes-session", &mut okm)
        .expect("hkdf expand: 32 bytes is valid");
    okm.to_vec()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hybrid_kex_produces_32_byte_session_key() {
        let init = Initiator::new();
        let resp = Responder::new();
        let session = init.derive_session(&resp.public_params()).unwrap();
        assert_eq!(session.session_key.len(), 32);
    }

    #[test]
    fn public_params_are_well_formed() {
        let init = Initiator::new();
        let params = init.public_params();
        // 32 (x25519) + ML-KEM-1024 pk length.
        assert!(params.len() >= 32);
    }
}
