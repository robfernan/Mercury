# Mercury

[![WIP](https://img.shields.io/badge/status-WIP-orange)](#status)

**Open-source zero-trust chat.** Interactive Flutter UI shell. E2EE local-first core in active development.

> **WIP.** Sync between devices may not be wired. Creating servers or guilds, inviting real users, and keeping state in sync across devices are still in progress.

<p align="center">
  <img src="screenshot.png" alt="Mercury client shell: channel list, seeded chat, and member sidebar" width="950" />
</p>

If you are following the work, a [star on GitHub](https://github.com/robfernan/Mercury) helps others find the repo.

---

## Status

| Area | Today |
| --- | --- |
| **UI shell** | Interactive Flutter client. You can move through channels, themes, wallpapers, the canvas, audio-room screens, fleet panels, and enclave-related screens. |
| **On-screen chat** | Seeded sample history inside the client. The screenshot above is that shell. |
| **E2EE local-first core** | Rust crate in `core/crypto-engine`, in active development. The app loads `hermes_crypto` when that library is present and uses a mock crypto engine when it is not. |
| **Device sync** | May not be wired. A local mesh client is in the tree. Live delivery between separate physical devices is unfinished. |

The Flutter project is one codebase with desktop, mobile, and web targets under `apps/chat` (Linux, Windows, macOS, Android, iOS, and web).

## Run the shell

### Prerequisites

- Flutter 3.47.x (Dart 3.13), matching `apps/chat/pubspec.yaml`
- A desktop device target, or a mobile target you have already configured
- Rust stable, only if you want to compile the crypto crate

Windows desktop builds need Visual Studio 2022 or newer with the **Desktop development with C++** workload, and Developer Mode so Flutter can create symlinks.

### 1. Crypto crate (optional)

The UI shell runs when this library is absent.

```bash
cd core/crypto-engine
cargo build --release
```

### 2. Flutter app

```bash
cd apps/chat
flutter pub get
flutter run -d linux
```

Use `flutter run -d windows` or `flutter run -d macos` for those desktops. Launching the shell on two machines is a UI check. Sync between devices may not be wired.

## Repository layout

```
.
├── apps/chat/                 # Flutter UI shell
├── core/crypto-engine/        # Rust E2EE core (active development)
├── docs/                      # Design notes
├── packages/shared-schema/    # OpenAPI sketch
├── screenshot.png
└── README.md
```

## Design notes

Longer write-ups live next to the code:

- [Architecture](docs/architecture.md)
- [Security model](docs/security.md)
- [Self-hosting notes](docs/self-hosting.md)
- [API sketch](packages/shared-schema/openapi.yaml)

Those pages describe the intended local-first design: ciphertext on participant devices, a Flutter client, and a Rust core for identity and message protection. Timing lines and product comparisons in those notes are **design targets**. This repository has not published measurements for them. Status of the public tree is the table in [Status](#status).

## License

MIT. See [LICENSE](LICENSE).
