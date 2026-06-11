import Foundation

// MARK: - Data Models

/// Represents a document selected for sending to Kindle
struct KindleDocument: Identifiable, Codable {
    let id: UUID
    var url: URL
    var fileName: String
    var fileSize: Int64
    var title: String

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.fileName = url.lastPathComponent
        self.fileSize = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        self.title = url.deletingPathExtension().lastPathComponent
    }

    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

/// SMTP configuration for the sender email
struct SMTPSettings: Codable, Equatable {
    var host: String = ""
    var port: Int = 587
    var useTLS: Bool = true
    var username: String = ""
    var password: String = ""
    var senderEmail: String = ""

    static let defaults = SMTPSettings(
        host: "smtp.gmail.com",
        port: 587,
        useTLS: true,
        username: "",
        password: "",
        senderEmail: ""
    )

    var isValid: Bool {
        !host.isEmpty && !username.isEmpty && !senderEmail.isEmpty && port > 0
    }
}

/// Kindle device email configuration
struct KindleSettings: Codable, Equatable {
    var kindleEmail: String = ""

    var isValid: Bool {
        !kindleEmail.isEmpty && kindleEmail.contains("@kindle.com")
    }
}

/// A record of a sent document
struct SendHistoryItem: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let fileSize: Int64
    let title: String
    let sentDate: Date
    let kindleEmail: String
    var status: SendStatus

    enum SendStatus: String, Codable {
        case sent
        case failed
        case sending

        var displayName: String {
            switch self {
            case .sent: return "Sent"
            case .failed: return "Failed"
            case .sending: return "Sending…"
            }
        }
    }
}

// MARK: - Errors

enum KindleDropError: LocalizedError {
    case invalidSettings(String)
    case smtpError(String)
    case fileNotFound(String)
    case connectionFailed(String)
    case authenticationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidSettings(let msg): return "Invalid settings: \(msg)"
        case .smtpError(let msg): return "SMTP error: \(msg)"
        case .fileNotFound(let msg): return "File not found: \(msg)"
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .authenticationFailed(let msg): return "Authentication failed: \(msg)"
        }
    }
}