// RootView.swift
import SwiftUI
import SwiftData

struct RootView: View {
    enum Tab: Hashable { case home, library }

    @Environment(AppRouter.self) private var router
    @State private var selection: Tab = .home

    @Query(filter: #Predicate<Quote> { $0.isFavourite }, sort: \Quote.createdAt, order: .reverse)
    private var favourites: [Quote]

    var body: some View {
        @Bindable var router = router

        // Native TabView: on iOS 26 this renders the floating Liquid Glass tab bar from the mockups.
        TabView(selection: $selection) {
            SwiftUI.Tab("Home", systemImage: "house.fill", value: Tab.home) { HomeView() }
            SwiftUI.Tab("Library", systemImage: "books.vertical.fill", value: Tab.library) { LibraryView() }
        }
        .fullScreenCover(isPresented: $router.showSession) { ReadingSessionView() }
        // Keep the widget's favourite quotes in sync with the vault.
        .onAppear { SharedStore.saveFavourites(favourites.map(\.shared)) }
        .onChange(of: favourites.map(\.shared)) { _, new in SharedStore.saveFavourites(new) }
    }
}
