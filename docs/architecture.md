# Hermes Architecture

This document describes the runtime data flow, service boundaries and the shared Rust crypto core. It is the source of truth for how a message travels from one client to another.

## 1. Service topology

Hermes runs **two independent Go services** that share PostgreSQL but scale independently:

| Service | Responsibility | Transport |
| --- | --- | --- |
| `api` | REST logic, auth (passkeys/JWT), file presigning, channel membership, rate limiting | HTTP/1.1 + HTTP/2 (`chi`) |
| `gateway` | Real-time bidirectional streams, presence, sequence numbers, gap-fill | WebTransport over QUIC/UDP (+ HTTP fallback) |

Both connect to PostgreSQL 17 via **independent connection pools** (pgx). They coordinate through **Redis 8 Pub/Sub**, never by calling each other.

## 2. Message delivery path (<50ms p99)

```
Client A posts message
   │  1. encrypt locally (Double Ratchet / MLS), sign with Ed25519
   ▼
api: POST /v1/channels/{id}/messages
   │  2. verify JWT + rate limit, insert row (channel_id, seq = last+1) in Postgres
   │  3. PUBLISH redis channel "server:{serverId}:channel:{channelId}"
   ▼
gateway (all instances subscribe to that channel)
   │  4. push frame over the client's WebTransport stream
   ▼
Client B receives, verifies Ed25519 signature (<1ms), decrypts, appends at seq
```

**Why this is fast:** the hot path is a single Postgres insert + one Redis publish + one QUIC datagram. There is no TCP head-of-line blocking because WebTransport rides on UDP/QUIC with independent streams — a lossy or reordered stream never stalls others during network drops or cellular handoff.

## 3. Ordering, sequence numbers & gap-fill

Every channel has a **strictly increasing integer `seq`** assigned by the API at insert time (single writer per channel via Postgres). This gives total ordering without client clocks.

On reconnect:
1. Client sends its last-acked `seq`.
2. Gateway/API returns all messages with `seq > N` for that channel.
3. Client applies them in order, then resumes the live stream.

This makes reconnection an O(gap) patch rather than a full resync.

## 4. Local-first CRDT sync engine

The client stores decrypted history in **Drift/SQLite** with embedded **CRDT state**. Consequences:

- **Zero data loss across devices**: each device is a peer; merges are commutative, associative and idempotent (Lamport timestamps + per-field LWW registers for editable metadata).
- **Offline→online merge**: edits made offline converge to the same state as online edits once connectivity returns — no "last write wins by server" surprises.
- The CRDT reconciliation math lives in the Rust core so it is bit-identical on every platform.

## 5. Zero-knowledge client-side search

Full-text search runs **locally** against the decrypted SQLite history using **FTS5**. The query never leaves the device, and the server holds no inverted index — preserving total E2EE privacy. Drift exposes FTS5 via `.drift` files + `package:drift/extensions/fts5.dart`.

## 6. Zero-knowledge file uploads

```
client → api: POST /v1/files (metadata)          → presigned PUT URL returned
client → MinIO/R2: PUT object (direct, >5GB multipart supported)
client → api: POST /v1/files/{id}/complete       → row finalized, seq assigned in channel
```

The server **never proxies bytes**. It only signs the upload and records metadata. Objects are encrypted client-side before upload where E2EE applies.

## 7. Mesh-based local fallback

When global internet drops, nearby devices discover each other over **Bluetooth / mDNS** and sync chat data peer-to-peer over an **encrypted local mesh**. The same CRDT engine that reconciles server↔client also reconciles device↔device, so a mesh merge is just another convergent apply.

## 8. Rust crypto core (uniffi)

One Rust library, compiled once and bound natively into Dart (Flutter), Kotlin and Swift via **uniffi**. It owns:

- Double Ratchet (DMs)
- Hybrid post-quantum MLS tree math (groups/calls): ML-KEM + X25519
- Ed25519 signing/verification
- CRDT state reconciliation
- SQLite FTS5 full-text search helpers

Keeping this in Rust guarantees identical crypto behavior and performance across all six platforms, with no JS/WASM drift.

## 9. Media (LiveKit)

`services/media` wraps a self-hosted **LiveKit Server** for voice/video/screen-share and recording orchestration. Group calls use the same hybrid PQ-MLS keys to enable LiveKit E2EE, so media is protected end-to-end as well.
