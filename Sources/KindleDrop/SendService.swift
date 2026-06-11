import Foundation
import Combine

/// Orchestrates the entire send-to-Kindle workflow
actor SendService {

    static let shared = SendService()

    private init() {}

    /// Send a document to Kindle via email
    /// - Returns: A history item representing the send attempt
    func sendDocument(_ document: KindleDocument,
                      smtp: SMTPSettings,
                      kindleEmail: String) async -> SendHistoryItem {

        let item = SendHistoryItem(
            id: UUID(),
            fileName: document.fileName,
            fileSize: document.fileSize,
            title: document.title,
            sentDate: Date(),
            kindleEmail: kindleEmail,
            status: .sending
        )

        // Save to history immediately as "sending"
        await HistoryStore.shared.addItem(item)

        do {
            let client = SMTPClient(
                host: smtp.host,
                port: smtp.port,
                useTLS: smtp.useTLS
            )

            try await client.send(
                email: smtp.username,
                password: smtp.password,
                from: smtp.senderEmail,
                to: kindleEmail,
                subject: document.title,
                attachmentPath: document.url
            )

            // Update to sent
            var sentItem = item
            sentItem.status = .sent
            await HistoryStore.shared.updateItem(sentItem)
            return sentItem

        } catch {
            // Update to failed
            var failedItem = item
            failedItem.status = .failed
            await HistoryStore.shared.updateItem(failedItem)
            // We still return the item but caller can check status
            return failedItem
        }
    }

    /// Validate that settings are correct by trying to connect
    func validateSettings(smtp: SMTPSettings) async throws -> Bool {
        let client = SMTPClient(host: smtp.host, port: smtp.port, useTLS: smtp.useTLS, timeout: 10)
        try await client.validate()
        return true
    }
}

// MARK: - History Store

@MainActor
class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published var items: [SendHistoryItem] = []

    private let saveKey = "KindleDropSendHistory"
    private let maxItems = 100

    private init() {
        load()
    }

    func addItem(_ item: SendHistoryItem) {
        items.insert(item, at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        save()
    }

    func updateItem(_ item: SendHistoryItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            save()
        }
    }

    func clearHistory() {
        items.removeAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([SendHistoryItem].self, from: data) else {
            return
        }
        items = decoded
    }
}

// MARK: - App Settings Store

@MainActor
class AppSettings: ObservableObject {
    @Published var smtp: SMTPSettings {
        didSet { save() }
    }
    @Published var kindleEmail: String {
        didSet { save() }
    }
    @Published var documentTitle: String = ""

    static let shared = AppSettings()

    private init() {
        // Load saved SMTP settings
        if let data = UserDefaults.standard.data(forKey: "KindleDropSMTPSettings"),
           let decoded = try? JSONDecoder().decode(SMTPSettings.self, from: data) {
            self.smtp = decoded
        } else {
            self.smtp = SMTPSettings.defaults
        }

        // Load saved Kindle email from UserDefaults (PN: we also store in keychain for sensitive)
        self.kindleEmail = UserDefaults.standard.string(forKey: "KindleDropKindleEmail") ?? ""

        // Try keychain for password
        if let password = KeychainManager.readSMTPPassword(), !password.isEmpty {
            self.smtp.password = password
        }

        // Try keychain for kindle email
        if let stored = KeychainManager.readKindleEmail(), !stored.isEmpty {
            self.kindleEmail = stored
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(smtp) {
            UserDefaults.standard.set(data, forKey: "KindleDropSMTPSettings")
        }
        UserDefaults.standard.set(kindleEmail, forKey: "KindleDropKindleEmail")

        // Save sensitive data to keychain
        if !smtp.password.isEmpty {
            _ = KeychainManager.saveSMTPPassword(smtp.password)
        }
        if !kindleEmail.isEmpty {
            _ = KeychainManager.saveKindleEmail(kindleEmail)
        }
    }

    var isValid: Bool {
        smtp.isValid && !kindleEmail.isEmpty
    }
}