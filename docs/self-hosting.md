# Mercury Zero-VPS & Serverless Deployment Guide

Mercury does not require running centralized servers or paying for cloud hosting. Every user node runs the lightweight native client and connects directly through Web4 P2P mechanisms.

---

## 1. Quick Start (No Docker, No VPS Needed)

### Step 1: Compile Native Rust Crypto Engine
```bash
cd core/crypto-engine
cargo build --release
```
- On Windows: The compiled `hermes_crypto.dll` is used directly by the Flutter engine.
- On Linux: Produces `libhermes_crypto.so`.
- On macOS: Produces `libhermes_crypto.dylib`.

### Step 2: Launch Mercury Client Node
```bash
cd apps/chat
flutter pub get

# Run on your desktop form factor:
flutter run -d windows
flutter run -d linux
flutter run -d macos
```

---

## 2. Peer Discovery Across Local Wi-Fi (0 Configuration)

When multiple devices (e.g., your Windows 11 Desktop and Wacom Studio or Linux laptop) share the same local Wi-Fi router or switch:
1. Mercury automatically sends encrypted discovery beacons to UDP multicast address `239.255.42.42:42424`.
2. Nearby nodes establish direct gigabit socket connections (~0.5ms round-trip latency) without accessing the external internet.

---

## 3. Remote Cellular & WAN Discovery (Kademlia DHT)

When devices are on different networks (e.g., your Moondrop MIAD01 phone on 5G cellular and your Desktop on home broadband):
1. Nodes look up each other's self-certifying `did:key` records on public decentralized Kademlia / Iroh DHT tables.
2. Direct STUN/UDP hole-punching creates an end-to-end encrypted P2P tunnel across consumer NAT firewalls.
3. If symmetric enterprise/carrier firewalls prevent direct hole punching, nodes seamlessly fail over to zero-knowledge Waku v2 / Iroh DERP encrypted packet relays.

---

## 4. Optional: Running a Community Waku Relay Node

If you want to contribute bandwidth to help friends route packets through symmetric firewalls or store offline mailboxes:
- Run a lightweight Waku v2 node (`docker run -d -p 8000:8000 wakuorg/nwaku:latest`) on any spare Raspberry Pi or mini PC.
- Add your relay node address in Mercury's **Web4 Network & P2P Mesh** modal.
- The relay never possesses encryption keys and only forwards opaque post-quantum ciphertext envelopes.
