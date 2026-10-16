# Mercury Web4 Architecture (Pure Zero-VPS P2P Standard)

This document describes the runtime data flow, decentralized transport tiers, and native Rust cryptography that power **Mercury** — an open-source, serverless, zero-trust real-time chat platform.

---

## 1. Zero-VPS Peer-to-Peer Paradigm

Mercury does not require running Docker containers, Kubernetes clusters, PostgreSQL instances, or paid cloud VPS nodes. Every client device acts as an autonomous, self-sovereign cryptographic node.

| Subsystem | Pure Web4 Approach | Traditional Matrix / Discord Approach |
| :--- | :--- | :--- |
| **Transport** | Direct P2P over QUIC/UDP (mDNS on LAN, STUN/DERP over WAN/5G) | Centralized WebSockets or heavy HTTP homeservers |
| **Relay & Mailbox** | Ephemeral Waku v2 / Iroh Gossip Relays (30-day encrypted cache) | Persistent server-side PostgreSQL databases |
| **Discovery** | Kademlia / Iroh Distributed Hash Table (DHT) keyed by `did:key` | Centralized account authentication servers |
| **Storage** | Client-side encrypted SQLite with FTS5 search index via Drift | Server-side cleartext or encrypted server archives |
| **Key Isolation** | OS Hardware Enclaves (TPM 2.0 / StrongBox / Apple Secure Enclave) | Browser memory / user-space files |

---

## 2. Multi-Tiered Dynamic Transport Router

When sending an encrypted message envelope, Mercury selects the lowest latency, zero-trust transport route dynamically:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                     Dynamic Web4 Transport Selection Engine                     │
│                                                                                 │
│   [Attempt 1: Local LAN]                                                        │
│   UDP Multicast / mDNS beacon (239.255.42.42:42424)                             │
│   ➜ Direct gigabit socket transfer (~0.5ms latency, 0 external hops)            │
│                              │                                                  │
│                              ▼ (If not on same local Wi-Fi)                     │
│   [Attempt 2: Direct WAN P2P]                                                   │
│   Kademlia DHT Lookup + STUN UDP Hole-Punching                                  │
│   ➜ Direct peer-to-peer connection across cellular 5G / broadband (~18ms)       │
│                              │                                                  │
│                              ▼ (If symmetric firewall / enterprise NAT blocks)  │
│   [Attempt 3: Encrypted Relay Fallback]                                         │
│   Decentralized Iroh DERP / Waku v2 Relay                                       │
│   ➜ Zero-knowledge encrypted packet forwarder (~48ms)                           │
│                              │                                                  │
│                              ▼ (If recipient device is powered off / offline)   │
│   [Attempt 4: Store-and-Forward Mailbox]                                        │
│   30-Day Ephemeral Decentralized Gossip Cache                                   │
│   ➜ Recipient syncs down immediately upon waking up                             │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Cryptographic Core (`hermes_crypto`)

All cryptography runs in compiled native Rust via C-ABI / FFI:
- **Group Encryption**: Hybrid Post-Quantum MLS (RFC 9420 compliant) pairing `ML-KEM-768` (FIPS 203) with `X25519` for quantum harvest-now-decrypt-later defense.
- **Direct 1:1 Messages**: Double Ratchet with per-message ephemeral Diffie-Hellman keys.
- **Signatures & Identity**: Hardware-derived `Ed25519` keypairs providing sub-1ms message authenticity verification.
- **Device Enrollment**: Noise-IK mutual cross-signing using ephemeral one-scan QR codes.

---

## 4. Local-First CRDT Sync Engine

Mercury stores all decrypted history in **Drift (SQLite)** coupled with an offline-first **CRDT (Conflict-free Replicated Data Type)** mutation log:
- **Hybrid Logical Clocks (HLC)**: Every edit, deletion, or reaction is timestamped with an HLC to ensure deterministic convergence.
- **Zero Data Loss**: Edits created while offline (e.g., on a flight) merge seamlessly into the peer network upon reconnecting without server conflicts.
- **Zero-Knowledge Search**: Full-text search queries execute exclusively on-device via SQLite **FTS5**. Search queries never touch any network interface.

---

## 5. Mobile & Hardware Optimizations

- **Dynamic SuperNode Coordination**: High-bandwidth, plugged-in workstations (e.g. Windows 11 Desktop) automatically assist low-power mobile nodes by multiplexing group streams.
- **Audiophile Direct DAC Bypass**: Native audio streaming tailored for the **Moondrop MIAD01 dual Cirrus Logic CS43131 DACs**, pushing 510kbps full-band Opus stereo over 4.4mm balanced output.
- **Wacom MobileStudio Live Canvas**: Real-time collaborative vector drawing capturing 8,192 levels of EMR pen pressure with sub-20ms latency.
- **UnifiedPush Background Battery Protection**: Uses decentralized sealed pings to wake sleeping mobile devices without draining battery or running permanent background UDP loops.
