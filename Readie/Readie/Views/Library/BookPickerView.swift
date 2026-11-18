// BookPickerView.swift
import SwiftUI
import SwiftData

struct BookPickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var existing: [Book]

    var defaultStatus: ReadingStatus = .reading
    @State private var query = ""
    @State private var selected: CatalogBook?
    @State private var showManual = false

    private var results: [CatalogBook] { CatalogStore.shared.search(query) }

    var body: some View {
        NavigationStack {
            List(results) { book in
                let inLibrary = existing.contains { $0.catalogID == book.id }
                Button {
                    if !inLibrary { selected = book }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.title).font(.headline).foregroundStyle(.primary)
                            Text(book.author).font(.subheadline).foregroundStyle(.secondary)
                            if let pages = book.pages {
                                Text("\(pages) pages").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        if inLibrary {
                            Label("In library", systemImage: "checkmark.circle.fill")
                                .labelStyle(.iconOnly).foregroundStyle(Color.readieAccent)
                                .accessibilityLabel("Already in your library")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .searchable(text: $query, prompt: "Title or author")
            .navigationTitle("Add a Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Add Manually") { showManual = true } }
            }
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView {
                        Label("No Results", systemImage: "magnifyingglass")
                    } description: {
                        Text("Can't find it? Add it yourself.")
                    } actions: {
                        Button("Add Manually") { showManual = true }
                    }
                }
            }
            .confirmationDialog("Add to your library", isPresented: Binding(get: { selected != nil },
                                                                            set: { if !$0 { selected = nil } }),
                                titleVisibility: .visible, presenting: selected) { book in
                Button("Start reading") { add(book, .reading) }
                Button("Want to read") { add(book, .wantToRead) }
                Button("Already read") { add(book, .read) }
                Button("Cancel", role: .cancel) {}
            } message: { Text($0.title) }
            .sheet(isPresented: $showManual) { ManualBookView(defaultStatus: defaultStatus) { dismiss() } }
        }
    }

    private func add(_ book: CatalogBook, _ status: ReadingStatus) {
        context.insert(Book(title: book.title, author: book.author, pageCount: book.pages ?? 0,
                            status: status, catalogID: book.id))
        dismiss()
    }
}

struct ManualBookView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var defaultStatus: ReadingStatus
    var onSaved: () -> Void

    @State private var title = ""
    @State private var author = ""
    @State private var pages: Int?
    @State private var status: ReadingStatus = .wantToRead

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
            .onAppear { status = defaultStatus }
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
