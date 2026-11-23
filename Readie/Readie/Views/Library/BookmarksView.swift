// BookmarksView.swift
// One collectible bookmark per finished book.
import SwiftUI
import SwiftData

/// Ribbon with a V notch at the bottom.
struct BookmarkShape: Shape {
    func path(in r: CGRect) -> Path {
        let notch = r.width * 0.35
        let corner = min(4, r.width * 0.08)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + corner))
        p.addQuadCurve(to: CGPoint(x: r.minX + corner, y: r.minY), control: r.origin)
        p.addLine(to: CGPoint(x: r.maxX - corner, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + corner), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY - notch))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct Bookmark: View {
    let book: Book
    var width: CGFloat = 46
    var height: CGFloat = 108

    private static let crimson = Color(red: 0.62, green: 0.08, blue: 0.12)
    private static let maroon = Color(red: 0.36, green: 0.04, blue: 0.08)
    private static let cream = Color(red: 0.93, green: 0.89, blue: 0.82)
    private static let blush = Color(red: 0.97, green: 0.80, blue: 0.82)
    private static let rose = Color(red: 0.84, green: 0.45, blue: 0.48)

    var body: some View {
        let seed = Book.stableSeed(book.title)
        Canvas { ctx, size in draw(seed % 6, in: &ctx, size: size) }
            .frame(width: width, height: height)
            .clipShape(BookmarkShape())
            .overlay(BookmarkShape().stroke(.white.opacity(0.5), lineWidth: 1))
            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Bookmark for \(book.title)")
    }

    private func draw(_ pattern: Int, in ctx: inout GraphicsContext, size: CGSize) {
        let all = CGRect(origin: .zero, size: size)
        switch pattern {
        case 0: // checkerboard
            ctx.fill(Path(all), with: .color(Self.cream))
            let cell = size.width / 3
            for row in 0..<Int(size.height / cell) + 1 {
                for col in 0..<3 where (row + col) % 2 == 0 {
                    let x = CGFloat(col) * cell + (row % 2 == 0 ? 0 : cell * 0.25)
                    ctx.fill(Path(CGRect(x: x, y: CGFloat(row) * cell, width: cell, height: cell)), with: .color(Self.crimson))
                }
            }
        case 1: // contour lines
            ctx.fill(Path(all), with: .color(Self.crimson))
            for i in 0..<12 {
                var p = Path()
                let y0 = CGFloat(i) * size.height / 10
                p.move(to: CGPoint(x: 0, y: y0))
                p.addCurve(to: CGPoint(x: size.width, y: y0 + 12),
                           control1: CGPoint(x: size.width * 0.3, y: y0 - 14),
                           control2: CGPoint(x: size.width * 0.7, y: y0 + 22))
                ctx.stroke(p, with: .color(Self.blush.opacity(0.7)), lineWidth: 0.8)
            }
        case 2: // flower
            ctx.fill(Path(all), with: .color(Self.rose))
            let c = CGPoint(x: size.width / 2, y: size.height * 0.4)
            let r = size.width * 0.75
            for k in 0..<6 {
                let a = Double(k) * .pi / 3
                let petal = CGRect(x: c.x + cos(a) * r * 0.55 - r / 2, y: c.y + sin(a) * r * 0.55 - r / 2, width: r, height: r)
                ctx.fill(Path(ellipseIn: petal), with: .color(Self.crimson))
                ctx.stroke(Path(ellipseIn: petal), with: .color(Self.blush), lineWidth: 1)
            }
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)), with: .color(Self.blush))
        case 3: // soft waves
            ctx.fill(Path(all), with: .color(Self.blush))
            for (i, color) in [Self.rose, Self.maroon].enumerated() {
                var p = Path()
                let x0 = size.width * (0.45 + CGFloat(i) * 0.25)
                p.move(to: CGPoint(x: x0, y: 0))
                p.addCurve(to: CGPoint(x: x0, y: size.height),
                           control1: CGPoint(x: x0 - 22, y: size.height * 0.35),
                           control2: CGPoint(x: x0 + 22, y: size.height * 0.65))
                p.addLine(to: CGPoint(x: size.width, y: size.height))
                p.addLine(to: CGPoint(x: size.width, y: 0))
                ctx.fill(p, with: .color(color))
            }
        case 4: // swirl rings
            ctx.fill(Path(all), with: .color(Self.cream))
            let c = CGPoint(x: size.width * 0.6, y: size.height * 0.3)
            for i in stride(from: 10, through: 1, by: -1) {
                let r = CGFloat(i) * 9
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                         with: .color(i % 2 == 0 ? Self.crimson : Self.cream))
            }
        default: // blobs
            ctx.fill(Path(all), with: .color(Self.maroon))
            for (x, y, r) in [(0.2, 0.15, 0.45), (0.9, 0.5, 0.5), (0.1, 0.8, 0.4)] {
                let rr = size.width * r
                ctx.fill(Path(ellipseIn: CGRect(x: size.width * x - rr, y: size.height * y - rr, width: rr * 2, height: rr * 2)),
                         with: .color(Self.blush))
            }
        }
    }
}

/// All collected bookmarks, opened from the Library's "collected" link.
struct BookmarksView: View {
    @Query(filter: #Predicate<Book> { $0.statusRaw == "read" }, sort: \Book.addedAt, order: .reverse)
    private var finished: [Book]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 16)], spacing: 20) {
                ForEach(finished) { book in
                    NavigationLink(value: book) {
                        VStack(spacing: 8) {
                            Bookmark(book: book, width: 56, height: 132)
                            Text(book.title).font(.caption).lineLimit(2).multilineTextAlignment(.center)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Bookmarks")
        .overlay {
            if finished.isEmpty {
                ContentUnavailableView("No Bookmarks Yet", systemImage: "bookmark",
                                       description: Text("Finish a book to collect its bookmark."))
            }
        }
    }
}
