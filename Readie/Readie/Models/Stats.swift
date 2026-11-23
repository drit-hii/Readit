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

    static let savesPerMonth = 2

    /// Consecutive reading days counting back from today (or yesterday if today is empty).
    /// Up to `savesPerMonth` missed days per calendar month are saved automatically and keep the streak alive.
    static func streak(sessions: [ReadingSession], now: Date = .now,
                       calendar: Calendar = .current) -> (days: Int, savesLeft: Int) {
        let readDays = Set(sessions.map { calendar.startOfDay(for: $0.startedAt) })
        let month = { (d: Date) in calendar.dateComponents([.year, .month], from: d) }
        let today = calendar.startOfDay(for: now)
        var cursor = readDays.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        var count = 0
        var used: [DateComponents: Int] = [:]
        var pending: [Date] = []   // missed days, only spent once an earlier reading day proves the streak continues
        let earliest = readDays.min() ?? today
        while cursor >= earliest {
            if readDays.contains(cursor) {
                count += 1
                for d in pending { used[month(d), default: 0] += 1 }
                pending = []
            } else {
                let m = month(cursor)
                let spent = (used[m] ?? 0) + pending.filter { month($0) == m }.count
                guard spent < savesPerMonth else { break }
                pending.append(cursor)
            }
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return (count, savesPerMonth - (used[month(today)] ?? 0))
    }

    /// Average on previous days that had reading ("Your usual is about 29 min").
    static func usual(_ days: [DayStat], kind: GoalKind) -> Int? {
        let values = days.dropLast().map { $0.value(kind) }.filter { $0 > 0 }
        guard !values.isEmpty else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }
}

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week = "W", month = "M", sixMonths = "6M", year = "Y"
    var id: Self { self }

    /// Bar size and how many bars the chart shows.
    var bucket: (unit: Calendar.Component, count: Int) {
        switch self {
        case .week: (.day, 7)
        case .month: (.day, 30)
        case .sixMonths: (.weekOfYear, 26)
        case .year: (.month, 12)
        }
    }
}

struct StatsBar: Identifiable {
    let start: Date
    let value: Double   // daily average inside the bar (minutes or pages)
    var id: Date { start }
}

struct PeriodStats {
    let bars: [StatsBar]
    let start: Date
    let total: Double
    let sessions: Int
    let average: Double          // per day, over the elapsed days of the period
    let previousAverage: Double  // same length, right before `start`

    /// Percent change vs the previous period; nil when there's nothing to compare.
    var trend: Int? {
        guard previousAverage > 0, average > 0 else { return nil }
        return Int(((average - previousAverage) / previousAverage * 100).rounded())
    }
}

extension Stats {
    static func period(_ period: StatsPeriod, kind: GoalKind, sessions: [ReadingSession],
                       now: Date = .now, calendar: Calendar = .current) -> PeriodStats {
        let (unit, count) = period.bucket
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let current = calendar.dateInterval(of: unit, for: now)!.start
        let start = calendar.date(byAdding: unit, value: -(count - 1), to: current)!
        let previousStart = calendar.date(byAdding: unit, value: -count, to: start)!

        func value(_ s: ReadingSession) -> Double { kind == .minutes ? s.duration / 60 : Double(s.pages) }
        func days(_ from: Date, _ to: Date) -> Double {
            Double(max(calendar.dateComponents([.day], from: from, to: to).day ?? 1, 1))
        }
        func inRange(_ from: Date, _ to: Date) -> [ReadingSession] {
            sessions.filter { $0.startedAt >= from && $0.startedAt < to }
        }

        let bars = (0..<count).map { i -> StatsBar in
            let barStart = calendar.date(byAdding: unit, value: i, to: start)!
            let barEnd = min(calendar.date(byAdding: unit, value: 1, to: barStart)!, end)
            let sum = inRange(barStart, barEnd).reduce(0) { $0 + value($1) }
            return StatsBar(start: barStart, value: barEnd > barStart ? sum / days(barStart, barEnd) : 0)
        }
        let inPeriod = inRange(start, end)
        let total = inPeriod.reduce(0) { $0 + value($1) }
        let previousTotal = inRange(previousStart, start).reduce(0) { $0 + value($1) }
        return PeriodStats(bars: bars, start: start, total: total, sessions: inPeriod.count,
                           average: total / days(start, end),
                           previousAverage: previousTotal / days(previousStart, start))
    }
}

func clock(_ t: TimeInterval) -> String {
    let s = max(Int(t), 0)
    let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
}
