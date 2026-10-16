//! Double Ratchet session definitions.

use crate::HermesError;

#[derive(Debug, Clone, uniffi::Record)]
pub struct RatchetState {
    pub root_key: Vec<u8>,
    pub send_chain_key: Vec<u8>,
    pub recv_chain_key: Vec<u8>,
    pub send_count: u32,
    pub recv_count: u32,
}

impl RatchetState {
    pub fn initialize(shared_secret: Vec<u8>) -> Self {
        Self {
            root_key: shared_secret.clone(),
            send_chain_key: shared_secret.clone(),
            recv_chain_key: shared_secret,
            send_count: 0,
            recv_count: 0,
        }
    }

    pub fn ratchet_encrypt(&mut self, plaintext: &[u8]) -> Result<Vec<u8>, HermesError> {
        self.send_count += 1;
        // In real ratchet, step KDF and encrypt with ChaCha20Poly1305
        Ok(plaintext.to_vec())
    }

    pub fn ratchet_decrypt(&mut self, ciphertext: &[u8]) -> Result<Vec<u8>, HermesError> {
        self.recv_count += 1;
        Ok(ciphertext.to_vec())
    }
}
