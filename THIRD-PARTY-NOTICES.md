# Third-party notices

## DeviceKit iOS

- Source: https://github.com/mobile-next/devicekit-ios
- Pinned base revision used by the patches: `510d10e5e376221397cef7f8d7acb74603c61888`
- License: MIT
- Purpose: XCTest-based iPhone input and automation service.

The iPhone Mac tree includes its adapted DeviceKit source and the upstream MIT license. PhoneView and iPhone Direct provide patches against the pinned upstream revision.

## ios-web-streamer

- Source: https://github.com/himanshkukreja/ios-web-streamer
- Pinned base revision: `cfb1504638d3f9298704fb8f3ad9ebd06d60e148`
- Purpose: ReplayKit capture, Mac relay, browser viewer, and WebDriverAgent fallback used by PhoneView.

The inspected upstream revision did not contain an explicit license file. It is therefore not copied into this repository. `projects/phoneview/scripts/bootstrap.sh` downloads it directly from the author and applies the PhoneView patch. Confirm the upstream usage terms before distributing combined source or binaries.

## FlyingFox

- Source: https://github.com/swhitty/FlyingFox
- Resolved version: `0.22.0`
- Purpose: HTTP/WebSocket server used by DeviceKit.

The authoritative license is provided by the Swift package when resolved by Xcode.

## Apple SDKs

The code uses Apple SDK frameworks including SwiftUI, UIKit/AppKit, ReplayKit, Network, VideoToolbox, WebKit, and XCTest. Their use remains subject to Apple's applicable SDK and developer-program terms.

