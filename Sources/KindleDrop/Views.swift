import SwiftUI
import WebKit

// MARK: - Content View

struct ContentView: View {
    @Binding var showSettings: Bool
    @EnvironmentObject var settings: AppSettings

    @State private var selectedTab: Tab = .send

    enum Tab: String, CaseIterable {
        case send = "Send"
        case history = "History"
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            switch selectedTab {
            case .send:
                SendToKindleWebView()
            case .history:
                HistoryView()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .frame(width: 460, height: 400)
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
                Text("KindleDrop")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Send PDFs to your Kindle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)

            VStack(spacing: 2) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack {
                            Image(systemName: tab == .send ? "paperplane.fill" : "clock.fill")
                                .frame(width: 20)
                            Text(tab.rawValue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            Button {
                showSettings = true
            } label: {
                HStack {
                    Image(systemName: "gearshape.fill").frame(width: 20)
                    Text("Settings")
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 160)
        .background(Color(.windowBackgroundColor).opacity(0.5))
    }
}

// MARK: - WebView

struct SendToKindleWebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        config.websiteDataStore = WKWebsiteDataStore.default() // shares cookies with Safari

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
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Page loaded
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigations within the Send to Kindle domain
            if let url = navigationAction.request.url,
               url.host?.contains("amazon.com") == true || url.host?.contains("amazon.co.uk") == true {
                decisionHandler(.allow)
            } else if navigationAction.navigationType == .linkActivated {
                // External links open in browser
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

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "kindle")
                            .font(.system(size: 28))
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("KindleDrop")
                                .font(.title2).fontWeight(.semibold)
                            Text("Uses Amazon's official Send to Kindle web service")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)

                // Info
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill").foregroundStyle(.blue)
                        Text("How It Works").font(.headline)
                    }
                    Text("KindleDrop loads Amazon's official Send to Kindle page in the main window. Sign in once with your Amazon account, then drag and drop files directly into the web uploader — just like using amazon.com/gp/sendtokindle in your browser.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)

                // Quick Links
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "link.circle.fill").foregroundStyle(.blue)
                        Text("Quick Links").font(.headline)
                    }

                    VStack(spacing: 8) {
                        ActionButton(icon: "arrow.up.doc.fill", title: "Open in Browser",
                                     subtitle: "Open Send to Kindle in Safari", color: .orange) {
                            NSWorkspace.shared.open(URL(string: "https://www.amazon.com/gp/sendtokindle")!)
                        }
                        ActionButton(icon: "gearshape.2.fill", title: "Manage Kindle Devices",
                                     subtitle: "View your Kindle email and approved senders", color: .blue) {
                            NSWorkspace.shared.open(URL(string: "https://www.amazon.com/hz/mycd/myu")!)
                        }
                    }
                }
                .padding(16)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)

                Spacer()
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title3).foregroundStyle(color).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.callout).fontWeight(.medium).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.forward.app.fill").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.windowBackgroundColor)).cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - History View (minimal, kept for future use)

struct HistoryView: View {
    @EnvironmentObject var history: HistoryStore
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Send History")
                    .font(.title).fontWeight(.semibold)
                Spacer()
                if !history.items.isEmpty {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.fill").font(.caption)
                            Text("Clear All")
                        }
                    }
                    .buttonStyle(.plain).foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 12)

            if history.items.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.badge.questionmark").font(.system(size: 48)).foregroundStyle(.secondary)
                    Text("Sends via the web — history is managed by Amazon")
                        .font(.callout).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Files you send through the web page appear in your Amazon library")
                        .font(.caption).foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            } else {
                List {
                    ForEach(history.items) { item in
                        HistoryRow(item: item)
                    }
                }
                .listStyle(.inset)
            }
        }
        .alert("Clear All History?", isPresented: $showClearConfirmation) {
            Button("Clear", role: .destructive) { withAnimation { history.clearHistory() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
    }
}

struct HistoryRow: View {
    let item: SendHistoryItem

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium; f.timeStyle = .short
        return f
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(iconColor.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: iconName).foregroundStyle(iconColor).font(.caption)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName).font(.body).lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.status.displayName).font(.caption).foregroundStyle(iconColor)
                    Text("·").foregroundStyle(.secondary)
                    Text(dateFormatter.string(from: item.sentDate)).font(.caption).foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.secondary)
                    Text(item.kindleEmail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch item.status {
        case .sent: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .sending: return "arrow.triangle.2.circlepath"
        }
    }
    private var iconColor: Color {
        switch item.status {
        case .sent: return .green
        case .failed: return .red
        case .sending: return .orange
        }
    }
}
