import SwiftUI
import WebKit

struct SendToKindleView: View {
    @State private var showSettings = false

    var body: some View {
        AmazonWebView()
            .edgesIgnoringSafeArea(.all)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        NSWorkspace.shared.open(URL(string: "https://www.amazon.com/gp/sendtokindle")!)
                    } label: {
                        Image(systemName: "safari")
                    }
                    .accessibilityLabel("Open in browser")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
                    .frame(width: 400, height: 300)
            }
    }
}

// MARK: - Amazon Send to Kindle WebView

struct AmazonWebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        if let url = URL(string: "https://www.amazon.com/gp/sendtokindle") {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               let host = url.host,
               host.contains("amazon.com") || host.contains("amazon.co.uk") || host.contains("amazon.ca") {
                decisionHandler(.allow)
            } else if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    NSWorkspace.shared.open(url)
                }
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("KindleDrop")
                    .font(.title2).fontWeight(.semibold)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill").foregroundStyle(.blue)
                    Text("How it works").font(.headline)
                }
                Text("KindleDrop loads Amazon's official Send to Kindle page. Sign in once, then upload files through Amazon's own interface — just like the website.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "link.circle.fill").foregroundStyle(.blue)
                    Text("Quick Links").font(.headline)
                }

                LinkButton(title: "Manage Kindle Devices", url: "https://www.amazon.com/hz/mycd/myu")
                LinkButton(title: "Approved Sender List", url: "https://www.amazon.com/hz/mycd/myx")
                LinkButton(title: "Amazon Help", url: "https://www.amazon.com/gp/help/customer/display.html?nodeId=G7NECT4B4ZWHQ8WV")
            }

            Spacer()
        }
        .padding()
    }
}

struct LinkButton: View {
    let title: String
    let url: String

    var body: some View {
        Button {
            NSWorkspace.shared.open(URL(string: url)!)
        } label: {
            HStack {
                Text(title).font(.callout)
                Spacer()
                Image(systemName: "arrow.up.forward.app.fill")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
