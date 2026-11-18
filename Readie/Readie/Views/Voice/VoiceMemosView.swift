// VoiceMemosView.swift
import SwiftUI
import SwiftData

struct VoiceMemosView: View {
    var book: Book? = nil

    @Environment(\.modelContext) private var context
    @Query(sort: \VoiceMemo.createdAt, order: .reverse) private var allMemos: [VoiceMemo]
    @State private var showRecord = false
    @State private var summary: String?
    @State private var isSummarizing = false

    private var memos: [VoiceMemo] { allMemos.filter { book == nil || $0.book?.id == book?.id } }

    var body: some View {
        List {
            if memos.count > 1 {
                Section("Summary") {
                    Button {
                        Task {
                            isSummarizing = true
                            summary = await SummaryService.summarize(memos.map(\.transcript))
                            isSummarizing = false
                        }
                    } label: {
                        if isSummarizing { ProgressView() } else { Label("Summarize all notes", systemImage: "sparkles") }
                    }
                    .disabled(isSummarizing)
                    if let summary { Text(summary) }
                }
            }
            Section {
                ForEach(memos) { memo in
                    NavigationLink { MemoDetailView(memo: memo) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(memo.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.subheadline.weight(.semibold))
                            if let title = memo.book?.title { Text(title).font(.footnote).foregroundStyle(Color.readieAccent) }
                            Text(memo.summary ?? memo.transcript).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                        }
                    }
                }
                .onDelete { $0.map { memos[$0] }.forEach(context.delete) }
            }
        }
        .navigationTitle("Voice Notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Record", systemImage: "mic.fill") { showRecord = true } }
        }
        .sheet(isPresented: $showRecord) { RecordMemoView(presetBook: book) }
        .overlay {
            if memos.isEmpty {
                ContentUnavailableView("No Voice Notes", systemImage: "mic",
                                       description: Text("Say your favourite parts out loud and Readie writes them down."))
            }
        }
    }
}

struct MemoDetailView: View {
    @Bindable var memo: VoiceMemo
    @State private var isSummarizing = false

    var body: some View {
        List {
            Section("Summary") {
                if let s = memo.summary { Text(s) } else { Text("No summary yet.").foregroundStyle(.secondary) }
                Button {
                    Task {
                        isSummarizing = true
                        memo.summary = await SummaryService.summarize([memo.transcript])
                        isSummarizing = false
                    }
                } label: {
                    if isSummarizing { ProgressView() } else { Label("Summarize", systemImage: "sparkles") }
                }
            }
            Section("Transcript") {
                TextField("Transcript", text: $memo.transcript, axis: .vertical)
            }
        }
        .navigationTitle(memo.createdAt.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RecordMemoView: View {
    var presetBook: Book? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Book.title) private var books: [Book]

    @State private var transcriber = SpeechTranscriber()
    @State private var text = ""
    @State private var duration: TimeInterval = 0
    @State private var bookID: UUID?
    @State private var finishedRecording = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if finishedRecording {
                    Form {
                        Section("Transcript") { TextField("Transcript", text: $text, axis: .vertical).lineLimit(4...12) }
                        Section {
                            Picker("Book", selection: $bookID) {
                                Text("None").tag(UUID?.none)
                                ForEach(books) { Text($0.title).tag(Optional($0.id)) }
                            }
                        }
                    }
                } else {
                    ScrollView {
                        Text(transcriber.transcript.isEmpty ? String(localized: "Tap the microphone and read your favourite part out loud.")
                                                            : transcriber.transcript)
                            .foregroundStyle(transcriber.transcript.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    if transcriber.status == .denied {
                        Text("Allow Microphone and Speech Recognition in Settings to record voice notes.")
                            .font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center).padding(.horizontal)
                    } else if transcriber.status == .unavailable {
                        Text("Speech recognition isn't available right now.")
                            .font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
                    }
                    Button {
                        if transcriber.status == .recording {
                            let r = transcriber.stop()
                            text = r.text; duration = r.duration; finishedRecording = true
                        } else {
                            Task { await transcriber.start() }
                        }
                    } label: {
                        Image(systemName: transcriber.status == .recording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 34)).frame(width: 84, height: 84)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .tint(transcriber.status == .recording ? .red : .readieButton)
                    .accessibilityLabel(transcriber.status == .recording ? "Stop recording" : "Start recording")
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Voice Note")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { bookID = presetBook?.id }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { _ = transcriber.stop(); dismiss() }
                }
                if finishedRecording {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(transcriber.status == .recording)
    }

    private func save() {
        let memo = VoiceMemo(transcript: text, duration: duration, book: books.first { $0.id == bookID })
        context.insert(memo)
        let transcript = text
        Task { memo.summary = await SummaryService.summarize([transcript]) }
        dismiss()
    }
}
