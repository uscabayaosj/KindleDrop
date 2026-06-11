import Foundation

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
              let decoded = try? JSONDecoder().decode([SendHistoryItem].self, from: data) else { return }
        items = decoded
    }
}

// MARK: - App Settings

@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private init() {}
}
