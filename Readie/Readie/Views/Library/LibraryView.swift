// LibraryView.swift
import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \Book.addedAt, order: .reverse) private var books: [Book]
    @Query private var quotes: [Quote]
    @Query private var memos: [VoiceMemo]
    @State private var showPicker = false

    private func books(_ s: ReadingStatus) -> [Book] { books.filter { $0.status == s } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Card {
                        VStack(alignment: .leading, spacing: 24) {
                            readingShelf
                            spineShelf(.read)
                        }
                        .padding(16)
                    }

                    bookmarks

                    Card {
                        VStack(spacing: 0) {
                            NavigationLink { QuoteVaultView() } label: {
                                row("Quote Vault", icon: "quote.opening", count: quotes.count)
                            }
                            Divider().padding(.leading, 56)
                            NavigationLink { VoiceMemosView() } label: {
                                row("Voice Notes", icon: "mic.fill", count: memos.count)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Book", systemImage: "plus") { showPicker = true }
                        .buttonStyle(.borderedProminent)
                        .tint(.readieButton)
                }
            }
            .navigationDestination(for: Book.self) { BookDetailView(book: $0) }
            .sheet(isPresented: $showPicker) { BookPickerView(defaultStatus: .reading) }
        }
    }

    private func row(_ title: LocalizedStringKey, icon: String, count: Int) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(Color.readieAccent).frame(width: 28)
            Text(title).font(.body)
            Spacer()
            Text("\(count)").foregroundStyle(.secondary)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    private func header(_ status: ReadingStatus) -> some View {
        let count = books(status).count
        return HStack {
            Text(status.title).font(.title3.weight(.semibold))
            Spacer()
            NavigationLink { BookListView(status: status) } label: {
                HStack(spacing: 4) {
                    Text("^[\(count) book](inflect: true)")
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                }
                .font(.subheadline)
                .foregroundStyle(Color.readieAccent)
            }
        }
    }

    private var bookmarks: some View {
        let finished = books(.read)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Bookmarks").font(.title3.weight(.semibold))
                Spacer()
                NavigationLink { BookmarksView() } label: {
                    HStack(spacing: 4) {
                        Text("\(finished.count) collected")
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.readieAccent)
                }
            }
            if finished.isEmpty {
                Text("Finish a book to collect its bookmark.").font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 90)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(finished) { book in
                            NavigationLink(value: book) { Bookmark(book: book) }.buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollClipDisabled()
            }
        }
        .padding(.horizontal, 4)
    }

    private var readingShelf: some View {
        VStack(alignment: .leading, spacing: 10) {
            header(.reading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(books(.reading)) { book in
                        NavigationLink(value: book) {
                            VStack(spacing: 8) {
                                BookCover(book: book)
                                ProgressView(value: book.progress)
                                    .tint(Color.readieAccent)
                                    .frame(width: 140)
                                    .accessibilityLabel("Progress")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Button { showPicker = true } label: {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color(.tertiaryLabel), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay { Image(systemName: "plus").font(.title.weight(.light)).foregroundStyle(.secondary) }
                            .frame(width: 140, height: 188)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add a book")
                }
                .padding(.vertical, 4)
            }
            ShelfBoard()
        }
    }

    private func spineShelf(_ status: ReadingStatus) -> some View {
        let list = books(status)
        return VStack(alignment: .leading, spacing: 10) {
            header(status)
            if list.isEmpty {
                Text("No books yet").font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 90)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(list) { book in
                            NavigationLink(value: book) {
                                BookSpine(color: book.spineColor, width: book.spineWidth, height: book.spineHeight,
                                          showsLabel: Book.stableSeed(book.title) % 2 == 0)
                                    .frame(minWidth: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(book.title), \(book.author)")
                        }
                    }
                    .padding(.top, 4)
                }
            }
            ShelfBoard()
        }
    }
}

struct BookListView: View {
    let status: ReadingStatus
    @Environment(\.modelContext) private var context
    @Query(sort: \Book.addedAt, order: .reverse) private var all: [Book]

    var body: some View {
        let list = all.filter { $0.status == status }
        List {
            ForEach(list) { book in
                NavigationLink(value: book) {
                    HStack(spacing: 14) {
                        BookSpine(color: book.spineColor, width: 28, height: 56, showsLabel: false)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.title).font(.headline)
                            Text(book.author).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete { offsets in offsets.map { list[$0] }.forEach(context.delete) }
        }
        .navigationTitle(status.title)
        .overlay {
            if list.isEmpty {
                ContentUnavailableView("No Books", systemImage: "books.vertical",
                                       description: Text("Books you add will appear here."))
            }
        }
    }
}
