// RootView.swift
import SwiftUI
import SwiftData

struct RootView: View {
    enum Tab: Hashable { case home, library }

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @State private var selection: Tab = .home

    @Query(filter: #Predicate<Quote> { $0.isFavourite }, sort: \Quote.createdAt, order: .reverse)
    private var favourites: [Quote]

    var body: some View {
        @Bindable var router = router

        // Native TabView: on iOS 26 this renders the floating Liquid Glass tab bar from the mockups.
        ZStack {
            TabView(selection: $selection) {
                SwiftUI.Tab("Home", systemImage: "house.fill", value: Tab.home) { HomeView() }
                SwiftUI.Tab("Library", systemImage: "books.vertical.fill", value: Tab.library) { LibraryView() }
            }
            .accessibilityHidden(router.showSession)

            // Overlay instead of fullScreenCover so the session slides in from the right like a push.
            if router.showSession {
                ReadingSessionView()
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
            }
        }
        .animation(.smooth(duration: 0.35), value: router.showSession)
        // Keep the widget's favourite quotes in sync with the vault.
        .onAppear {
            SharedStore.saveFavourites(favourites.map(\.shared))
            // "Want to read" was removed: move those books to "Currently reading".
            let old = (try? context.fetch(FetchDescriptor<Book>(predicate: #Predicate { $0.statusRaw == "wantToRead" }))) ?? []
            old.forEach { $0.statusRaw = ReadingStatus.reading.rawValue }
        }
        .onChange(of: favourites.map(\.shared)) { _, new in SharedStore.saveFavourites(new) }
    }
}
