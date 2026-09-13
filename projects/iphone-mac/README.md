# iPhone Mac

![iPhone Mac icon](../../assets/icons/iphone-mac.png)

**Version:** `0.1.0-alpha` (Xcode targets currently report version 1.0, build 1)  
**Status:** working experimental prototype  
**Runtime:** iPhone + Mac

iPhone Mac is a native macOS viewer and controller inspired by the workflow of Apple's iPhone Mirroring feature. It was created in part for developers and users in regions where Apple's implementation is unavailable.

It is independent from PhoneView and iPhone Direct. The Mac receives and decodes the ReplayKit H.264 stream directly, while mouse, trackpad, and keyboard actions are translated into iPhone input through a dedicated DeviceKit/XCTest runner.

## Features

- Borderless, transparent, movable, and proportionally resizable Mac window.
- iPhone-style shell with a compact Home control.
- Native low-latency H.264 decoding.
- Click to tap and click-and-drag to swipe.
- Click-and-hold for long press.
- Mouse wheel and trackpad scrolling.
- Horizontal two-finger gestures and Shift-scroll navigation.
- Batched Mac keyboard input.
- `⌘1` Home, `⌘2` App Switcher, and `⌘3` iPhone Spotlight.
- `⌘+`, `⌘0`, and `⌘−` window sizing commands.
- iPhone keep-awake during an active stream.
- Bonjour service `_iphonemac._tcp` and separate DeviceKit port 12005.

## Dependencies

| Dependency | Purpose |
|---|---|
| Xcode + iOS/macOS SDKs | Build and sign the apps and test runner |
| ReplayKit | User-approved iPhone capture |
| VideoToolbox | H.264 encoding/decoding |
| Network.framework + Bonjour | iPhone/Mac discovery and transport |
| AppKit + SwiftUI | Native Mac window and controls |
| DeviceKit iOS | XCTest input injection, bundled with the Mac project |
| FlyingFox 0.22.0 | DeviceKit HTTP/JSON-RPC service |

## Repository layout

```text
ios/       iPhone companion app and ReplayKit extension
macos/     Native Mac viewer plus bundled DeviceKit control project
```

## Build setup

### 1. Configure identifiers and signing

Replace every `YOURTEAMID` and `com.example` placeholder with values owned by your Apple Developer account.

For the iPhone project, configure the main app, ReplayKit extension, shared App Group entitlements, the App Group constant, and the preferred extension identifier.

For the Mac and bundled DeviceKit projects, configure unique bundle identifiers and your development team. Preserve port `12005` if you want iPhone Mac to coexist with PhoneView/iPhone Direct.

### 2. Configure the development iPhone

The initial prototype's automatic launcher needs two identifiers in `macos/iPhoneMac/DeviceKitLauncher.swift`:

- `YOUR_IPHONE_DESTINATION_ID`: the destination identifier accepted by `xcodebuild`.
- `YOUR_IPHONE_CORE_DEVICE_ID`: the CoreDevice identifier accepted by `xcrun devicectl`.

Discover connected development devices with:

```bash
xcrun xctrace list devices
xcrun devicectl list devices
```

Also update the iPhone companion bundle identifier used by `launchCompanionApp` in the same Swift file.

### 3. Build

1. Open `ios/BroadcastApp.xcodeproj`, configure signing, and install the companion app on the iPhone.
2. Open `macos/iPhoneMac.xcodeproj`, configure signing, and build the Mac app.
3. If you edit `macos/project.yml`, run `xcodegen generate` before rebuilding.

The Mac target embeds the `iPhoneMacControl` source folder as a resource so it can launch its dedicated XCTest runner. Xcode must remain installed at the path configured in `DeviceKitLauncher.swift` (the prototype currently references `/Applications/Xcode-beta.app`).

## Start a session

1. Unlock and pair the iPhone with the Mac.
2. Open iPhone Mac on the Mac.
3. The Mac app attempts to start its dedicated DeviceKit runner and open the iPhone companion.
4. On the iPhone, explicitly confirm **Start Broadcast** in the ReplayKit system sheet.

The ReplayKit confirmation cannot be automated by a normal third-party app.

## Comparison with Apple's iPhone Mirroring

| Capability | iPhone Mac |
|---|---|
| Click, long press, swipe, and scroll | Yes |
| Mac keyboard input | Yes |
| Home, App Switcher, and iPhone Spotlight shortcuts | Yes |
| Movable/resizable iPhone window | Yes |
| Game controller connected directly to iPhone | Compatible with the normal iPhone path |
| iPhone audio on Mac | Not yet implemented |
| Automatic landscape shell rotation | Not finished |
| Native cross-device drag and drop | Not available through public third-party APIs |
| Mirrored system notifications in macOS | Not available through public third-party APIs |
| Control while iPhone remains locked | No—XCTest requires an unlocked device |
| Apple's private Continuity trust/history features | No |

## Known limitations

- The automatic control launcher currently requires developer-specific IDs to be entered in source.
- Xcode and Developer Mode are required.
- The iPhone must remain unlocked.
- Audio is not transported.
- Protected/DRM video may appear black.
- The local protocol has no application-level authentication or encryption.

See the root [Security policy](../../SECURITY.md) before use.

