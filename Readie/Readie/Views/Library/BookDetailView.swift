// BookDetailView.swift
import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ReadingTimer.self) private var timer
    @Environment(AppRouter.self) private var router
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    BookCover(book: book, width: 100, height: 140)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title).font(.title3.bold())
                        Text(book.author).foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.clear)
            }

            Section {
                Picker("Status", selection: $book.status) {
                    ForEach(ReadingStatus.allCases) { Text($0.title).tag($0) }
                }
                if book.pageCount > 0 {
                    Stepper(value: $book.currentPage, in: 0...book.pageCount) {
                        Text("Page \(book.currentPage) of \(book.pageCount)")
                    }
                    ProgressView(value: book.progress).tint(Color.readieAccent)
                        .accessibilityLabel("Reading progress")
                } else {
                    Stepper(value: $book.currentPage, in: 0...5000) { Text("Page \(book.currentPage)") }
                }
                LabeledContent("Time read", value: timeRead)
            }

            if book.status != .read {
                Section {
                    Button { startReading() } label: {
                        if timer.phase == .idle {
                            Label("Start Reading", systemImage: "book.fill")
                        } else if timer.bookID == book.id {
                            Label("Resume Reading", systemImage: "book.fill")
                        } else {
                            Label("Go to Current Session", systemImage: "timer")
                        }
                    }
                } footer: {
                    if timer.phase != .idle && timer.bookID != book.id {
                        Text("Finish your current session to start reading this book.")
                    }
                }
            }

            Section("Notes") {
                NavigationLink { QuoteVaultView(book: book) } label: {
                    LabeledContent("Quotes", value: "\(book.quotes.count)")
                }
                NavigationLink { VoiceMemosView(book: book) } label: {
                    LabeledContent("Voice notes", value: "\(book.memos.count)")
                }
            }

            Section {
                Button("Remove from Library", role: .destructive) { confirmDelete = true }
                    .disabled(isInSession)
            } footer: {
                if isInSession { Text("Finish the current reading session to remove this book.") }
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Remove this book?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { book.remove(from: context); dismiss() }
        } message: { Text("Your quotes and voice notes are kept.") }
    }

    private var isInSession: Bool { timer.phase != .idle && timer.bookID == book.id }

    private var timeRead: String {
        let total = book.sessions.reduce(0) { $0 + $1.duration }
        return Duration.seconds(total).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private func startReading() {
        if timer.phase == .idle { timer.start(bookID: book.id, title: book.title, author: book.author) }
        router.showSession = true
    }
}
