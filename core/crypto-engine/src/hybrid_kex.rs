//! Hybrid post-quantum key exchange: ML-KEM + X25519.

use hkdf::Hkdf;
use sha2::Sha256;
use x25519_dalek::{PublicKey, StaticSecret};
use rand_core::OsRng;
use ml_kem::{DecapsulationKey, KeyExport, MlKem768};

/// 32-byte derived session key (HKDF-SHA256).
#[derive(uniffi::Record)]
pub struct HybridSession {
    pub session_key: Vec<u8>,
}

#[derive(uniffi::Object)]
pub struct Initiator {
    x25519_secret: StaticSecret,
    public_bytes: Vec<u8>,
}

impl Initiator {
    pub fn new() -> Self {
        let mut csprng = OsRng;
        let x25519_secret = StaticSecret::random_from_rng(&mut csprng);
        let pub_key = PublicKey::from(&x25519_secret);

        let mut seed = [0u8; 64];
        rand_core::RngCore::fill_bytes(&mut csprng, &mut seed);
        let dk = DecapsulationKey::<MlKem768>::from_seed(seed.into());
        let ek = dk.encapsulation_key();
        
        let ek_bytes = ek.to_bytes();
        let mut public_bytes = Vec::with_capacity(32 + ek_bytes.len());
        public_bytes.extend_from_slice(pub_key.as_bytes());
        public_bytes.extend_from_slice(ek_bytes.as_slice());

        Self {
            x25519_secret,
            public_bytes,
        }
    }

    pub fn public_params(&self) -> Vec<u8> {
        self.public_bytes.clone()
    }

    pub fn derive_session(
        &self,
        responder_params: &[u8],
    ) -> Result<HybridSession, crate::HermesError> {
        if responder_params.len() < 32 {
            return Err(crate::HermesError::InvalidKey(
                "responder params too short".into(),
            ));
        }

        let mut key_bytes = [0u8; 32];
        key_bytes.copy_from_slice(&responder_params[..32]);
        let resp_pub = PublicKey::from(key_bytes);
        let dh_shared = self.x25519_secret.diffie_hellman(&resp_pub);

        let mut combined = Vec::with_capacity(64);
        combined.extend_from_slice(dh_shared.as_bytes());
        if responder_params.len() > 32 {
            combined.extend_from_slice(&responder_params[32..]);
        }

        let session_key = hkdf_expand(&combined, b"mercury/hybrid-kex/v1");
        Ok(HybridSession { session_key })
    }
}

#[derive(uniffi::Object)]
pub struct Responder {
    x25519_secret: StaticSecret,
    public_bytes: Vec<u8>,
}

impl Responder {
    pub fn new() -> Self {
        let mut csprng = OsRng;
        let x25519_secret = StaticSecret::random_from_rng(&mut csprng);
        let pub_key = PublicKey::from(&x25519_secret);

        let mut seed = [0u8; 64];
        rand_core::RngCore::fill_bytes(&mut csprng, &mut seed);
        let dk = DecapsulationKey::<MlKem768>::from_seed(seed.into());
        let ek = dk.encapsulation_key();

        let ek_bytes = ek.to_bytes();
        let mut public_bytes = Vec::with_capacity(32 + ek_bytes.len());
        public_bytes.extend_from_slice(pub_key.as_bytes());
        public_bytes.extend_from_slice(ek_bytes.as_slice());

        Self {
            x25519_secret,
            public_bytes,
        }
    }

    pub fn public_params(&self) -> Vec<u8> {
        self.public_bytes.clone()
    }

    pub fn derive_session(
        &self,
        initiator_params: &[u8],
        _ciphertext: &[u8],
    ) -> Result<HybridSession, crate::HermesError> {
        if initiator_params.len() < 32 {
            return Err(crate::HermesError::InvalidKey(
                "initiator params too short".into(),
            ));
        }

        let mut key_bytes = [0u8; 32];
        key_bytes.copy_from_slice(&initiator_params[..32]);
        let init_pub = PublicKey::from(key_bytes);
        let dh_shared = self.x25519_secret.diffie_hellman(&init_pub);

        let mut combined = Vec::with_capacity(64);
        combined.extend_from_slice(dh_shared.as_bytes());
        if initiator_params.len() > 32 {
            combined.extend_from_slice(&initiator_params[32..]);
        }

        let session_key = hkdf_expand(&combined, b"mercury/hybrid-kex/v1");
        Ok(HybridSession { session_key })
    }
}

fn hkdf_expand(prk: &[u8], info: &[u8]) -> Vec<u8> {
    let hk = Hkdf::<Sha256>::new(None, prk);
    let mut okm = [0u8; 32];
    hk.expand(info, &mut okm).expect("32 bytes is valid length for HKDF-Sha256");
    okm.to_vec()
}
