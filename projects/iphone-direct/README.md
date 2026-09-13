# iPhone Direct

![iPhone Direct icon](../../assets/icons/iphone-direct.png)

**Version:** `0.1.0-alpha` (Xcode targets currently report version 1.0, build 1)  
**Status:** working experimental prototype  
**Runtime:** iPhone + Apple Vision Pro; no Mac relay

iPhone Direct sends the iPhone's ReplayKit H.264 stream straight to Apple Vision Pro and returns control commands over the same peer-to-peer connection. It is intended for travel and situations where a normal shared router is unavailable.

The prototype has been tested both on a normal local Wi-Fi network and with Apple Vision Pro connected to the iPhone's Personal Hotspot. In the latter setup, the Mac is not part of the runtime path.

## Features

- Native H.264 capture and decoding.
- Network.framework/Bonjour discovery using `_iphonedirect._tcp`.
- Peer-to-peer networking enabled.
- Tap, swipe, text, Home, Lock, and volume commands.
- Phone-style visionOS presentation inherited from PhoneView.
- Automatic video reconnect.
- Independent identifiers and services; it does not replace PhoneView.

## Dependencies

| Dependency | Purpose |
|---|---|
| Xcode + iOS/visionOS SDKs | Build and sign the two apps |
| ReplayKit | User-approved iPhone screen capture |
| VideoToolbox | H.264 encoding and decoding |
| Network.framework + Bonjour | Direct discovery and transport |
| DeviceKit iOS | XCTest-based input injection on port 12004 |
| FlyingFox 0.22.0 | DeviceKit's local HTTP/JSON-RPC server |

## Repository layout

```text
ios/                         iPhone app and ReplayKit extension
visionos/                    Native Apple Vision Pro viewer
devicekit-ios.patch          DeviceKit configuration used by this project
scripts/setup-devicekit.sh   Fetch and patch the pinned DeviceKit source
```

## Build setup

### 1. Signing identifiers

All project files contain safe placeholders. Replace `YOURTEAMID` with your Apple Developer team and replace the `com.example` identifiers with unique values you control.

For the iPhone targets, configure:

- main app bundle identifier;
- ReplayKit extension bundle identifier;
- one shared App Group in both entitlement files;
- the same App Group in `ios/Shared/Constants.swift`;
- the final extension identifier in `ios/BroadcastApp/ContentView.swift`.

For the visionOS target, set your team and unique bundle identifier in `visionos/project.yml` or directly in Xcode. If you edit the YAML file, regenerate with `xcodegen generate`.

### 2. DeviceKit

From this directory:

```bash
./scripts/setup-devicekit.sh
```

Open `Sources/devicekit-ios/devicekit-ios.xcodeproj`, select your development team, replace the placeholder identifiers, and build its host and UI-test targets for the iPhone.

DeviceKit runs as an XCTest service. Depending on the iOS/Xcode version, starting the UI test and then opening the DeviceKit host app once may be required. The iPhone Direct extension contacts it locally at `127.0.0.1:12004`.

### 3. Install both iPhone Direct apps

1. Build `ios/BroadcastApp.xcodeproj` on the iPhone.
2. Build `visionos/iPhoneDirectVision.xcodeproj` on Apple Vision Pro.
3. Accept Local Network access on both devices.

## Start a session

1. Connect Apple Vision Pro to the same Wi-Fi as the iPhone, or connect it to the iPhone's Personal Hotspot.
2. Start the DeviceKit UI test and open its iPhone host app if necessary.
3. Open iPhone Direct on Apple Vision Pro.
4. Open iPhone Direct on the iPhone.
5. Use the ReplayKit picker and explicitly confirm **Start Broadcast**.

The Mac may be disconnected after the development apps and test runner have been installed and started. iOS still requires a human confirmation for every new ReplayKit broadcast.

## Known limitations

- The iPhone must remain unlocked for reliable control.
- DeviceKit is a developer automation mechanism and may break across Xcode/iOS releases.
- Transport is unauthenticated and unencrypted at the application layer.
- DRM and protected surfaces may appear black.
- Audio is not currently transported.
- Reconnection after aggressive sleep or radio changes still needs broader testing.

See the root [Security policy](../../SECURITY.md) before use.

