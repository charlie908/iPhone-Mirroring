import SwiftUI

struct ContentView: View {
    @AppStorage("serverHost") private var serverHost = "192.168.1.100"
    @StateObject private var streamStatus = StreamStatus()
    @StateObject private var controls = ControlClient()
    @State private var showConnection = false
    @State private var showKeyboard = false
    @State private var typedText = ""
    @State private var chromeVisible = false

    private let screenAspect = 1320.0 / 2868.0

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = min(max(geometry.size.height - 178, 580), 704)
            let shellWidth = screenHeight * screenAspect + 22

            ZStack {
                if chromeVisible {
                    Color.clear
                        .glassBackgroundEffect(
                            in: RoundedRectangle(cornerRadius: 48, style: .continuous)
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }

                chromeToggleRegions(shellWidth: shellWidth)

                phoneAssembly(screenHeight: screenHeight)

                if chromeVisible {
                    expandedControls
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: chromeVisible)
        .sheet(isPresented: $showConnection) { connectionSheet }
        .sheet(isPresented: $showKeyboard) { keyboardSheet }
        .task(id: serverHost) {
            controls.connect(host: serverHost)
        }
        .onDisappear { controls.disconnect() }
    }

    private func phoneAssembly(screenHeight: CGFloat) -> some View {
        VStack(spacing: 12) {
            phoneShell(screenHeight: screenHeight)

            Button {
                controls.send("home")
            } label: {
                Text("Accueil")
                    .font(.headline)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .help("Revenir à l’écran d’accueil de l’iPhone")
        }
        .offset(y: 16)
        .zIndex(2)
    }

    private func phoneShell(screenHeight: CGFloat) -> some View {
        NativeH264StreamView(host: serverHost, status: streamStatus)
            .id(serverHost)
            .aspectRatio(screenAspect, contentMode: .fit)
            .overlay { NativeTargetGrid(controls: controls) }
            .clipShape(RoundedRectangle(cornerRadius: 50, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 50, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 0.8)
            }
            .frame(height: screenHeight)
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 61, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.20),
                                Color(white: 0.035),
                                Color.black,
                                Color(white: 0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 61, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.34), .white.opacity(0.04), .black],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    }
            }
            .overlay(alignment: .leading) {
                VStack(spacing: 13) {
                    phoneSideButton(height: 29)
                    phoneSideButton(height: 53)
                    phoneSideButton(height: 53)
                }
                .offset(x: -4, y: -132)
            }
            .overlay(alignment: .trailing) {
                phoneSideButton(height: 83)
                    .offset(x: 4, y: -72)
            }
            .shadow(color: .black.opacity(0.58), radius: 38, y: 24)
            .shadow(color: .blue.opacity(0.10), radius: 14)
    }

    private func phoneSideButton(height: CGFloat) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.22), .black],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 5, height: height)
            .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 0.5))
    }

    private func chromeToggleRegions(shellWidth: CGFloat) -> some View {
        ZStack {
            VStack {
                ChromeToggleZone(axis: .top, isExpanded: chromeVisible) {
                    chromeVisible.toggle()
                }
                .frame(width: min(shellWidth + 170, 520), height: 70)
                Spacer()
            }

            HStack(spacing: 0) {
                ChromeToggleZone(axis: .leading, isExpanded: chromeVisible) {
                    chromeVisible.toggle()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Color.clear
                    .frame(width: shellWidth + 18)
                    .allowsHitTesting(false)

                ChromeToggleZone(axis: .trailing, isExpanded: chromeVisible) {
                    chromeVisible.toggle()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.vertical, 82)
        }
        .zIndex(1)
    }

    private var expandedControls: some View {
        ZStack {
            VStack {
                header
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .glassBackgroundEffect(in: Capsule())
                Spacer()
            }

            HStack {
                VStack(spacing: 12) {
                    compactControlButton("speaker.minus", help: "Baisser le volume") {
                        controls.send("volumeDown")
                    }
                    compactControlButton("speaker.plus", help: "Augmenter le volume") {
                        controls.send("volumeUp")
                    }
                }
                .padding(12)
                .glassBackgroundEffect(in: Capsule())

                Spacer()

                VStack(spacing: 12) {
                    compactControlButton("keyboard", help: "Écrire sur l’iPhone") {
                        typedText = ""
                        showKeyboard = true
                    }
                    compactControlButton("lock.fill", help: "Verrouiller l’iPhone") {
                        controls.send("lock")
                    }
                    compactControlButton("network", help: "Régler la connexion") {
                        showConnection = true
                    }
                }
                .padding(12)
                .glassBackgroundEffect(in: Capsule())
            }
            .padding(.horizontal, 18)
        }
        .padding(4)
        .zIndex(3)
    }

    private func compactControlButton(
        _ icon: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.bordered)
        .help(help)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.system(size: 28, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 3) {
                Text("PhoneView")
                    .font(.title2.weight(.semibold))
                HStack(spacing: 7) {
                    Circle()
                        .fill(streamStatus.state.color)
                        .frame(width: 8, height: 8)
                    Text(streamStatus.state.rawValue)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                HStack(spacing: 7) {
                    Circle()
                        .fill(controls.isConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(controls.isConnected ? "Commandes actives" : "Commandes hors ligne")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }

            Spacer()

            Button {
                showConnection = true
            } label: {
                Label("Connexion", systemImage: "network")
            }
            .buttonStyle(.bordered)
        }
    }

    private var connectionSheet: some View {
        VStack(alignment: .leading, spacing: 22) {
            Label("Connexion au Mac", systemImage: "network")
                .font(.title2.weight(.semibold))
            Text("Indique l’adresse locale du Mac qui exécute le serveur PhoneView.")
                .foregroundStyle(.secondary)
            TextField("192.168.1.100", text: $serverHost)
                .textFieldStyle(.roundedBorder)
                .font(.title3.monospaced())
            HStack {
                Spacer()
                Button("Terminé") { showConnection = false }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(34)
        .frame(width: 520)
    }

    private var keyboardSheet: some View {
        VStack(alignment: .leading, spacing: 22) {
            Label("Écrire sur l’iPhone", systemImage: "keyboard")
                .font(.title2.weight(.semibold))
            Text("Place d’abord le curseur dans un champ sur l’iPhone, puis saisis le texte ici.")
                .foregroundStyle(.secondary)
            TextField("Texte à envoyer", text: $typedText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
            HStack {
                Button("Annuler", role: .cancel) { showKeyboard = false }
                Spacer()
                Button("Envoyer") {
                    controls.send("type", text: typedText)
                    showKeyboard = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(typedText.isEmpty)
            }
        }
        .padding(34)
        .frame(width: 600)
    }
}

private struct ChromeToggleZone: View {
    enum Axis {
        case leading
        case trailing
        case top
    }

    let axis: Axis
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.white.opacity(isExpanded ? 0.022 : 0.001))
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(isExpanded ? 0.18 : 0.035))
                }
                .contentShape(.interaction, RoundedRectangle(cornerRadius: 30))
                .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 30))
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityLabel(isExpanded ? "Masquer les commandes" : "Afficher les commandes")
    }

    private var symbol: String {
        switch axis {
        case .leading: "chevron.right"
        case .trailing: "chevron.left"
        case .top: "chevron.down"
        }
    }
}

private struct NativeTargetGrid: View {
    @ObservedObject var controls: ControlClient
    // The cells exist only to give visionOS a gaze target. The actual tap keeps
    // its exact projected location, so precision is not limited to the grid.
    private let columns = 8
    private let rows = 18

    var body: some View {
        GeometryReader { geometry in
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: columns),
                spacing: 0
            ) {
                ForEach(0..<(columns * rows), id: \.self) { index in
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.white)
                        .contentShape(.interaction, Rectangle())
                        .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 7))
                        .hoverEffect { effect, isActive, _ in
                            effect
                                .opacity(isActive ? 0.28 : 0.001)
                                .scaleEffect(isActive ? 0.94 : 1.0)
                                .animation(.easeOut(duration: 0.08)) { $0 }
                        }
                    .frame(height: geometry.size.height / CGFloat(rows))
                }
            }
            .coordinateSpace(name: "phoneSurface")
            .contentShape(Rectangle())
            .simultaneousGesture(
                // One recognizer classifies the pinch after release. This
                // prevents a slightly moving pinch from sending both a tap
                // and a swipe to XCTest at the same time.
                DragGesture(minimumDistance: 0, coordinateSpace: .named("phoneSurface"))
                    .onEnded { value in
                        let dx = value.location.x - value.startLocation.x
                        let dy = value.location.y - value.startLocation.y
                        if hypot(dx, dy) < 12 {
                            controls.tap(at: value.location, in: geometry.size)
                        } else {
                            controls.swipe(
                                from: value.startLocation,
                                to: value.location,
                                in: geometry.size
                            )
                        }
                    }
            )
        }
        .accessibilityLabel("Écran de l’iPhone")
        .accessibilityHint("La zone regardée s’illumine. Pincez pour toucher, pincez et déplacez pour balayer")
    }
}
