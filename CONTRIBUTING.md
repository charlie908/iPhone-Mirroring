# Contributing

Thank you for helping improve PhoneView.

## Before opening a pull request

1. Choose the smallest project affected by the change.
2. Do not mix PhoneView, iPhone Direct, and iPhone Mac identifiers or Bonjour services.
3. Keep secrets, signing material, device identifiers, and private IP addresses out of commits.
4. Build every changed target without signing where possible.
5. Test real-device behavior when the change affects ReplayKit, Network.framework, VideoToolbox, or XCTest automation.
6. Update the relevant project README and version notes.

## Pull requests

Describe:

- the problem and intended behavior;
- affected devices and OS/Xcode versions;
- how the change was tested;
- latency, quality, or security trade-offs;
- screenshots or recordings, after removing private information.

By contributing, you agree that your contribution is licensed under Apache License 2.0 and that the repository's NOTICE attribution will be preserved.

## Priorities

- Authenticated and encrypted local transport.
- Friendly device discovery and configuration.
- Lower glass-to-glass latency and objective measurements.
- Robust reconnect and sleep/wake handling.
- Audio transport.
- Landscape and orientation changes.
- Automated builds and compatibility testing.

