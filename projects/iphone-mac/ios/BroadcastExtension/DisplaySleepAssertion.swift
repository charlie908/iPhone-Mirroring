import CoreFoundation
import Darwin
import Foundation

/// Holds an IOKit display-sleep assertion for the lifetime of the ReplayKit
/// upload extension. This is intentionally isolated to iPhone Mac: the app is
/// developer-signed and is not intended for App Store distribution.
final class DisplaySleepAssertion {
    private typealias CreateAssertion = @convention(c) (
        CFString,
        UInt32,
        CFString,
        UnsafeMutablePointer<UInt32>
    ) -> Int32
    private typealias ReleaseAssertion = @convention(c) (UInt32) -> Int32

    private var library: UnsafeMutableRawPointer?
    private var assertionID: UInt32 = 0
    private var isHeld = false

    @discardableResult
    func acquire() -> Int32? {
        guard !isHeld else { return 0 }
        guard let library = dlopen(
            "/System/Library/Frameworks/IOKit.framework/IOKit",
            RTLD_NOW
        ), let symbol = dlsym(library, "IOPMAssertionCreateWithName") else {
            return nil
        }

        self.library = library
        let create = unsafeBitCast(symbol, to: CreateAssertion.self)
        let result = create(
            "PreventUserIdleDisplaySleep" as CFString,
            255,
            "iPhone Mac screen broadcast" as CFString,
            &assertionID
        )
        isHeld = result == 0
        return result
    }

    func release() {
        if isHeld,
           let library,
           let symbol = dlsym(library, "IOPMAssertionRelease") {
            let release = unsafeBitCast(symbol, to: ReleaseAssertion.self)
            _ = release(assertionID)
        }
        isHeld = false
        assertionID = 0
        if let library { dlclose(library) }
        library = nil
    }

    deinit {
        release()
    }
}
