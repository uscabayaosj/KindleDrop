import Foundation

/// A record of a sent document (for history display)
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
