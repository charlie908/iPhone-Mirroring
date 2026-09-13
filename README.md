<div align="center">
  <img src="assets/icons/phoneview.png" width="112" alt="PhoneView icon">
  <h1>PhoneView</h1>
  <p><strong>Experimental iPhone mirroring and control for Apple Vision Pro and Mac.</strong></p>
  <p>
    <img alt="Status: Experimental" src="https://img.shields.io/badge/status-experimental-orange">
    <img alt="Platforms" src="https://img.shields.io/badge/platforms-iOS%20%7C%20visionOS%20%7C%20macOS-black">
    <img alt="License" src="https://img.shields.io/badge/license-Apache--2.0-blue">
  </p>
</div>

PhoneView is an open-source collection of three related prototypes for viewing and controlling an iPhone without having to hold it. Each project addresses a different environment: a bridged Vision Pro setup, a direct Vision Pro connection, or a native Mac window.

The projects use ReplayKit for user-approved screen capture, hardware H.264 encoding/decoding for low latency, and XCTest/DeviceKit automation for input injection. They are developer tools, not App Store-ready applications.

> [!IMPORTANT]
> You must build and sign every Apple-platform target with your own Apple Developer account. No certificates, provisioning profiles, device identifiers, or personal network addresses are included.

## Choose a project

| | Project | Runtime path | Best for | Mac required while using it? |
|---|---|---|---|---|
| <img src="assets/icons/phoneview.png" width="56" alt="PhoneView"> | **[PhoneView](projects/phoneview/README.md)** | iPhone → Mac relay → Vision Pro | Stable local-network use with the full Vision Pro interface | Yes |
| <img src="assets/icons/iphone-direct.png" width="56" alt="iPhone Direct"> | **[iPhone Direct](projects/iphone-direct/README.md)** | iPhone ↔ Vision Pro | Travel, Personal Hotspot, or peer-to-peer use | No, after building/installing |
| <img src="assets/icons/iphone-mac.png" width="56" alt="iPhone Mac"> | **[iPhone Mac](projects/iphone-mac/README.md)** | iPhone ↔ Mac | Mac-based mirroring and control, including regions where Apple's iPhone Mirroring is unavailable | Yes—the Mac is the viewer |

All three projects are deliberately separate. Their app identifiers, ReplayKit extensions, Bonjour services, and control services do not need to replace one another.

## Current versions

| Project | Version | Status | Tested capabilities |
|---|---:|---|---|
| PhoneView | `0.1.0-alpha` | Working prototype | H.264 video, tap, swipe, text, Home, Lock, volume, focus UI, keep-awake |
| iPhone Direct | `0.1.0-alpha` | Working prototype | Peer-to-peer video and controls, Wi-Fi and iPhone Personal Hotspot |
| iPhone Mac | `0.1.0-alpha` | Working prototype | Native Mac window, mouse/trackpad gestures, keyboard, resize/move, shortcuts |

The repository uses an `0.1.0-alpha` release label; individual Xcode targets currently retain their original `1.0`/build `1` metadata. These snapshots work in the original development setup, but installation is still manual and OS/Xcode updates may require changes.

## Shared requirements

- A Mac with a recent Xcode version that supports the deployment targets.
- Xcode command-line tools.
- An Apple Developer account for local signing.
- Developer Mode enabled on the iPhone and Apple Vision Pro.
- The iPhone paired with the development Mac for XCTest/DeviceKit installation.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) when regenerating projects from `project.yml`.
- Python 3.10+ for PhoneView's Mac relay only.

Current project settings target iOS 15/16+, macOS 15.0, and visionOS 27.0 depending on the component. Developers may lower deployment targets where the APIs allow it.

## How it works

```text
                              ┌─────────────────────────┐
                              │ Apple Vision Pro        │
                    H.264 ───▶│ PhoneView / Direct      │
                    input ◀───│ native viewer           │
                              └─────────────────────────┘
                                ▲                 ▲
                                │ Mac relay       │ peer-to-peer
                                │ (PhoneView)     │ (iPhone Direct)
                                ▼                 ▼
┌─────────────────────────┐   H.264/input   ┌─────────────────────────┐
│ Mac                     │◀───────────────▶│ iPhone                  │
│ iPhone Mac native app   │                 │ ReplayKit + DeviceKit   │
└─────────────────────────┘                 └─────────────────────────┘
```

See [Architecture](docs/ARCHITECTURE.md) for protocols, ports, and component boundaries.

## Safety and privacy

- Screen capture never starts silently. iOS always displays the ReplayKit confirmation UI.
- The prototypes can expose unauthenticated video/control services on the local network.
- Use them only on a trusted network. Never forward their ports to the public internet.
- The repositories contain source and assets only—no signed application bundles.
- Secure or DRM-protected content may appear black, and some protected UI cannot be automated.

Please read [SECURITY.md](SECURITY.md) before running or modifying the projects.

## Repository layout

```text
assets/                     Shared icons used by this README
docs/                       Architecture and project notes
projects/phoneview/         iPhone + Mac relay + visionOS viewer
projects/iphone-direct/     Direct iPhone + visionOS pair
projects/iphone-mac/        iPhone + native macOS pair
.github/                    Issue and pull-request templates
```

## Contributions

Contributions are welcome. Useful areas include easier device discovery, authenticated transport, automatic configuration, audio, landscape handling, latency measurement, reconnect behavior, and clearer installation tooling.

Please read [CONTRIBUTING.md](CONTRIBUTING.md). If you distribute a modified or integrated solution, retain the attribution in [NOTICE](NOTICE), as required by the Apache 2.0 licensing terms for this repository's original work.

## Credits and third-party work

PhoneView was originally developed by **Charles Millet**. See [NOTICE](NOTICE) and [Third-party notices](THIRD-PARTY-NOTICES.md).

The projects build on open development tools including DeviceKit and, for the bridged PhoneView variant, modifications to `ios-web-streamer`. Because the referenced `ios-web-streamer` snapshot does not include an explicit license, this repository provides a patch and bootstrap instructions rather than copying its upstream source.

## Disclaimer

This project is independent, experimental, and not affiliated with or endorsed by Apple Inc. Apple, iPhone, Mac, Apple Vision Pro, iOS, macOS, visionOS, ReplayKit, and Xcode are trademarks of Apple Inc.
