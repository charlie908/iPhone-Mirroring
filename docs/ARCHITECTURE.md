# Architecture

PhoneView is a monorepo containing three independently installable prototypes. They share the same broad capture and control ideas but use separate bundle identifiers and discovery services.

## Shared capture pipeline

1. The user explicitly starts a ReplayKit broadcast on the iPhone.
2. The broadcast extension receives video sample buffers.
3. VideoToolbox encodes them as low-latency H.264.
4. The receiving app decodes H.264 natively and displays the latest frame.
5. Pointer/keyboard events travel back to the iPhone.
6. DeviceKit/XCTest injects supported input events into the unlocked device.

The encoder profile currently targets up to 60 fps, approximately 10 Mbps, and a one-second keyframe interval. Actual performance depends on the device, radio conditions, and OS scheduling.

## PhoneView

```text
iPhone ReplayKit extension
    │ H.264 WebSocket :8765
    ▼
Mac Python relay :8999
    │ native H.264 WebSocket
    ▼
Vision Pro viewer
    │ HTTP control commands
    ▼
Mac relay → DeviceKit/WDA → iPhone
```

The Mac is a required bridge. DeviceKit on port 12004 is preferred; WebDriverAgent remains a fallback inherited from the upstream streamer.

## iPhone Direct

```text
iPhone ReplayKit extension  ◀──── input commands ────  Vision Pro
            │                                            ▲
            └──────── H.264 peer-to-peer TCP ────────────┘
                         _iphonedirect._tcp
```

Network.framework Bonjour discovery uses peer-to-peer networking. The iPhone extension forwards controls locally to DeviceKit on port 12004. The Mac is needed to build/sign/install the developer apps, but not in the runtime media path.

## iPhone Mac

```text
iPhone ReplayKit extension  ◀──── input commands ────  Native Mac app
            │                                            ▲
            └──────── H.264 peer-to-peer TCP ────────────┘
                           _iphonemac._tcp
```

The native Mac app handles window presentation, decoding, mouse/trackpad gestures, keyboard input, and shortcuts. Its bundled DeviceKit runner uses port 12005 to remain separate from the other prototypes.

## Trust boundaries

These prototypes assume a trusted developer and trusted local network. The current protocols do not provide application-level authentication or encryption. See `SECURITY.md` before extending the architecture beyond local testing.

