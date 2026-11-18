// Stats.swift
import Foundation

struct DayStat: Identifiable {
    let date: Date
    let seconds: TimeInterval
    let pages: Int
    var id: Date { date }
    var minutes: Int { Int(seconds / 60) }
    func value(_ kind: GoalKind) -> Int { kind == .minutes ? minutes : pages }
}

enum Stats {
    static func lastDays(_ n: Int = 7, sessions: [ReadingSession],
                         now: Date = .now, calendar: Calendar = .current) -> [DayStat] {
        let today = calendar.startOfDay(for: now)
        return (0..<n).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let daily = sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
            return DayStat(date: day,
                           seconds: daily.reduce(0) { $0 + $1.duration },
                           pages: daily.reduce(0) { $0 + $1.pages })
        }
    }

    /// Consecutive days with any reading, counting back from today (or yesterday if today is empty).
    static func streak(sessions: [ReadingSession], now: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(sessions.map { calendar.startOfDay(for: $0.startedAt) })
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return count
    }

    /// Average on previous days that had reading ("Your usual is about 29 min").
    static func usual(_ days: [DayStat], kind: GoalKind) -> Int? {
        let values = days.dropLast().map { $0.value(kind) }.filter { $0 > 0 }
        guard !values.isEmpty else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }
}

func clock(_ t: TimeInterval) -> String {
    let s = max(Int(t), 0)
    let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
}
