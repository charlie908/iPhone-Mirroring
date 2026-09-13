import SwiftUI
import AppKit

@main
struct iPhoneMacApp: App {
    @NSApplicationDelegateAdaptor(iPhoneMacAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 410, height: 850)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Accueil") {
                    DirectPeerTransport.shared.sendControl(["type": "home"])
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Sélecteur d’apps") {
                    DirectPeerTransport.shared.sendControl(["type": "appSwitcher"])
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Spotlight") {
                    DirectPeerTransport.shared.sendControl(["type": "spotlight"])
                }
                .keyboardShortcut("3", modifiers: .command)
            }

            CommandMenu("Présentation") {
                Button("Plus grand") {
                    iPhoneMacAppDelegate.resizeMainWindow(by: 1.18)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Taille réelle") {
                    iPhoneMacAppDelegate.setMainWindowContentSize(NSSize(width: 410, height: 850))
                }
                .keyboardShortcut("0", modifiers: .command)

                Button("Plus petit") {
                    iPhoneMacAppDelegate.resizeMainWindow(by: 1 / 1.18)
                }
                .keyboardShortcut("-", modifiers: .command)
            }
        }
    }
}

final class iPhoneMacAppDelegate: NSObject, NSApplicationDelegate {
    private var observer: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { notification in
            Self.configure(notification.object as? NSWindow)
        }

        DispatchQueue.main.async {
            NSApp.windows.forEach(Self.configure)
        }
    }

    static func configure(_ window: NSWindow?) {
        guard let window else { return }

        // A resizable borderless window leaves only the physical iPhone visible.
        // Resizing from any edge and dragging the phone bezel remain available.
        window.styleMask = [.borderless, .resizable]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        // Movement and resizing are handled by WindowChromeOverlay so the
        // borderless surface behaves consistently even over SwiftUI content.
        window.isMovableByWindowBackground = false
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbar = nil
        window.contentAspectRatio = NSSize(width: 410, height: 850)
        window.minSize = NSSize(width: 250, height: 520)
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView?.superview?.wantsLayer = true
        window.contentView?.superview?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    static func resizeMainWindow(by factor: CGFloat) {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        let current = window.contentLayoutRect.size
        let width = min(max(current.width * factor, 250), 700)
        setMainWindowContentSize(NSSize(width: width, height: width * 850 / 410))
    }

    static func setMainWindowContentSize(_ size: NSSize) {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        var target = size
        if let visible = window.screen?.visibleFrame, target.height > visible.height * 0.94 {
            let scale = visible.height * 0.94 / target.height
            target = NSSize(width: target.width * scale, height: target.height * scale)
        }
        window.setContentSize(target)
    }
}
