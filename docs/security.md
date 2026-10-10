# Hermes Security Model

Hermes is **zero-trust by default**: the server stores ciphertext and metadata, never plaintext; identity is hardware-bound; every message is signed; and group messaging is post-quantum hybrid.

## 1. Identity & authentication

- **W3C DIDs (`did:key`)**: each user's public key is encoded as a `did:key`, giving a self-sovereign, verifiable identifier with no central registry.
- **Passkeys (WebAuthn)**: passwordless login backed by Apple Secure Enclave, Android StrongBox or TPM 2.0. The private key never leaves the device and cannot be exported.
- **JWT RS256**: asymmetric signing. Access tokens carry a `jti` claim checked against a **Redis denylist** for instantaneous revocation (logout / password change / anomaly).

## 2. Password hashing

Where a secret is stored server-side, it uses **Argon2id** (`golang.org/x/crypto/argon2`) with memory-hard parameters tuned to resist GPU/ASIC attacks.

## 3. End-to-end encryption

| Context | Scheme |
| --- | --- |
| Direct messages (1:1) | **Double Ratchet** — forward secrecy + post-compromise security |
| Groups & calls | **Hybrid post-quantum MLS** — Messaging Layer Security with ML-KEM + X25519 key exchange |

The hybrid PQ construction defends against **"harvest now, decrypt later"**: an attacker capturing today's ciphertext cannot break it after a quantum computer exists, because the ML-KEM component resists Shor-style attacks.

## 4. Message integrity

Every message is **signed with the sender's Ed25519 private key**. Receivers verify signatures locally in **<1ms** before rendering — so a tampered or replayed frame is rejected even if it arrived over a trusted transport.

## 5. Token denylists & rate limiting

- RS256 JWTs include `jti`; revocation = add to Redis denylist (O(1) check on the hot path).
- Rate limits: **100 msg/min per user**, plus per-channel and per-IP caps, enforced at the API edge.

## 6. Threat model summary

| Threat | Mitigation |
| --- | --- |
| Server compromise (at rest) | Ciphertext in Postgres/MinIO; keys on device |
| Harvest now / decrypt later | Hybrid PQ MLS (ML-KEM + X25519) |
| Malicious gateway replay/tamper | Ed25519 signatures + strict per-channel `seq` ordering |
| Token theft after logout | Redis `jti` denylist, instant revocation |
| Brute-force / credential stuffing | Passkeys (no password), Argon2id fallback, rate limits |
| Cross-device desync | CRDT convergence — no data loss on merge |
| Search leakage to server | Zero-knowledge local FTS5 search |

## 7. Reproducible builds

Docker images are built with pinned toolchains and a fixed `SOURCE_DATE_EPOCH`, producing **bit-identical** outputs across machines so auditors can verify the exact bytes that run in production.
