# Third-party notices

PhoneView builds on the following projects:

## ios-web-streamer

- Repository: https://github.com/himanshkukreja/ios-web-streamer
- Pinned commit: `cfb1504638d3f9298704fb8f3ad9ebd06d60e148`
- Use: iPhone ReplayKit capture, Mac relay, browser fallback, and WebDriverAgent fallback.

At the time this kit was assembled, the checked-out upstream snapshot did not contain an explicit license file. For that reason, the upstream source is not copied into this archive. The bootstrap script asks Git to obtain it directly from its repository, and the archive contains only the PhoneView changes as a patch. Confirm redistribution and usage rights with the upstream author before publishing a combined source tree or binary.

## devicekit-ios

- Repository: https://github.com/mobile-next/devicekit-ios
- Pinned commit: `510d10e5e376221397cef7f8d7acb74603c61888`
- Use: XCTest-based iPhone input injection and device automation.
- License: MIT. The upstream `LICENSE` file is present after running the bootstrap script and remains authoritative.

## Apple frameworks

PhoneView uses Apple SDK frameworks including SwiftUI, ReplayKit, VideoToolbox, WebKit, and XCTest. Use and distribution remain subject to Apple's SDK and developer-program terms.

## PhoneView-specific code

The PhoneView-specific source in this repository is licensed under the repository's Apache License 2.0. The third-party projects and their original source remain governed by their own terms.
