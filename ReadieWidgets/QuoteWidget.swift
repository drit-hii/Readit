// QuoteWidget.swift
// Shows a favourite quote. If the reader has not saved a favourite, it renders nothing.
import WidgetKit
import SwiftUI

struct QuoteEntry: TimelineEntry {
    let date: Date
    let quote: SharedQuote?
}

struct QuoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(date: .now, quote: SharedQuote(id: UUID(), text: "A favourite line from your book appears here.",
                                                   author: "Author", bookTitle: "Book"))
    }

    func getSnapshot(in context: Context, completion: @escaping (QuoteEntry) -> Void) {
        completion(QuoteEntry(date: .now, quote: context.isPreview ? placeholder(in: context).quote
                                                                   : SharedStore.loadFavourites().first))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteEntry>) -> Void) {
        let favourites = SharedStore.loadFavourites()
        let now = Date()
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
        if let quote = entry.quote {
            switch family {
            case .accessoryInline:
                Text(quote.text)
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text("“\(quote.text)”").font(.caption).lineLimit(3)
                    if !quote.source.isEmpty { Text(quote.source).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                }
            default:
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "quote.opening").foregroundStyle(accent)
                    Text(quote.text)
                        .font(.system(.body, design: .serif))
                        .minimumScaleFactor(0.7)
                        .lineLimit(family == .systemSmall ? 5 : 4)
                    Spacer(minLength: 0)
                    if !quote.source.isEmpty {
                        Text(quote.source).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        } else {
            EmptyView()
        }
    }
}

struct QuoteWidget: Widget {
    let kind = "QuoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuoteProvider()) { entry in
            QuoteWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    if entry.quote == nil { Color.clear } else { Color(uiColor: .secondarySystemBackground) }
                }
        }
        .configurationDisplayName("Favourite Quote")
        .description("A favourite line from your Quote Vault.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}
