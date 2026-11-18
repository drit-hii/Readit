// ReadingSessionView.swift
import SwiftUI
import SwiftData

struct ReadingSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(ReadingTimer.self) private var timer
    @Environment(AppRouter.self) private var router
    @Query(sort: \Book.title) private var books: [Book]
    @Query(sort: \ReadingSession.startedAt) private var sessions: [ReadingSession]

    @AppStorage("goalKind") private var goalKind: GoalKind = .minutes
    @AppStorage("goalMinutes") private var goalMinutes = 30
    @AppStorage("goalPages") private var goalPages = 20

    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 76

    @State private var showFinish = false
    @State private var showQuote = false
    @State private var showMemo = false
    @State private var confirmDiscard = false

    private var book: Book? { books.first { $0.id == timer.bookID } }
    private var reading: [Book] { books.filter { $0.status == .reading } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                header
                Spacer(minLength: 0)
                timerDisplay
                goalLine
                Spacer(minLength: 0)
                controls
                HStack(spacing: 12) {
                    Button { showQuote = true } label: { Label("Quote", systemImage: "quote.opening") }
                    Button { showMemo = true } label: { Label("Voice note", systemImage: "mic.fill") }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Minimize", systemImage: "chevron.down") { router.showSession = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Discard", systemImage: "trash", role: .destructive) { confirmDiscard = true }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showFinish) {
            FinishSessionSheet(book: book, duration: timer.elapsed()) { pages, finishedBook in
                save(pages: pages, finishedBook: finishedBook)
            }
        }
        .sheet(isPresented: $showQuote) { AddQuoteView(presetBook: book) }
        .sheet(isPresented: $showMemo) { RecordMemoView(presetBook: book) }
        .confirmationDialog("Discard this session?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard Session", role: .destructive) { timer.reset(); router.showSession = false }
            Button("Keep Reading", role: .cancel) {}
        } message: { Text("The time you've read so far won't be saved.") }
        .onChange(of: timer.phase) { _, phase in if phase == .idle { router.showSession = false } }
    }

    private var header: some View {
        VStack(spacing: 4) {
            if reading.count > 1 {
                Menu {
                    ForEach(reading) { b in Button(b.title) { timer.setBook(b.id) } }
                } label: {
                    Label(book?.title ?? String(localized: "Choose a book"), systemImage: "chevron.up.chevron.down")
                        .font(.headline)
                }
            } else {
                Text(book?.title ?? String(localized: "Free reading")).font(.headline)
            }
            if let book { Text(book.author).font(.subheadline).foregroundStyle(.secondary) }
        }
        .multilineTextAlignment(.center)
    }

    private var timerDisplay: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            Text(clock(timer.elapsed(at: ctx.date)))
                .font(.system(size: timerSize, weight: .light, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .accessibilityLabel("Time reading")
                .accessibilityValue(spoken(timer.elapsed(at: ctx.date)))
        }
    }

    private var goalLine: some View {
        let today = Stats.lastDays(sessions: sessions).last
        let target = goalKind == .minutes ? goalMinutes : goalPages
        let done = goalKind == .minutes
            ? Int(((today?.seconds ?? 0) + timer.elapsed()) / 60)
            : (today?.pages ?? 0)
        return Text(goalKind == .minutes ? "\(done) of \(target) min today" : "\(done) of \(target) pages today")
            .font(.subheadline).foregroundStyle(.secondary)
    }

    private var controls: some View {
        HStack(spacing: 16) {
            if timer.phase == .running {
                Button { timer.pause() } label: {
                    Label("Pause", systemImage: "pause.fill").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.glass)
            } else {
                Button { timer.resume() } label: {
                    Label("Resume", systemImage: "play.fill").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.glass)
            }
            Button {
                timer.pause()
                showFinish = true
            } label: {
                Label("Finish", systemImage: "checkmark").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(.readieButton)
        }
        .controlSize(.large)
    }

    private func save(pages: Int, finishedBook: Bool) {
        let duration = timer.finish()
        if duration >= 10 || pages > 0 {
            context.insert(ReadingSession(startedAt: Date().addingTimeInterval(-duration),
                                          duration: duration, pages: pages, book: book))
        }
        if let book {
            book.currentPage += pages
            if book.pageCount > 0 { book.currentPage = min(book.currentPage, book.pageCount) }
            if finishedBook || (book.pageCount > 0 && book.currentPage >= book.pageCount) {
                book.status = .read
                if book.pageCount > 0 { book.currentPage = book.pageCount }
            }
        }
        router.showSession = false
    }

    private func spoken(_ t: TimeInterval) -> String {
        let s = Int(t)
        return "\(s / 3600) hours, \((s % 3600) / 60) minutes, \(s % 60) seconds"
    }
}

struct FinishSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let book: Book?
    let duration: TimeInterval
    var onSave: (Int, Bool) -> Void

    @State private var pages = 0
    @State private var finishedBook = false

    var body: some View {
        NavigationStack {
            Form {
                Section { LabeledContent("Time read", value: clock(duration)) }
                Section("Pages read") {
                    Stepper(value: $pages, in: 0...1000) { Text("\(pages) pages") }
                }
                if book != nil {
                    Section { Toggle("I finished this book", isOn: $finishedBook) }
                }
            }
            .navigationTitle("Session Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Back") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { dismiss(); onSave(pages, finishedBook) }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
