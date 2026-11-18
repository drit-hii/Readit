// ReadieApp.swift
import SwiftUI
import SwiftData

@main
struct ReadieApp: App {
    @State private var timer = ReadingTimer()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(timer)
                .environment(router)
                .tint(.readieAccent)
        }
        .modelContainer(for: [Book.self, ReadingSession.self, Quote.self, VoiceMemo.self])
    }
}
