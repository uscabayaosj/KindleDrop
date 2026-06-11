import SwiftUI
import UniformTypeIdentifiers

// MARK: - Content View

struct ContentView: View {
    @Binding var showSettings: Bool
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var history: HistoryStore

    @State private var documents: [KindleDocument] = []
    @State private var isSending = false
    @State private var sendResult: SendResult?
    @State private var showResult = false
    @State private var selectedTab: Tab = .send

    enum Tab: String, CaseIterable {
        case send = "Send"
        case history = "History"
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(spacing: 0) {
                // App logo/title
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
                .accessibilityElement(children: .combine)
                .accessibilityLabel("KindleDrop app — Send PDFs to your Kindle")

                // Tab buttons
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
                        .accessibilityLabel("\(tab.rawValue) tab")
                        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 8)

                Spacer()

                // Settings button
                Button {
                    showSettings = true
                } label: {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .frame(width: 20)
                        Text("Settings")
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .accessibilityLabel("Open settings")
            }
            .frame(width: 160)
            .background(Color(.windowBackgroundColor).opacity(0.5))
        } detail: {
            switch selectedTab {
            case .send:
                SendView(
                    documents: $documents,
                    isSending: $isSending,
                    sendResult: $sendResult,
                    showResult: $showResult,
                    showSettings: $showSettings
                )
            case .history:
                HistoryView()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .alert(isPresented: $showResult) {
            Alert(
                title: Text(sendResult?.success == true ? "Sent Successfully" : "Send Failed"),
                message: Text(sendResult?.message ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// MARK: - Send Result

struct SendResult {
    let success: Bool
    let message: String
}

// MARK: - Send View

struct SendView: View {
    @Binding var documents: [KindleDocument]
    @Binding var isSending: Bool
    @Binding var sendResult: SendResult?
    @Binding var showResult: Bool
    @Binding var showSettings: Bool

    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var history: HistoryStore

    @State private var isTargeted = false
    @State private var showFilePicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Send to Kindle")
                    .font(.title)
                    .fontWeight(.semibold)
                Spacer()
                if !documents.isEmpty {
                    Button("Clear All") {
                        documents.removeAll()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Remove all files")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 8)

            // Drop zone or file list
            if documents.isEmpty {
                dropZone
            } else {
                fileList
            }

            Spacer()

            // Bottom bar
            HStack {
                // Status indicator
                statusIndicator

                Spacer()

                // Kindle email badge
                if !settings.kindleEmail.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "kindle")
                            .font(.caption)
                        Text(settings.kindleEmail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(6)
                    .accessibilityLabel("Sending to \(settings.kindleEmail)")
                }

                // Send button
                Button {
                    sendFiles()
                } label: {
                    HStack(spacing: 6) {
                        if isSending {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(isSending ? "Sending…" : "Send to Kindle")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(documents.isEmpty || !settings.isValid || isSending)
                .keyboardShortcut("s", modifiers: .command)
                .accessibilityHint("Sends all files to your Kindle email address")
            }
            .padding(16)
            .background(.bar)
        }
        .onDrop(of: [.fileURL, .pdf], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
        .fileImporter(isPresented: $showFilePicker,
                     allowedContentTypes: [.pdf, .epub, .plainText, .rtf, .html, .image],
                     allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                for url in urls {
                    let doc = KindleDocument(url: url)
                    if !documents.contains(where: { $0.url == url }) {
                        documents.append(doc)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if !settings.isValid {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Configure settings to send")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            .accessibilityLabel("Warning: configure settings before sending")
        } else if documents.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.secondary)
                Text("Drop files above to begin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Drop Zone

    private var dropZone: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isTargeted ? Color.orange : Color.gray.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .frame(maxWidth: 380, maxHeight: 240)

                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(isTargeted ? .orange : .secondary)

                    Text("Drop PDF files here")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("or")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Browse Files…") {
                        showFilePicker = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isTargeted)
            .accessibilityLabel("Drop zone — drag and drop PDF files here, or press Browse Files to select")
            .accessibilityAddTraits(.allowsDirectInteraction)

            Text("Supported: PDF, EPUB, DOCX, TXT, HTML, JPEG, PNG")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - File List

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(documents) { doc in
                    DocumentRow(document: doc) {
                        withAnimation {
                            documents.removeAll { $0.id == doc.id }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Actions

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
                continue
            }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard error == nil else { return }

                // On macOS, Finder drag-and-drop provides the URL directly as an NSURL
                if let url = item as? URL {
                    DispatchQueue.main.async {
                        self.addDocument(url: url)
                    }
                    return
                }

                // Fallback: some providers give Data that needs to be converted
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        self.addDocument(url: url)
                    }
                    return
                }

                // Last resort: try string path
                if let path = item as? String {
                    let url = URL(fileURLWithPath: path)
                    DispatchQueue.main.async {
                        self.addDocument(url: url)
                    }
                }
            }
            accepted = true
        }
        return accepted
    }

    private func addDocument(url: URL) {
        let doc = KindleDocument(url: url)
        if !documents.contains(where: { $0.url == url }) {
            withAnimation {
                documents.append(doc)
            }
        }
    }

    private func sendFiles() {
        guard !documents.isEmpty, settings.isValid else { return }
        isSending = true

        Task {
            var sent: [String] = []
            var failed: [String] = []

            for doc in documents {
                let result = await SendService.shared.sendDocument(
                    doc,
                    smtp: settings.smtp,
                    kindleEmail: settings.kindleEmail
                )

                if result.status == .sent {
                    sent.append(result.fileName)
                } else {
                    failed.append(result.fileName)
                }
            }

            await MainActor.run {
                if failed.isEmpty {
                    sendResult = SendResult(success: true, message: "✅ \(sent.count) file\(sent.count == 1 ? "" : "s") sent to \(settings.kindleEmail)")
                } else {
                    let summary = "Sent: \(sent.count). Failed: \(failed.count)\n\(failed.joined(separator: "\n"))"
                    sendResult = SendResult(success: false, message: summary)
                }
                showResult = true
                documents.removeAll()
                isSending = false
            }
        }
    }
}

// MARK: - Document Row

struct DocumentRow: View {
    let document: KindleDocument
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // File icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 40, height: 44)

                Image(systemName: "doc.richtext")
                    .font(.title3)
                    .foregroundStyle(.orange)
            }

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(document.fileName)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    Text(document.fileSizeFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(document.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(document.fileName)")
        }
        .padding(10)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(document.fileName), \(document.fileSizeFormatted)")
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var showSMTPPassword = false
    @State private var smtpTestResult: String?
    @State private var isTestingSMTP = false
    @State private var showKindleInfo = false

    var body: some View {
        TabView {
            smtpSettingsTab
                .tabItem {
                    Label("SMTP", systemImage: "envelope.fill")
                }

            kindleSettingsTab
                .tabItem {
                    Label("Kindle", systemImage: "kindle")
                }
        }
        .frame(width: 540, height: 500)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    settings.save()
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }

    // MARK: - SMTP Tab

    private var smtpSettingsTab: some View {
        Form {
            // Server section
            Section {
                Label("SMTP Server", systemImage: "server.rack")
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .padding(.bottom, 4)

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SMTP Host")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        TextField("smtp.gmail.com", text: $settings.smtp.host)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Port")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        TextField("587", value: $settings.smtp.port, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }

                Toggle(isOn: $settings.smtp.useTLS) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use TLS/SSL")
                        Text("Encrypts the connection to your email server")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Authentication section
            Section {
                Label("Authentication", systemImage: "person.badge.key.fill")
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Sender Email")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    TextField("[EMAIL]", text: $settings.smtp.senderEmail)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Sender email address")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Username")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        TextField("[EMAIL]", text: $settings.smtp.username)
                            .textFieldStyle(.roundedBorder)
                    }
                    .accessibilityLabel("SMTP username — usually your email address")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Password / App Password")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack {
                        if showSMTPPassword {
                            TextField("", text: $settings.smtp.password)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("App password", text: $settings.smtp.password)
                                .textFieldStyle(.roundedBorder)
                        }
                        Button {
                            showSMTPPassword.toggle()
                        } label: {
                            Image(systemName: showSMTPPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(showSMTPPassword ? "Hide password" : "Show password")
                    }
                }

                if !settings.smtp.password.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                        Text("Gmail users: use an App Password from your Google Account settings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Test connection
            Section {
                HStack {
                    Button {
                        testSMTPConnection()
                    } label: {
                        HStack(spacing: 6) {
                            if isTestingSMTP {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "bolt.fill")
                                    .font(.caption)
                            }
                            Text(isTestingSMTP ? "Testing…" : "Test Connection")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isTestingSMTP || !settings.smtp.isValid)
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    if let result = smtpTestResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.hasPrefix("✅") ? .green : .red)
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Kindle Tab

    private var kindleSettingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "kindle")
                            .font(.system(size: 28))
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Kindle Settings")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Configure how your documents reach your Kindle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)

                // Kindle Email Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "envelope.badge.fill")
                            .foregroundStyle(.orange)
                        Text("Your Kindle Email")
                            .font(.headline)
                    }

                    TextField("[EMAIL]", text: $settings.kindleEmail)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .accessibilityLabel("Kindle email address")

                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text("Find this in ")
                        Text("Amazon → Manage Your Content and Devices → Devices")
                            .fontWeight(.medium)
                        Text(" → your Kindle's email (ends in @kindle.com)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // Email validation hint
                    if !settings.kindleEmail.isEmpty && !settings.kindleEmail.contains("@kindle.com") {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("Kindle emails typically end with @kindle.com — double-check this address")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(16)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)

                // Setup Checklist Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "checklist.checked")
                            .foregroundStyle(.green)
                        Text("Setup Checklist")
                            .font(.headline)
                    }

                    VStack(spacing: 6) {
                        KindleChecklistRow(
                            icon: settings.kindleEmail.contains("@kindle.com") ? "checkmark.circle.fill" : "circle",
                            iconColor: settings.kindleEmail.contains("@kindle.com") ? .green : .secondary,
                            title: "Find your Kindle email address",
                            subtitle: "Look in Amazon Account → Devices — it ends with @kindle.com",
                            isComplete: settings.kindleEmail.contains("@kindle.com")
                        )

                        KindleChecklistRow(
                            icon: settings.smtp.senderEmail.contains("@") ? "checkmark.circle.fill" : "circle",
                            iconColor: settings.smtp.senderEmail.contains("@") ? .green : .secondary,
                            title: "Add sender email to Amazon's approved list",
                            subtitle: "Amazon only accepts emails from approved addresses in your account settings",
                            isComplete: settings.smtp.senderEmail.contains("@")
                        )

                        KindleChecklistRow(
                            icon: settings.smtp.password.count >= 8 ? "checkmark.circle.fill" : "circle",
                            iconColor: settings.smtp.password.count >= 8 ? .green : .secondary,
                            title: "Use an App Password",
                            subtitle: "Many providers require a dedicated app password (not your login password)",
                            isComplete: settings.smtp.password.count >= 8
                        )
                    }
                }
                .padding(16)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)

                // Setup Instructions Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "graduationcap.fill")
                            .foregroundStyle(.blue)
                        Text("How It Works")
                            .font(.headline)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SetupStep(number: 1, title: "Find your Kindle email",
                                 detail: "Go to Amazon → Manage Your Content and Devices → Devices tab. Each Kindle has a unique @kindle.com email.")

                        SetupStep(number: 2, title: "Approve your sender email",
                                 detail: "In the same page under Personal Document Settings, add the email you're sending from to the Approved List.")

                        SetupStep(number: 3, title: "Configure SMTP below",
                                 detail: "Switch to the SMTP tab and enter your email provider's SMTP settings. Gmail users need an App Password.")

                        SetupStep(number: 4, title: "Drag, drop, and send!",
                                 detail: "Drop a PDF on the main window and click Send. Amazon converts and delivers it to your Kindle.")
                    }
                }
                .padding(16)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)

                // Quick Actions Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "link.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Quick Actions")
                            .font(.headline)
                    }

                    VStack(spacing: 8) {
                        ActionButton(
                            icon: "arrow.up.doc.fill",
                            title: "Open Send to Kindle Page",
                            subtitle: "Upload files directly through Amazon's web interface",
                            color: .orange
                        ) {
                            if let url = URL(string: "https://www.amazon.com/gp/sendtokindle") {
                                NSWorkspace.shared.open(url)
                            }
                        }

                        ActionButton(
                            icon: "gearshape.2.fill",
                            title: "Manage Approved Email Settings",
                            subtitle: "Add or remove sender emails in your Amazon account",
                            color: .blue
                        ) {
                            if let url = URL(string: "https://www.amazon.com/hz/mycd/myu") {
                                NSWorkspace.shared.open(url)
                            }
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
    }

    // MARK: - Actions

    private func testSMTPConnection() {
        isTestingSMTP = true
        smtpTestResult = nil

        Task {
            do {
                _ = try await SendService.shared.validateSettings(smtp: settings.smtp)
                await MainActor.run {
                    smtpTestResult = "✅ Connection successful! SMTP server responded."
                }
            } catch {
                await MainActor.run {
                    smtpTestResult = "❌ Connection failed: \(error.localizedDescription)"
                }
            }

            await MainActor.run {
                isTestingSMTP = false
            }
        }
    }
}

// MARK: - Kindle Checklist Row

struct KindleChecklistRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.title3)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .fontWeight(isComplete ? .regular : .medium)
                    .foregroundStyle(isComplete ? .secondary : .primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if isComplete {
                Text("Done")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(10)
        .background(isComplete ? Color.green.opacity(0.03) : Color.clear)
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isComplete ? "✅" : "⬜") \(title)")
    }
}

// MARK: - Setup Step

struct SetupStep: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(title). \(detail)")
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
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.forward.app.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.windowBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title): \(subtitle)")
    }
}

// MARK: - History View

struct HistoryView: View {
    @EnvironmentObject var history: HistoryStore
    @State private var selectedItem: SendHistoryItem?
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Send History")
                    .font(.title)
                    .fontWeight(.semibold)
                Spacer()
                if !history.items.isEmpty {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                                .font(.caption)
                            Text("Clear All")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Clear all history")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            if history.items.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No send history yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Files you send will appear here")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .accessibilityLabel("No send history")
            } else {
                List(history.items) { item in
                    HistoryRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItem = item
                        }
                }
                .listStyle(.inset)
            }
        }
        .alert("Clear All History?", isPresented: $showClearConfirmation) {
            Button("Clear", role: .destructive) {
                withAnimation {
                    history.clearHistory()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .sheet(item: $selectedItem) { item in
            HistoryDetailView(item: item)
        }
    }
}

// MARK: - History Detail

struct HistoryDetailView: View {
    let item: SendHistoryItem
    @Environment(\.dismiss) private var dismiss

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .medium
        return f
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Send Details")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }

            VStack(alignment: .leading, spacing: 12) {
                DetailRow(label: "File", value: item.fileName)
                DetailRow(label: "Size", value: ByteCountFormatter().string(fromByteCount: item.fileSize))
                DetailRow(label: "Title", value: item.title)
                DetailRow(label: "Sent to", value: item.kindleEmail)
                DetailRow(label: "Date", value: dateFormatter.string(from: item.sentDate))
                DetailRow(label: "Status", value: item.status.displayName)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
        .padding()
        .frame(width: 400)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
            Text(value)
                .font(.body)
            Spacer()
        }
    }
}

// MARK: - History Row

struct HistoryRow: View {
    let item: SendHistoryItem

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .font(.caption)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.status.displayName)
                        .font(.caption)
                        .foregroundStyle(iconColor)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(dateFormatter.string(from: item.sentDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(item.kindleEmail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.fileName) — \(item.status.displayName)")
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