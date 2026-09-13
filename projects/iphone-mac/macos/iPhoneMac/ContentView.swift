import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var streamStatus = StreamStatus()
    @StateObject private var controls = ControlClient()
    @StateObject private var controlRunner = DeviceKitLauncher.shared
    @State private var hoveringScreen = false
    @State private var windowDragOrigin: NSPoint?
    @State private var resizeStartFrame: NSRect?

    private let screenAspect = 1320.0 / 2868.0

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(geometry.size.width - 20, 220)
            let availableHeight = max(geometry.size.height - 96, 430)
            let screenHeight = min(availableHeight, availableWidth / screenAspect)

            VStack(spacing: 12) {
                Color.clear
                    .frame(height: 20)
                    .contentShape(Rectangle())
                    .overlay {
                        Capsule()
                            .fill(Color.secondary.opacity(0.42))
                            .frame(width: 50, height: 4)
                            .allowsHitTesting(false)
                    }
                    .gesture(windowDragGesture)
                    .help("Déplacer la fenêtre")
                phoneShell(screenHeight: screenHeight)

                ZStack {
                    Button("Accueil") {
                        controls.send("home")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .keyboardShortcut("1", modifiers: .command)

                    HStack {
                        Spacer()
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                            .gesture(windowResizeGesture)
                            .help("Redimensionner la fenêtre")
                            .padding(.trailing, 2)
                    }
                }

                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 250, minHeight: 520)
        .containerBackground(.clear, for: .window)
        .background(WindowConfigurator())
        .onAppear {
            controls.connect()
            controlRunner.start()
        }
        .onDisappear {
            controls.disconnect()
        }
    }

    private func phoneShell(screenHeight: CGFloat) -> some View {
        NativeH264StreamView(status: streamStatus)
            .aspectRatio(screenAspect, contentMode: .fit)
            .overlay {
                PhoneInteractionView(controls: controls)
                    .contentShape(Rectangle())
                    .onHover { hoveringScreen = $0 }
            }
            .overlay {
                if streamStatus.state != .connected {
                    waitingOverlay
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .stroke(
                        hoveringScreen ? Color.accentColor.opacity(0.78) : Color.white.opacity(0.13),
                        lineWidth: hoveringScreen ? 2 : 1
                    )
                    .allowsHitTesting(false)
            }
            .frame(height: screenHeight)
            .padding(9)
            .background {
                RoundedRectangle(cornerRadius: 51, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.22), Color(white: 0.035), .black, Color(white: 0.14)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 51, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .white.opacity(0.04), .black],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
            .overlay(alignment: .leading) {
                VStack(spacing: 10) {
                    sideButton(height: 24)
                    sideButton(height: 44)
                    sideButton(height: 44)
                }
                .offset(x: -3, y: -screenHeight * 0.16)
            }
            .overlay(alignment: .trailing) {
                sideButton(height: 70)
                    .offset(x: 3, y: -screenHeight * 0.09)
            }
            .shadow(color: .black.opacity(0.48), radius: 25, y: 16)
            .animation(.easeOut(duration: 0.12), value: hoveringScreen)
    }

    private var waitingOverlay: some View {
        VStack(spacing: 10) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text("En attente de l’iPhone Mac")
                .font(.headline)
            Text(waitingDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(22)
    }

    private var waitingDetail: String {
        switch controlRunner.state {
        case .unavailable:
            return "Déverrouillez l’iPhone, puis relancez le partage."
        case .starting:
            return "Préparation des commandes…\nConfirmez « Démarrer la diffusion » sur l’iPhone."
        case .running:
            return "Confirmez « Démarrer la diffusion » sur l’iPhone."
        }
    }

    private func sideButton(height: CGFloat) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.25), .black],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 4, height: height)
    }

    private var windowDragGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
                if windowDragOrigin == nil {
                    windowDragOrigin = window.frame.origin
                }
                guard let origin = windowDragOrigin else { return }
                window.setFrameOrigin(NSPoint(
                    x: origin.x + value.translation.width,
                    y: origin.y - value.translation.height
                ))
            }
            .onEnded { _ in
                windowDragOrigin = nil
            }
    }

    private var windowResizeGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
                if resizeStartFrame == nil {
                    resizeStartFrame = window.frame
                }
                guard let start = resizeStartFrame else { return }

                let aspect = 410.0 / 850.0
                let horizontalWidth = start.width + value.translation.width
                let verticalWidth = (start.height + value.translation.height) * aspect
                var width = abs(horizontalWidth - start.width) >= abs(verticalWidth - start.width)
                    ? horizontalWidth : verticalWidth
                width = min(max(width, 250), 700)
                let height = width / aspect
                window.setFrame(
                    NSRect(
                        x: start.minX,
                        y: start.maxY - height,
                        width: width,
                        height: height
                    ),
                    display: true
                )
            }
            .onEnded { _ in
                resizeStartFrame = nil
            }
    }
}
