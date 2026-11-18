// QuoteVaultView.swift
import SwiftUI
import SwiftData

struct QuoteVaultView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all, favourites
        var id: String { rawValue }
        var title: LocalizedStringKey { self == .all ? "All" : "Favourites" }
    }

    var book: Book? = nil

    @Environment(\.modelContext) private var context
    @Query(sort: \Quote.createdAt, order: .reverse) private var quotes: [Quote]
    @State private var search = ""
    @State private var filter: Filter = .all
    @State private var showAdd = false

    private var visible: [Quote] {
        quotes.filter { q in
            (book == nil || q.book?.id == book?.id)
            && (filter == .all || q.isFavourite)
            && (search.isEmpty
                || q.text.localizedStandardContains(search)
                || q.author.localizedStandardContains(search)
                || (q.book?.title.localizedStandardContains(search) ?? false))
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Show", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }
            ForEach(visible) { quote in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text("“\(quote.text)”").font(.body).fontDesign(.serif)
                        Spacer(minLength: 8)
                        if quote.isFavourite {
                            Image(systemName: "star.fill").foregroundStyle(Color.readieAccent)
                                .accessibilityLabel("Favourite")
                        }
                    }
                    if !quote.sourceLine.isEmpty {
                        Text(quote.sourceLine).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .leading) {
                    Button { quote.isFavourite.toggle() } label: {
                        Label(quote.isFavourite ? "Unfavourite" : "Favourite", systemImage: "star")
                    }
                    .tint(.readieButton)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { context.delete(quote) } label: { Label("Delete", systemImage: "trash") }
                }
                .contextMenu {
                    Button { quote.isFavourite.toggle() } label: {
                        Label(quote.isFavourite ? "Unfavourite" : "Favourite", systemImage: "star")
                    }
                    ShareLink(item: "“\(quote.text)” — \(quote.sourceLine)")
                }
            }
        }
        .navigationTitle("Quote Vault")
        .searchable(text: $search, prompt: "Search quotes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Add Quote", systemImage: "plus") { showAdd = true } }
        }
        .sheet(isPresented: $showAdd) { AddQuoteView(presetBook: book) }
        .overlay {
            if quotes.isEmpty {
                ContentUnavailableView("No Quotes Yet", systemImage: "quote.opening",
                                       description: Text("Save lines you love. Star one to show it on your Lock Screen."))
            } else if visible.isEmpty {
                ContentUnavailableView.search
            }
        }
    }
}

struct AddQuoteView: View {
    var presetBook: Book? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Book.title) private var books: [Book]

    @State private var text = ""
    @State private var author = ""
    @State private var page: Int?
    @State private var bookID: UUID?
    @State private var favourite = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Quote") {
                    TextField("Type or paste the quote", text: $text, axis: .vertical).lineLimit(3...10)
                }
                Section {
                    Picker("Book", selection: $bookID) {
                        Text("None").tag(UUID?.none)
                        ForEach(books) { Text($0.title).tag(Optional($0.id)) }
                    }
                    TextField("Author", text: $author)
                    TextField("Page (optional)", value: $page, format: .number).keyboardType(.numberPad)
                }
                Section {
                    Toggle("Favourite", isOn: $favourite)
                } footer: {
                    Text("Favourites can appear on your Lock Screen widget and your reading timer.")
                }
            }
            .navigationTitle("New Quote")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { bookID = presetBook?.id; author = presetBook?.author ?? "" }
            .onChange(of: bookID) { _, id in
                if let b = books.first(where: { $0.id == id }) { author = b.author }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(Quote(text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                                             author: author.trimmingCharacters(in: .whitespaces),
                                             page: page, isFavourite: favourite,
                                             book: books.first { $0.id == bookID }))
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
