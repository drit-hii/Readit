// BookPickerView.swift
import SwiftUI
import SwiftData

/// Add a book: scan its barcode, or type it in.
struct BookPickerView: View {
    @Environment(\.dismiss) private var dismiss

    var defaultStatus: ReadingStatus = .reading
    @State private var showManual = false
    @State private var showScanner = false
    @State private var scanned: FoundBook?

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Add a Book", systemImage: "books.vertical.fill")
            } description: {
                Text("Scan the barcode on the back of the book, or type in its title.")
            } actions: {
                Button("Scan Barcode", systemImage: "barcode.viewfinder") { scanned = nil; showScanner = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.readieButton)
                    .controlSize(.large)
                Button("Add Manually", systemImage: "square.and.pencil") { scanned = nil; showManual = true }
                    .controlSize(.large)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .sheet(isPresented: $showManual) { ManualBookView(defaultStatus: defaultStatus, prefill: scanned) { dismiss() } }
            // The scanned book opens pre-filled in the manual form, so title/author/pages can be checked before adding.
            .sheet(isPresented: $showScanner, onDismiss: { if scanned != nil { showManual = true } }) {
                ScanBookView { scanned = $0 }
            }
        }
        .presentationDetents([.medium])
    }
}

struct ManualBookView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var defaultStatus: ReadingStatus
    var prefill: FoundBook? = nil
    var onSaved: () -> Void

    @State private var title = ""
    @State private var author = ""
    @State private var pages: Int?
    @State private var status: ReadingStatus = .reading

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                    TextField("Pages (optional)", value: $pages, format: .number).keyboardType(.numberPad)
                }
                Section {
                    Picker("Status", selection: $status) {
                        ForEach(ReadingStatus.allCases) { Text($0.title).tag($0) }
                    }
                }
            }
            .navigationTitle("New Book")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                status = defaultStatus
                if let prefill { title = prefill.title; author = prefill.author; pages = prefill.pages }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        context.insert(Book(title: title.trimmingCharacters(in: .whitespaces),
                                            author: author.trimmingCharacters(in: .whitespaces),
                                            pageCount: pages ?? 0, status: status))
                        dismiss(); onSaved()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
