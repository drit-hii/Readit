// SharedModels.swift
// Add to BOTH targets: Readie (app) and ReadieWidgets (widget extension).

import Foundation
import ActivityKit
import WidgetKit

enum AppGroup {
    static let id = "group.com.readie.app"
}

/// A favourite quote, serialised into the App Group so the widget can read it.
struct SharedQuote: Codable, Hashable, Identifiable {
    var id: UUID
    var text: String
    var author: String
    var bookTitle: String

    var source: String {
        [bookTitle, author].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

enum SharedStore {
    private static let key = "favouriteQuotes"
    private static var defaults: UserDefaults { UserDefaults(suiteName: AppGroup.id) ?? .standard }

    static func saveFavourites(_ quotes: [SharedQuote]) {
        if let data = try? JSONEncoder().encode(quotes) {
            defaults.set(data, forKey: key)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "QuoteWidget")
    }

    static func loadFavourites() -> [SharedQuote] {
        guard let data = defaults.data(forKey: key),
              let quotes = try? JSONDecoder().decode([SharedQuote].self, from: data) else { return [] }
        return quotes
    }
}

/// Live Activity (Lock Screen / Dynamic Island timer).
struct ReadingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// "Effective" start: now minus time already read, so the system can count up by itself.
        var startDate: Date
        /// Non-nil while paused; the timer freezes at (pausedAt - startDate).
        var pausedAt: Date?
    }

    var bookTitle: String
    /// Only set when the reader has a favourite quote. Nil means nothing is shown.
    var quote: String?
    var quoteSource: String?
}
