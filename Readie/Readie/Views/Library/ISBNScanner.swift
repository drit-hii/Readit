// ISBNScanner.swift
// Scan the barcode on the back of a book and look it up on Google Books.
import SwiftUI
import Vision
import VisionKit

struct FoundBook: Equatable {
    let title: String
    let author: String
    let pages: Int?
}

struct LookupFailed: Error {}

/// Looks the ISBN up on Google Books, then on Open Library when Google doesn't know it.
/// Returns nil when neither has the book; throws only when neither could be reached.
func lookUpBook(isbn: String) async throws -> FoundBook? {
    guard isbn.allSatisfy(\.isNumber) else { return nil }   // only digits reach the URLs
    let google = try? await googleBooks(isbn: isbn)
    if let found = google ?? nil { return found }
    let openLibrary = try? await openLibrary(isbn: isbn)
    if let found = openLibrary ?? nil { return found }
    if google == nil && openLibrary == nil { throw LookupFailed() }
    return nil
}

private func fetch(_ url: URL) async throws -> Data {
    let (data, response) = try await URLSession.shared.data(from: url)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw LookupFailed() }
    return data
}

private func found(_ title: String?, _ authors: [String]?, _ pages: Int?) -> FoundBook? {
    guard let title, !title.isEmpty else { return nil }
    return FoundBook(title: title, author: authors?.joined(separator: ", ") ?? "", pages: pages.flatMap { $0 > 0 ? $0 : nil })
}

private func googleBooks(isbn: String) async throws -> FoundBook? {
    struct Response: Decodable {
        struct Item: Decodable { let volumeInfo: Info }
        struct Info: Decodable { let title: String?; let authors: [String]?; let pageCount: Int? }
        let items: [Item]?
    }
    // googleBooksAPIKey lives in Secrets.swift, which is git-ignored (see Secrets.swift.example).
    let key = googleBooksAPIKey.isEmpty ? "" : "&key=\(googleBooksAPIKey)"
    let data = try await fetch(URL(string: "https://www.googleapis.com/books/v1/volumes?q=isbn:\(isbn)\(key)")!)
    let info = (try? JSONDecoder().decode(Response.self, from: data))?.items?.first?.volumeInfo
    return found(info?.title, info?.authors, info?.pageCount)
}

private func openLibrary(isbn: String) async throws -> FoundBook? {
    struct Book: Decodable {
        struct Author: Decodable { let name: String }
        let title: String?
        let authors: [Author]?
        let number_of_pages: Int?
    }
    let data = try await fetch(URL(string: "https://openlibrary.org/api/books?bibkeys=ISBN:\(isbn)&format=json&jscmd=data")!)
    let book = (try? JSONDecoder().decode([String: Book].self, from: data))?["ISBN:\(isbn)"]
    return found(book?.title, book?.authors?.map(\.name), book?.number_of_pages)
}

/// Book barcodes are EAN-13 starting with 978/979 (the ISBN).
func isbn(fromBarcode payload: String) -> String? {
    let digits = payload.filter(\.isNumber)
    return digits.count == 13 && (digits.hasPrefix("978") || digits.hasPrefix("979")) ? digits : nil
}

/// Camera view that reports the first book barcode it sees.
struct ISBNScanner: UIViewControllerRepresentable {
    var onISBN: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.ean13])],
                                           qualityLevel: .balanced, isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        context.coordinator.onISBN = onISBN
        if !vc.isScanning { try? vc.startScanning() }
    }

    static func dismantleUIViewController(_ vc: DataScannerViewController, coordinator: Coordinator) {
        vc.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onISBN: onISBN) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onISBN: (String) -> Void
        init(onISBN: @escaping (String) -> Void) { self.onISBN = onISBN }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for case .barcode(let code) in addedItems {
                if let isbn = code.payloadStringValue.flatMap(isbn(fromBarcode:)) { onISBN(isbn); return }
            }
        }
    }
}

/// Sheet: camera, then lookup. Calls `onFound` and closes when the book is identified.
struct ScanBookView: View {
    @Environment(\.dismiss) private var dismiss
    var onFound: (FoundBook) -> Void

    @State private var isLooking = false
    @State private var notFound: String?
    @State private var failed = false

    private var supported: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if supported {
                    ISBNScanner { code in
                        guard !isLooking else { return }
                        isLooking = true
                        notFound = nil
                        failed = false
                        Task {
                            do {
                                if let book = try await lookUpBook(isbn: code) {
                                    onFound(book)
                                    dismiss()
                                    return
                                }
                                notFound = code
                            } catch {
                                failed = true
                            }
                            isLooking = false
                        }
                    }
                    .ignoresSafeArea()
                } else {
                    ContentUnavailableView("Scanner Unavailable", systemImage: "barcode.viewfinder",
                                           description: Text("Allow camera access in Settings, or add the book manually."))
                }

                if supported {
                    Group {
                        if isLooking {
                            ProgressView("Looking up the book…")
                        } else if failed {
                            Text("Couldn't reach Google Books. Check your connection and scan again, or add the book manually.")
                        } else if let notFound {
                            VStack(spacing: 10) {
                                Text("No book found for ISBN \(notFound).")
                                Button("Add It Manually") {
                                    onFound(FoundBook(title: "", author: "", pages: nil))
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.readieButton)
                            }
                        } else {
                            Text("Point the camera at the barcode on the back of a book.")
                        }
                    }
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding()
                }
            }
            .navigationTitle("Scan a Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
