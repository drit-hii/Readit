// CatalogStore.swift
// Reads the bundled books.json dataset. Swap in a larger file with the same schema if you like.
import Foundation

struct CatalogBook: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let year: Int?
    let pages: Int?
    let genre: String?
}

final class CatalogStore {
    static let shared = CatalogStore()
    let books: [CatalogBook]

    private init() {
        guard let url = Bundle.main.url(forResource: "books", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([CatalogBook].self, from: data) else {
            books = []
            return
        }
        books = items.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Case- and diacritic-insensitive search across title and author.
    func search(_ query: String) -> [CatalogBook] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return books }
        return books.filter { $0.title.localizedStandardContains(q) || $0.author.localizedStandardContains(q) }
    }
}
