import SwiftUI
import WebKit

// We catch the redirect to httpbin.org before the page loads.
struct LoginView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openURL) private var openURL

    @State private var url: URL?
    @State private var pastedURL = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let url {
                    OAuthWebView(url: url) { redirect in finish(with: redirect) }
                } else if errorMessage == nil {
                    ProgressView()
                } else {
                    Image(systemName: "key.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
                // Plan B: sign in with the default browser and paste the final URL.
                HStack {
                    Button("Open in browser") {
                        if let url { openURL(url) }
                    }
                    .disabled(url == nil)
                    TextField("…or paste the final URL here (https://httpbin.org/get?code=…)", text: $pastedURL)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(submitPastedURL)
                    if isWorking {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Connect", action: submitPastedURL)
                            .disabled(URL(string: pastedURL.trimmingCharacters(in: .whitespaces)) == nil)
                    }
                }
            }
            .padding(14)
            .background(.bar)
        }
        .frame(width: 520, height: 700)
        .task {
            do {
                url = try auth.authorizationURL()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func submitPastedURL() {
        guard let redirect = URL(string: pastedURL.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        finish(with: redirect)
    }

    private func finish(with redirect: URL) {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await auth.handleRedirect(redirect)
                dismissWindow(id: "login")
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}

private struct OAuthWebView: NSViewRepresentable {
    let url: URL
    let onRedirect: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onRedirect: onRedirect) }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onRedirect: (URL) -> Void

        init(onRedirect: @escaping (URL) -> Void) {
            self.onRedirect = onRedirect
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url, url.host == AuthManager.redirectHost else { return .allow }
            onRedirect(url)
            return .cancel
        }
    }
}
