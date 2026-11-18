// Theme.swift
import SwiftUI

extension Color {
    /// Terracotta accent from the mockups. Lightens in Dark Mode to keep contrast.
    static let readieAccent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.85, green: 0.58, blue: 0.51, alpha: 1)
            : UIColor(red: 0.58, green: 0.33, blue: 0.28, alpha: 1)
    })
    /// Fixed fill for the prominent button (white label stays readable in both modes).
    static let readieButton = Color(red: 0.58, green: 0.33, blue: 0.28)

    static let spinePalette: [Color] = [
        Color(red: 0.54, green: 0.60, blue: 0.48), // sage
        Color(red: 0.42, green: 0.51, blue: 0.59), // slate
        Color(red: 0.72, green: 0.61, blue: 0.37), // mustard
        Color(red: 0.49, green: 0.35, blue: 0.39), // plum
        Color(red: 0.61, green: 0.54, blue: 0.72), // lavender
        Color(red: 0.66, green: 0.39, blue: 0.31)  // terracotta
    ]

    func darker(_ amount: Double) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: r * (1 - amount), green: g * (1 - amount), blue: b * (1 - amount))
    }
}

/// Rounded content card with a soft shadow (solid surface, per HIG: glass is for controls/navigation).
struct Card<Content: View>: View {
    var fill: Color = Color(.secondarySystemGroupedBackground)
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .background(fill, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 6)
    }
}

/// A book standing on a shelf, seen from the spine.
struct BookSpine: View {
    let color: Color
    var width: CGFloat = 40
    var height: CGFloat
    var showsLabel: Bool = true

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(LinearGradient(colors: [color, color.darker(0.14)], startPoint: .leading, endPoint: .trailing))
            .overlay(alignment: .top) { band.padding(.top, 8) }
            .overlay(alignment: .bottom) { band.padding(.bottom, 8) }
            .overlay {
                if showsLabel && height >= 70 {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color(red: 0.93, green: 0.90, blue: 0.83))
                        .frame(width: width * 0.6, height: min(26, height * 0.2))
                }
            }
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)
            .accessibilityHidden(true)
    }

    private var band: some View {
        Rectangle().fill(Color(red: 0.86, green: 0.82, blue: 0.68)).frame(height: 1.5)
    }
}

struct ShelfBoard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(LinearGradient(colors: [Color(.systemBackground).opacity(0.9), Color(.tertiaryLabel).opacity(0.35)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(height: 6)
            .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
            .accessibilityHidden(true)
    }
}

/// Cover used for "Currently reading".
struct BookCover: View {
    let book: Book
    var width: CGFloat = 140
    var height: CGFloat = 188

    var body: some View {
        let base = Color.spinePalette[book.colorIndex % Color.spinePalette.count].darker(0.3)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: [base, base.darker(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Rectangle().fill(.black.opacity(0.18)).frame(width: 7)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title).font(.headline).foregroundStyle(.white).lineLimit(4)
                Spacer(minLength: 0)
                Text(book.author).font(.caption).foregroundStyle(.white.opacity(0.85)).lineLimit(2)
            }
            .padding(.init(top: 16, leading: 20, bottom: 14, trailing: 10))
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(book.title), \(book.author)")
    }
}

extension Book {
    /// Deterministic spine dimensions so the shelf looks the same every launch.
    var spineHeight: CGFloat { [118, 98, 138, 112, 150, 106, 142, 110][Book.stableSeed(title) % 8] }
    var spineWidth: CGFloat { [46, 38, 50, 42, 54, 38, 48, 42][(Book.stableSeed(title) / 3) % 8] }
    var spineColor: Color { Color.spinePalette[colorIndex % Color.spinePalette.count] }
}
