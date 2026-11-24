// Models.swift
import Foundation
import SwiftData
import SwiftUI

enum ReadingStatus: String, Codable, CaseIterable, Identifiable {
    case reading, read
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .reading: "Currently reading"
        case .read: "Already read"
        }
    }
}

enum GoalKind: String, CaseIterable, Identifiable {
    case minutes, pages
    var id: String { rawValue }
    var title: LocalizedStringKey { self == .minutes ? "Minutes" : "Pages" }
}

@Model
final class Book {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String = ""
    var author: String = ""
    var pageCount: Int = 0
    var currentPage: Int = 0
    var statusRaw: String = ReadingStatus.reading.rawValue
    var colorIndex: Int = 0
    var catalogID: String?
    var addedAt: Date = Date()
    var finishedAt: Date?

    @Relationship(deleteRule: .nullify, inverse: \ReadingSession.book) var sessions: [ReadingSession] = []
    @Relationship(deleteRule: .nullify, inverse: \Quote.book) var quotes: [Quote] = []
    @Relationship(deleteRule: .nullify, inverse: \VoiceMemo.book) var memos: [VoiceMemo] = []

    init(title: String, author: String, pageCount: Int = 0,
         status: ReadingStatus = .reading, catalogID: String? = nil) {
        self.title = title
        self.author = author
        self.pageCount = pageCount
        self.statusRaw = status.rawValue
        self.catalogID = catalogID
        self.colorIndex = Book.stableSeed(title) % Color.spinePalette.count
        if status == .read { currentPage = pageCount; finishedAt = .now }
    }

    var status: ReadingStatus {
        get { ReadingStatus(rawValue: statusRaw) ?? .reading }  // old "wantToRead" books land here
        set {
            statusRaw = newValue.rawValue
            finishedAt = newValue == .read ? (finishedAt ?? .now) : nil
        }
    }

    /// Deletes the book; its past sessions keep the title so History still shows it.
    func remove(from context: ModelContext) {
        sessions.forEach { $0.label = title }
        context.delete(self)
    }

    var progress: Double {
        pageCount > 0 ? min(Double(currentPage) / Double(pageCount), 1) : 0
    }

    static func stableSeed(_ s: String) -> Int {
        s.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
    }
}

@Model
final class ReadingSession {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var duration: TimeInterval = 0
    var pages: Int = 0
    var book: Book?
    var label: String?   // what was read in a free-reading session (newspaper, magazine…)

    init(startedAt: Date, duration: TimeInterval, pages: Int, book: Book?, label: String? = nil) {
        self.startedAt = startedAt
        self.duration = duration
        self.pages = pages
        self.book = book
        self.label = label
    }
}

@Model
final class Quote {
    var id: UUID = UUID()
    var text: String = ""
    var author: String = ""
    var page: Int?
    var createdAt: Date = Date()
    var isFavourite: Bool = false
    var book: Book?

    init(text: String, author: String = "", page: Int? = nil, isFavourite: Bool = false, book: Book? = nil) {
        self.text = text
        self.author = author
        self.page = page
        self.isFavourite = isFavourite
        self.book = book
    }

    var sourceLine: String {
        var parts: [String] = []
        if let t = book?.title { parts.append(t) }
        if !author.isEmpty { parts.append(author) }
        var line = parts.joined(separator: " — ")
        if let page { line += line.isEmpty ? "p. \(page)" : ", p. \(page)" }
        return line
    }

    var shared: SharedQuote {
        SharedQuote(id: id, text: text, author: author, bookTitle: book?.title ?? "")
    }
}

@Model
final class VoiceMemo {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var duration: TimeInterval = 0
    var transcript: String = ""
    var summary: String?
    var book: Book?

    init(transcript: String, duration: TimeInterval, book: Book?) {
        self.transcript = transcript
        self.duration = duration
        self.book = book
    }
}
