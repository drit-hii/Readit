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

    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 88

    @State private var showFinish = false
    @State private var showQuote = false
    @State private var showMemo = false
    @State private var confirmDiscard = false
    @State private var askRecord = false
    @State private var savedBook: Book?
    @State private var saved = false

    private var book: Book? { books.first { $0.id == timer.bookID } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer(minLength: 0)
                TimelineView(.periodic(from: .now, by: 1)) { ctx in dial(at: ctx.date) }
                Spacer(minLength: 0)
                controls
                details
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back", systemImage: "chevron.left") { router.showSession = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Discard", systemImage: "trash", role: .destructive) { confirmDiscard = true }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showFinish, onDismiss: { if saved { askRecord = true } }) {
            FinishSessionSheet(book: book, duration: timer.elapsed()) { pages, finishedBook in
                save(pages: pages, finishedBook: finishedBook)
            }
        }
        .sheet(isPresented: $showQuote, onDismiss: { router.showSession = false }) { AddQuoteView(presetBook: savedBook) }
        .sheet(isPresented: $showMemo, onDismiss: { router.showSession = false }) { RecordMemoView(presetBook: savedBook) }
        .alert("Save something from this session?", isPresented: $askRecord) {
            Button("Record a Voice Note") { showMemo = true }
            Button("Add a Quote") { showQuote = true }
            Button("Not Now", role: .cancel) { router.showSession = false }
        } message: { Text("Keep what stuck with you while it's fresh.") }
        .confirmationDialog("Discard this session?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard Session", role: .destructive) { timer.reset(); router.showSession = false }
            Button("Keep Reading", role: .cancel) {}
        } message: { Text("The time you've read so far won't be saved.") }
        .onChange(of: timer.phase) { _, phase in if phase == .idle && !saved { router.showSession = false } }
    }

    /// Seconds already read today in saved sessions.
    private var todaySeconds: TimeInterval { Stats.lastDays(sessions: sessions).last?.seconds ?? 0 }

    // MARK: Dial (Clock-style ring toward today's minutes goal)

    private func dial(at date: Date) -> some View {
        let elapsed = timer.elapsed(at: date)
        let goal = TimeInterval(max(goalMinutes, 1) * 60)
        let read = todaySeconds + elapsed
        let left = max(goal - read, 0)
        return ZStack {
            Circle().stroke(Color(.tertiarySystemFill), lineWidth: 10)
            Circle().trim(from: 0, to: min(read / goal, 1))
                .stroke(Color.readieAccent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 10) {
                Group {
                    if left == 0 {
                        Label("Goal reached", systemImage: "checkmark")
                    } else if timer.phase == .running {
                        Label(date.addingTimeInterval(left).formatted(date: .omitted, time: .shortened), systemImage: "flag.fill")
                    } else {
                        Label("Paused", systemImage: "pause.fill")
                    }
                }
                .font(.title3).foregroundStyle(.secondary)

                Text(clock(elapsed))
                    .font(.system(size: timerSize, weight: .thin))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityLabel("Time reading")
                    .accessibilityValue(spoken(elapsed))

                Text("\(Int(read / 60)) of \(goalMinutes) min today").font(.title3)
            }
            .padding(.horizontal, 36)
        }
        .frame(maxWidth: 340)
        .aspectRatio(1, contentMode: .fit)
        .animation(.smooth, value: timer.phase)
    }

    // MARK: Controls

    private var controls: some View {
        HStack {
            Button("Finish", systemImage: "checkmark") {
                timer.pause()
                showFinish = true
            }
            .buttonStyle(CircleButtonStyle(fill: Color(.tertiarySystemFill), foreground: .primary))
            Spacer()
            if timer.phase == .running {
                Button("Pause", systemImage: "pause.fill") { timer.pause() }
                    .buttonStyle(CircleButtonStyle(fill: Color.readieAccent.opacity(0.2), foreground: .readieAccent))
            } else {
                Button("Resume", systemImage: "play.fill") { timer.resume() }
                    .buttonStyle(CircleButtonStyle(fill: Color.readieAccent.opacity(0.2), foreground: .readieAccent))
            }
        }
    }

    /// Grouped card under the controls, like the Label/Sound rows in Clock.
    private var details: some View {
        @Bindable var timer = timer
        return VStack(spacing: 0) {
            HStack {
                Text(book == nil ? "Reading" : "Book")
                Spacer()
                if let book {
                    Text(book.title).foregroundStyle(.secondary).lineLimit(1)
                } else {
                    TextField("Newspaper, magazine…", text: $timer.label)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .submitLabel(.done)
                }
            }
            .padding(.horizontal, 16).frame(minHeight: 52)
            if let book, !book.author.isEmpty {
                Divider().padding(.leading, 16)
                HStack {
                    Text("Author")
                    Spacer()
                    Text(book.author).foregroundStyle(.secondary).lineLimit(1)
                }
                .padding(.horizontal, 16).frame(minHeight: 52)
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func save(pages: Int, finishedBook: Bool) {
        // Set before finish(): the phase change must not close the screen, the voice-note prompt does.
        saved = true
        savedBook = book
        let book = book
        let label = timer.label.trimmingCharacters(in: .whitespaces)
        let duration = timer.finish()
        if duration >= 10 || pages > 0 {
            context.insert(ReadingSession(startedAt: Date().addingTimeInterval(-duration),
                                          duration: duration, pages: pages, book: book,
                                          label: book == nil && !label.isEmpty ? label : nil))
        }
        if let book {
            book.currentPage += pages
            if book.pageCount > 0 { book.currentPage = min(book.currentPage, book.pageCount) }
            if finishedBook || (book.pageCount > 0 && book.currentPage >= book.pageCount) {
                book.status = .read
                if book.pageCount > 0 { book.currentPage = book.pageCount }
            }
        }
    }

    private func spoken(_ t: TimeInterval) -> String {
        let s = Int(t)
        return "\(s / 3600) hours, \((s % 3600) / 60) minutes, \(s % 60) seconds"
    }
}

/// Large round button from the Clock app: tinted disc, icon only.
struct CircleButtonStyle: ButtonStyle {
    let fill: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: 84, height: 84)
            .background(fill, in: Circle())
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Circle())
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
