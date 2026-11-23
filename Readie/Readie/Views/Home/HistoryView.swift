// HistoryView.swift
import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    @Query(sort: \ReadingSession.startedAt, order: .reverse) private var sessions: [ReadingSession]
    @AppStorage("goalKind") private var goalKind: GoalKind = .minutes
    @State private var period: StatsPeriod = .week

    private var stats: PeriodStats { Stats.period(period, kind: goalKind, sessions: sessions) }

    var body: some View {
        let stats = stats
        let streak = Stats.streak(sessions: sessions)
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Period", selection: $period) {
                        ForEach(StatsPeriod.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily average")
                            .font(.footnote.weight(.semibold)).textCase(.uppercase).foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(Int(stats.average.rounded()))").font(.system(.largeTitle, design: .rounded, weight: .bold))
                            Text(unit).font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        Text((stats.start..<Date.now).formatted(.interval.day().month(.abbreviated).year()))
                            .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)

                    chart(stats)
                }
                .padding(.vertical, 8)
            }

            Section("Highlights") {
                HStack(spacing: 10) {
                    Image(systemName: trendIcon(stats.trend)).foregroundStyle(Color.readieAccent)
                    Text(trendText(stats.trend))
                }
                .font(.subheadline)
                HStack {
                    tile("Total", goalKind == .minutes ? hours(stats.total) : "\(Int(stats.total))")
                    Divider()
                    tile("Sessions", "\(stats.sessions)")
                    Divider()
                    tile("Streak", "\(streak.days) d")
                }
                Label("^[\(streak.savesLeft) streak save](inflect: true) left this month. A missed day uses one automatically.",
                      systemImage: "shield.lefthalf.filled")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Sessions") {
                let inPeriod = sessions.filter { $0.startedAt >= stats.start }
                if inPeriod.isEmpty {
                    Text("No sessions in this period.").foregroundStyle(.secondary)
                }
                ForEach(inPeriod) { s in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.book?.title ?? s.label ?? String(localized: "Free reading")).font(.headline)
                            Text(s.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(clock(s.duration)).monospacedDigit()
                            if s.pages > 0 { Text("\(s.pages) pages").font(.footnote).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.smooth, value: period)
    }

    private var unit: String { goalKind == .minutes ? String(localized: "min") : String(localized: "pages") }

    private func chart(_ stats: PeriodStats) -> some View {
        let unitComponent = period.bucket.unit
        return Chart(stats.bars) { bar in
            BarMark(x: .value("Date", bar.start, unit: unitComponent),
                    y: .value("Average", bar.value))
                .foregroundStyle(Color.readieAccent)
                .cornerRadius(3)
        }
        .chartXAxis {
            switch period {
            case .week:
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine(); AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                }
            case .month:
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine(); AxisValueLabel(format: .dateTime.day())
                }
            case .sixMonths:
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine(); AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            case .year:
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine(); AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                }
            }
        }
        .chartYAxis { AxisMarks(position: .trailing) }
        .frame(height: 240)
        .accessibilityLabel("Daily average chart")
    }

    private func tile(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.bold)).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func hours(_ minutes: Double) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }

    private func trendIcon(_ trend: Int?) -> String {
        guard let trend else { return "chart.line.flattrend.xyaxis" }
        return trend >= 0 ? "arrow.up.right" : "arrow.down.right"
    }

    private func trendText(_ trend: Int?) -> String {
        let previous: String = switch period {
        case .week: String(localized: "the previous week")
        case .month: String(localized: "the previous month")
        case .sixMonths: String(localized: "the previous 6 months")
        case .year: String(localized: "the previous year")
        }
        guard let trend else { return String(localized: "Not enough reading yet to show a trend.") }
        if trend == 0 { return String(localized: "Your daily reading is the same as \(previous).") }
        return trend > 0
            ? String(localized: "Your daily reading is up \(trend)% compared to \(previous).")
            : String(localized: "Your daily reading is down \(abs(trend))% compared to \(previous).")
    }
}
