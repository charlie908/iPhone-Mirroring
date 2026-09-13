import SwiftUI
import WebKit

@MainActor
final class StreamStatus: ObservableObject {
    enum State: String {
        case loading = "Connexion…"
        case connected = "iPhone connecté"
        case disconnected = "Hors ligne"
        case failed = "Connexion impossible"

        var color: Color {
            switch self {
            case .connected: .green
            case .loading: .orange
            case .disconnected, .failed: .red
            }
        }
    }

    @Published var state: State = .loading
}

struct PhoneStreamView: UIViewRepresentable {
    let host: String
    @ObservedObject var status: StreamStatus

    func makeCoordinator() -> Coordinator {
        Coordinator(status: status)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "phoneViewStatus")
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: Self.polishScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        load(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let wanted = "http://\(host):8999/?native=1"
        if webView.url?.absoluteString != wanted {
            status.state = .loading
            load(webView)
        }
    }

    private func load(_ webView: WKWebView) {
        guard let url = URL(string: "http://\(host):8999/?native=1") else {
            status.state = .failed
            return
        }
        webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
    }

    static let polishScript = #"""
    (() => {
      const style = document.createElement('style');
      style.textContent = `
        html, body { background: transparent !important; overflow: hidden !important; }
        body { min-height: 100vh !important; }
        #container { max-width: none !important; height: 100vh !important; padding: 8px !important; gap: 0 !important; }
        header, #device-info-panel, #device-controls, #stats-bar, footer { display: none !important; }
        main, #video-wrapper { width: 100% !important; height: 100% !important; }
        .iphone-frame { height: 100% !important; padding: 8px !important; border-radius: 48px !important; }
        #video-container { height: 100% !important; max-height: none !important; border-radius: 40px !important; }
      `;
      document.head.appendChild(style);

      const report = () => {
        const text = document.querySelector('#status .status-text')?.textContent || 'Disconnected';
        window.webkit.messageHandlers.phoneViewStatus.postMessage(text);
      };
      const target = document.getElementById('status');
      if (target) new MutationObserver(report).observe(target, { subtree: true, childList: true, characterData: true, attributes: true });
      report();
    })();
    """#

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let status: StreamStatus

        init(status: StreamStatus) {
            self.status = status
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            status.state = .loading
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            status.state = .failed
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            status.state = .failed
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let value = message.body as? String else { return }
            switch value.lowercased() {
            case let text where text.contains("connected") && !text.contains("disconnected"):
                status.state = .connected
            case let text where text.contains("connecting"):
                status.state = .loading
            default:
                status.state = .disconnected
            }
        }
    }
}
