// QuoteWidget.swift
// Shows the book from the latest session with its pages, and a favourite quote under it.
// Renders nothing when there is neither.
import WidgetKit
import SwiftUI

struct QuoteEntry: TimelineEntry {
    let date: Date
    let quote: SharedQuote?
    var book: SharedBook? = SharedStore.loadLastBook()
}

struct QuoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(date: .now, quote: SharedQuote(id: UUID(), text: "A favourite line from your book appears here.",
                                                   author: "Author", bookTitle: "Book"),
                   book: SharedBook(title: "Book", author: "Author", currentPage: 120, pageCount: 300))
    }

    func getSnapshot(in context: Context, completion: @escaping (QuoteEntry) -> Void) {
        completion(QuoteEntry(date: .now, quote: context.isPreview ? placeholder(in: context).quote
                                                                   : SharedStore.loadFavourites().first))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteEntry>) -> Void) {
        let favourites = SharedStore.loadFavourites()
        let now = Date()
        // No quotes: one entry, still showing the book when there is one.
        guard !favourites.isEmpty else {
            completion(Timeline(entries: [QuoteEntry(date: now, quote: nil)], policy: .never))
            return
        }
        let start = Int.random(in: 0..<favourites.count)
        let entries = (0..<12).map { i in
            QuoteEntry(date: now.addingTimeInterval(Double(i) * 3600), quote: favourites[(start + i) % favourites.count])
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct QuoteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuoteEntry
    private let accent = Color(red: 0.58, green: 0.33, blue: 0.28)

    var body: some View {
        switch family {
        case .accessoryInline:
            if let quote = entry.quote { Text(quote.text) } else if let book = entry.book { Text(book.title) }
        case .accessoryRectangular:
            if let quote = entry.quote {
                VStack(alignment: .leading, spacing: 2) {
                    Text("“\(quote.text)”").font(.caption).lineLimit(3)
                    if !quote.source.isEmpty { Text(quote.source).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                }
            } else if let book = entry.book {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title).font(.headline).lineLimit(1)
                    Text(pages(book)).font(.caption)
                    if book.pageCount > 0 { ProgressView(value: progress(book)) }
                }
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                if let book = entry.book { bookView(book) }
                if let quote = entry.quote {
                    if entry.book != nil { Divider() }
                    quoteView(quote)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func bookView(_ book: SharedBook) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Reading", systemImage: "book.fill").font(.caption.weight(.semibold)).foregroundStyle(accent)
            Text(book.title).font(.system(.headline, design: .serif)).lineLimit(entry.quote == nil ? 3 : 1)
            if !book.author.isEmpty { Text(book.author).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            if book.pageCount > 0 { ProgressView(value: progress(book)).tint(accent) }
            Text(pages(book)).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private func quoteView(_ quote: SharedQuote) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if entry.book == nil { Image(systemName: "quote.opening").foregroundStyle(accent) }
            Text(entry.book == nil ? quote.text : "“\(quote.text)”")
                .font(.system(entry.book == nil ? .body : .caption, design: .serif))
                .minimumScaleFactor(0.7)
                .lineLimit(entry.book == nil ? (family == .systemSmall ? 5 : 4) : 2)
            if !quote.source.isEmpty && (entry.book == nil || family != .systemSmall) {
                Text(quote.source).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    private func progress(_ book: SharedBook) -> Double {
        min(Double(book.currentPage) / Double(max(book.pageCount, 1)), 1)
    }

    private func pages(_ book: SharedBook) -> String {
        book.pageCount > 0 ? "Page \(book.currentPage) of \(book.pageCount)" : "Page \(book.currentPage)"
    }
}

struct QuoteWidget: Widget {
    let kind = "QuoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuoteProvider()) { entry in
            QuoteWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    if entry.quote == nil && entry.book == nil { Color.clear } else { Color(uiColor: .secondarySystemBackground) }
                }
        }
        .configurationDisplayName("Reading & Quote")
        .description("The book you're reading, with a favourite line from your Quote Vault.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}
