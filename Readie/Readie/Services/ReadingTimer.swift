// ReadingTimer.swift
import Foundation
import ActivityKit
import Observation

@Observable @MainActor
final class ReadingTimer {
    enum Phase: String { case idle, running, paused }

    private(set) var phase: Phase = .idle
    private(set) var bookID: UUID?

    private var accumulated: TimeInterval = 0
    private var resumedAt: Date?
    private var activity: Activity<ReadingActivityAttributes>?
    private let defaults = UserDefaults.standard

    init() { restore() }

    func elapsed(at date: Date = .now) -> TimeInterval {
        accumulated + (resumedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }

    func start(bookID: UUID?, title: String, author: String) {
        guard phase == .idle else { return }
        self.bookID = bookID
        accumulated = 0
        resumedAt = .now
        phase = .running
        persist()
        beginActivity(title: title.isEmpty ? String(localized: "Reading") : title)
    }

    func setBook(_ id: UUID?) {
        bookID = id
        persist()
    }

    func pause() {
        guard phase == .running else { return }
        accumulated = elapsed()
        resumedAt = nil
        phase = .paused
        persist()
        updateActivity()
    }

    func resume() {
        guard phase == .paused else { return }
        resumedAt = .now
        phase = .running
        persist()
        updateActivity()
    }

    /// Ends the session and returns the total time read.
    @discardableResult
    func finish() -> TimeInterval {
        let total = elapsed()
        reset()
        return total
    }

    func reset() {
        let current = activity
        Task { await current?.end(nil, dismissalPolicy: .immediate) }
        activity = nil
        phase = .idle
        accumulated = 0
        resumedAt = nil
        bookID = nil
        persist()
    }

    // MARK: Live Activity

    private func state() -> ReadingActivityAttributes.ContentState {
        let start = Date.now.addingTimeInterval(-elapsed())
        return .init(startDate: start, pausedAt: phase == .paused ? .now : nil)
    }

    private func beginActivity(title: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // The quote is only included when the reader actually has a favourite.
        let favourite = SharedStore.loadFavourites().randomElement()
        let attributes = ReadingActivityAttributes(
            bookTitle: title,
            quote: favourite?.text,
            quoteSource: favourite?.source
        )
        activity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state(), staleDate: nil),
            pushType: nil
        )
    }

    private func updateActivity() {
        guard let activity else { return }
        let content = ActivityContent(state: state(), staleDate: nil)
        Task { await activity.update(content) }
    }

    // MARK: Persistence (survives the app being killed mid-session)

    private func persist() {
        defaults.set(phase.rawValue, forKey: "timer.phase")
        defaults.set(accumulated, forKey: "timer.accumulated")
        defaults.set(resumedAt, forKey: "timer.resumedAt")
        defaults.set(bookID?.uuidString, forKey: "timer.bookID")
    }

    private func restore() {
        guard let raw = defaults.string(forKey: "timer.phase"),
              let saved = Phase(rawValue: raw), saved != .idle else { return }
        phase = saved
        accumulated = defaults.double(forKey: "timer.accumulated")
        resumedAt = defaults.object(forKey: "timer.resumedAt") as? Date
        bookID = defaults.string(forKey: "timer.bookID").flatMap(UUID.init)
        activity = Activity<ReadingActivityAttributes>.activities.first
    }
}

@Observable @MainActor
final class AppRouter {
    var showSession = false
}
