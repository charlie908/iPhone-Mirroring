# PhoneView Developer Kit

PhoneView is an experimental iPhone screen-mirroring and remote-control prototype for Apple Vision Pro. It streams the iPhone display over the local network, renders low-latency H.264 video in a native visionOS app, and forwards taps, swipes, text, Home, Lock, and volume commands back to the iPhone.

This archive contains **PhoneView only**. It does not include the separate iPhone Direct or iPhone Mac projects.

## What is included

- `visionos/` — the native SwiftUI visionOS viewer and its PhoneView interface.
- `patches/ios-web-streamer.patch` — the iPhone ReplayKit app plus the customized Mac relay/control server.
- `patches/devicekit-ios.patch` — the DeviceKit changes required for fast control over the LAN.
- `scripts/bootstrap.sh` — downloads the pinned upstream projects and applies the PhoneView patches.
- `scripts/setup-mac.sh` — creates the Python environment for the Mac relay.
- `scripts/start-server.sh` — starts the Mac relay against an iPhone IP address.
- `scripts/run-devicekit.sh` — launches the DeviceKit UI-test control service on a connected iPhone.

No compiled application, provisioning profile, certificate, device identifier, personal path, or private LAN address is included. Every developer must build and sign the apps with their own Apple Developer team.

## Architecture

```text
iPhone PhoneView app
  ReplayKit broadcast extension
  H.264 over WebSocket :8765
              |
              v
Mac relay (Python) :8999  <---->  DeviceKit on iPhone :12004
              |
              | native H.264 WebSocket + HTTP control
              v
Apple Vision Pro PhoneView app
```

WebDriverAgent remains available as a fallback in the inherited server code, but the tested PhoneView path prefers DeviceKit because it is more responsive.

## Requirements

- A Mac with Xcode capable of building the iOS and visionOS deployment targets in the projects. This snapshot targets iOS 16+ and visionOS 27.0; lower the visionOS deployment target if your toolchain and APIs allow it.
- Xcode command-line tools.
- Python 3.10 or newer.
- Git.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) only if you want to regenerate the included visionOS Xcode project.
- An iPhone and Apple Vision Pro with Developer Mode enabled.
- Your own Apple Developer signing team.
- The Mac, iPhone, and Vision Pro on the same trusted local network.

The prototype exposes unauthenticated development services on the LAN. Do not run it on an untrusted network and do not forward ports 8765, 8999, or 12004 to the internet.

## 1. Expand the upstream sources

From the root of this kit:

```bash
./scripts/bootstrap.sh
```

This creates:

```text
Sources/ios-web-streamer
Sources/devicekit-ios
```

The script checks out the exact upstream commits used for this prototype and applies the included patches. It refuses to overwrite an existing `Sources` directory.

## 2. Configure signing and identifiers

The archive deliberately uses placeholder identifiers beginning with `com.example`. Replace them with unique identifiers owned by your team.

### iPhone PhoneView app

Open:

```text
Sources/ios-web-streamer/ios-app/BroadcastApp/BroadcastApp.xcodeproj
```

For both the `BroadcastApp` and `BroadcastExtension` targets:

1. Select your Apple Developer team.
2. Set unique bundle identifiers, for example `com.yourcompany.phoneview` and `com.yourcompany.phoneview.extension`.
3. Create one App Group, for example `group.com.yourcompany.phoneview`.
4. Put that same App Group in both entitlement files.
5. Update `Constants.appGroupIdentifier` in `Shared/Constants.swift`.
6. Update `picker.preferredExtension` in `BroadcastApp/ContentView.swift` to the extension bundle identifier.

The server host is editable inside the iPhone app. Enter the Mac's local IP address there; the default placeholder is `192.168.1.100`. Keep port `8765`.

### DeviceKit

Open:

```text
Sources/devicekit-ios/devicekit-ios.xcodeproj
```

Select your team for the app and UI-test targets and replace the `com.example.phoneview.devicekit` identifiers with unique values.

### visionOS PhoneView app

Edit `visionos/project.yml`:

1. Replace the `com.example` prefix and bundle identifier.
2. Add your `DEVELOPMENT_TEAM` value, or select the team later in Xcode.
3. If necessary, adjust the visionOS deployment target.

Open the included project:

```bash
cd visionos
open PhoneViewVision.xcodeproj
```

After changing `project.yml`, regenerate it with `xcodegen generate` before opening it.

Build and install it on Apple Vision Pro. The Mac server address can be changed from PhoneView's connection panel; the source contains only a placeholder address.

## 3. Prepare and start the Mac relay

Run once:

```bash
./scripts/setup-mac.sh
```

Then start the relay with the iPhone's local IP address:

```bash
./scripts/start-server.sh 192.168.1.123
```

The server should report:

- iPhone video receiver on WebSocket port `8765`.
- viewer and control API on HTTP/WebSocket port `8999`.
- DeviceKit connected on the iPhone at port `12004`, once its test runner is active.

You can check the relay locally at `http://127.0.0.1:8999/health`.

## 4. Start DeviceKit control

Connect the iPhone to the Mac for the initial development pairing and discover its Xcode destination identifier:

```bash
xcrun xctrace list devices
```

Launch the control test, replacing the sample identifier:

```bash
./scripts/run-devicekit.sh YOUR_IPHONE_DESTINATION_ID
```

Keep this test running. On some versions of iOS, opening the DeviceKit host app on the iPhone once is necessary before the control service becomes reachable. Confirm it from the Mac with:

```bash
curl http://IPHONE_IP:12004/health
```

The expected response is `OK`.

## 5. Start a PhoneView session

1. Start the DeviceKit runner and Mac relay.
2. Open PhoneView on the iPhone.
3. Confirm the Mac IP and port `8765`.
4. Tap the ReplayKit broadcast picker, select PhoneView, and explicitly start the broadcast. Apple requires this confirmation; an app cannot silently begin full-screen capture.
5. Open PhoneView on Apple Vision Pro.
6. Enter the Mac IP in the connection panel if needed.
7. Wait for both video and control indicators to become active.

While a broadcast and DeviceKit control session are connected, the relay periodically prevents iPhone auto-lock. Regular user interaction also refreshes the idle timer.

## Controls on Apple Vision Pro

- Look at the phone display and pinch to tap.
- Pinch and drag to swipe.
- Use the text control for keyboard input.
- Use `Home` below the phone to return to the Home Screen.
- The side/top control areas can be hidden and shown by pinching around the phone shell.

## Troubleshooting

### Video is black

- Confirm the ReplayKit broadcast is still active on the iPhone.
- Confirm the iPhone app contains the correct Mac IP.
- Allow Local Network access for PhoneView.
- Verify the Mac firewall permits incoming connections to the Python process.
- Stop and restart the ReplayKit broadcast after restarting the Mac relay.
- Protected/DRM video may intentionally appear black.

### Video works but controls do not

- Verify `curl http://IPHONE_IP:12004/health` returns `OK`.
- Keep the DeviceKit UI test running in Xcode or through `run-devicekit.sh`.
- Unlock the iPhone.
- Restart the Mac relay after DeviceKit becomes available; the current server selects its control backend at startup.

### The Vision Pro cannot connect

- Confirm all three devices are on the same network and client isolation is disabled.
- Use the Mac's LAN address, not `127.0.0.1` or `localhost`.
- Verify `http://MAC_IP:8999/health` from another device on the LAN.

### High latency or macroblocking

- Prefer a clean 5 GHz/6 GHz Wi-Fi channel or an iPhone Personal Hotspot link when appropriate.
- Keep all devices close to the access point.
- The included encoder profile targets 60 fps and 10 Mbps. Lower the bitrate if the network cannot sustain it; raise it cautiously for cleaner motion.

## Important limitations

- This is a developer prototype, not an App Store-ready product.
- Device control relies on XCTest/DeviceKit automation and requires a development-signed test runner. Apple may change or restrict this behavior in future OS/Xcode releases.
- ReplayKit always requires a user-confirmed broadcast start.
- The iPhone generally needs to remain unlocked for reliable interaction.
- There is no authentication or encryption on the local control endpoints.
- System dialogs, secure fields, DRM content, and some protected surfaces may not be controllable or visible.

## Provenance and licensing

See `THIRD-PARTY-NOTICES.md` before redistributing this kit. In particular, the referenced `ios-web-streamer` snapshot does not contain an explicit license file, so this archive ships only a PhoneView patch and a bootstrap script; recipients obtain the upstream source directly from its author.
