# Mercury Security Model

Mercury is **zero-trust and serverless by default**: no central server stores your cleartext, keys, or metadata; identity is hardware-bound; every message is cryptographically signed; and group messaging uses hybrid post-quantum MLS.

---

## 1. Identity & Hardware-Bound Sovereignty

- **W3C DIDs (`did:key`)**: Each user's identity is a self-sovereign cryptographic keypair encoded as a `did:key`, with zero dependence on phone numbers, email addresses, or central registries.
- **Hardware Enclave Key Isolation**: Cryptographic seeds are generated and isolated inside host platform hardware coprocessors:
  - Windows: TPM 2.0 & Windows Hello via DPAPI
  - Android: StrongBox Keymaster / Hardware TEE
  - Linux: Secret Service API & Kernel Keyring
  - macOS/iOS: Apple Secure Enclave
- **Noise-IK Device Cross-Signing**: Adding a new device to your fleet (phone, drawing tablet, laptop) uses an ephemeral one-scan QR code handshake, mutually authenticating devices without password entry.

---

## 2. End-to-End Cryptography Architecture

| Communication Channel | Cryptographic Primitive & Standard |
| :--- | :--- |
| **Direct DMs (1:1)** | **Double Ratchet (Signal Protocol)**: Ephemeral Diffie-Hellman ratcheting for forward secrecy and post-compromise self-healing. |
| **Channels & Group Rooms** | **Hybrid Post-Quantum MLS (RFC 9420)**: `ML-KEM-768` (NIST FIPS 203) combined with `X25519` defending against "harvest-now-decrypt-later" quantum attacks. |
| **Message Authenticity** | **Ed25519 Signatures**: Every message, reaction, and canvas stroke is digitally signed; peer clients verify authenticity locally in `<1ms`. |
| **Symmetric Encryption** | **XChaCha20-Poly1305**: Authenticated AEAD with 192-bit nonces, immune to nonce-reuse vulnerabilities. |

---

## 3. Physical Device Defense & Zero-Knowledge Storage

- **Zero-Knowledge SQLite FTS5**: All chat history and media are indexed client-side using SQLite Full-Text Search (FTS5). Search queries never touch any network or relay interface.
- **Plausible Deniability & Decoy Vaults**: Multi-derivation cryptographic PINs allow loading a plausible decoy history while keeping sensitive conversation trees cryptographically hidden.
- **Volatile Memory Sanitization**: Native Rust hooks zero out active in-memory session keys in under 5ms upon OS lock or hotkey trigger.

---

## 4. Threat Model Summary

| Threat Vector | Mercury Web4 Mitigation |
| :--- | :--- |
| **Third-Party Relay Snooping** | All envelopes are encrypted with hybrid post-quantum MLS; relays only see opaque bytes. |
| **Harvest Now, Decrypt Later** | ML-KEM-768 (Kyber) quantum-resistant key encapsulation layered with X25519. |
| **Packet Spoofing & Replay** | Ed25519 digital signatures and strict monotonic logical clocks (HLC). |
| **ISP / Carrier Traffic Analysis** | Sphinx packet formatting and variable cover traffic over Waku/Iroh mesh routes. |
| **Compelled Device Inspection** | Hardware-attested plausible deniability vault with secondary decoy PIN. |
| **Cross-Device Desynchronization** | CRDT convergence — zero data loss across offline and multi-device sessions. |
