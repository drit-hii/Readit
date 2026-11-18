// HomeView.swift
import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(ReadingTimer.self) private var timer
    @Environment(AppRouter.self) private var router
    @Query(sort: \ReadingSession.startedAt) private var sessions: [ReadingSession]
    @Query(filter: #Predicate<Book> { $0.statusRaw == "reading" }, sort: \Book.addedAt) private var reading: [Book]

    @AppStorage("goalKind") private var goalKind: GoalKind = .minutes
    @AppStorage("goalMinutes") private var goalMinutes = 30
    @AppStorage("goalPages") private var goalPages = 20

    @State private var showGoal = false
    @State private var showPicker = false

    private var days: [DayStat] { Stats.lastDays(sessions: sessions) }
    private var today: DayStat { days.last ?? DayStat(date: .now, seconds: 0, pages: 0) }
    private var target: Int { max(goalKind == .minutes ? goalMinutes : goalPages, 1) }
    private var remaining: Int { max(target - today.value(goalKind), 0) }
    private var progress: Double {
        let done = goalKind == .minutes ? today.seconds / 60 : Double(today.pages)
        return min(done / Double(target), 1)
    }

    var body: some View {
        NavigationStack {
            Group { reading.isEmpty && timer.phase == .idle ? AnyView(emptyState) : AnyView(todayState) }
                .background((reading.isEmpty ? Color(.systemBackground) : Color(.systemGroupedBackground)).ignoresSafeArea())
        }
        .sheet(isPresented: $showGoal) { GoalSheet() }
        .sheet(isPresented: $showPicker) { BookPickerView(defaultStatus: .reading) }
    }

    // MARK: Today (book in progress)

    private var todayState: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Text("For today")
                        .font(.caption.weight(.medium)).tracking(0.8).textCase(.uppercase)
                        .foregroundStyle(Color.readieAccent)
                    Button { showGoal = true } label: {
                        ProgressRing(progress: progress, remaining: remaining,
                                     unit: goalKind == .minutes ? "min" : "pages", done: progress >= 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(goalKind == .minutes
                        ? "Daily goal: \(today.minutes) of \(target) minutes read"
                        : "Daily goal: \(today.pages) of \(target) pages read")
                    .accessibilityHint("Edit your daily goal")

                    if let usual = Stats.usual(days, kind: goalKind) {
                        Text(goalKind == .minutes ? "Your usual is about \(usual) min."
                                                  : "Your usual is about \(usual) pages.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }

                startButton

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Last 7 days").font(.title3.weight(.semibold))
                        Spacer()
                        let streak = Stats.streak(sessions: sessions)
                        if streak > 0 {
                            Label("\(streak)-day streak", systemImage: "bookmark.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.readieAccent)
                        }
                    }
                    Card { WeekChart(days: days, kind: goalKind, goal: target).padding(16) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .navigationTitle("Today")
    }

    private var startButton: some View {
        Button(action: start) {
            Group {
                if timer.phase == .idle {
                    Label("Start Reading", systemImage: "book.fill")
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Label("Resume · \(clock(timer.elapsed(at: ctx.date)))", systemImage: "book.fill")
                            .monospacedDigit()
                    }
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.glassProminent)
        .tint(.readieButton)
        .controlSize(.large)
    }

    private func start() {
        if timer.phase == .idle {
            let book = reading.first
            timer.start(bookID: book?.id, title: book?.title ?? "", author: book?.author ?? "")
        }
        router.showSession = true
    }

    // MARK: Empty state (no book in progress)

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.footnote.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                    Text("What are you reading today?").font(.title.bold())
                    Text("Pick a book to start").font(.title3).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)

                Card(fill: Color(.secondarySystemBackground)) {
                    VStack(spacing: 18) {
                        HStack(alignment: .top, spacing: 16) {
                            Button { showPicker = true } label: {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.readieAccent, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                    .background(Color.readieAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay { Image(systemName: "plus").font(.largeTitle.weight(.light)).foregroundStyle(Color.readieAccent) }
                                    .frame(width: 96, height: 144)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Pick a book")

                            VStack(alignment: .leading, spacing: 6) {
                                Text("No book in progress")
                                    .font(.caption.weight(.semibold)).textCase(.uppercase)
                                    .foregroundStyle(Color.readieAccent)
                                Text("Pick a book").font(.title2.bold())
                                Text("From your library, or add a new one").foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        Button { showPicker = true } label: {
                            Label("Pick a book", systemImage: "plus").font(.headline).padding(.horizontal, 12).padding(.vertical, 4)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.readieButton)
                        .controlSize(.large)
                    }
                    .padding(16)
                }

                Text("Your bookshelf").font(.title3.weight(.semibold))
                Card(fill: Color(.secondarySystemBackground)) {
                    VStack(spacing: 14) {
                        VStack(spacing: 6) {
                            Image(systemName: "books.vertical.fill").font(.largeTitle).foregroundStyle(.tertiary)
                            Text("The bookshelf is empty").font(.headline)
                            Text("Books you read will line up here.").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.top, 20)
                        Divider()
                        WeekdayAxis(days: days).padding(.horizontal, 6).padding(.bottom, 10)
                    }
                }

                Button("Start without a book") {
                    timer.start(bookID: nil, title: "", author: "")
                    router.showSession = true
                }
                .buttonStyle(.borderless)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
    }
}

// MARK: - Components

struct ProgressRing: View {
    let progress: Double
    let remaining: Int
    let unit: LocalizedStringKey
    let done: Bool

    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 64
    @ScaledMetric(relativeTo: .largeTitle) private var diameter: CGFloat = 188
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(Color.readieAccent.opacity(0.18), lineWidth: 16)
            // A tiny trim with a round cap draws the dot at 12 o'clock when progress is zero.
            Circle().trim(from: 0, to: max(progress, 0.001))
                .stroke(Color.readieAccent, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                if done {
                    Image(systemName: "checkmark").font(.system(size: numberSize * 0.8, weight: .semibold))
                        .foregroundStyle(Color.readieAccent)
                    Text("Goal reached").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("\(remaining)").font(.system(size: numberSize, weight: .semibold)).monospacedDigit()
                    Text(unit).font(.body).foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(reduceMotion ? nil : .smooth, value: progress)
    }
}

struct WeekdayAxis: View {
    let days: [DayStat]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                let isToday = index == days.count - 1
                Text(isToday ? String(localized: "Today") : letter(day.date))
                    .font(.caption2.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
    private func letter(_ d: Date) -> String {
        let cal = Calendar.current
        return cal.veryShortWeekdaySymbols[cal.component(.weekday, from: d) - 1]
    }
}

/// Seven days of reading drawn as books on a shelf, with a check-in row underneath.
struct WeekChart: View {
    let days: [DayStat]
    let kind: GoalKind
    let goal: Int

    private let maxSpine: CGFloat = 130

    var body: some View {
        let maxValue = max(days.map { $0.value(kind) }.max() ?? 0, goal, 1)
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    column(day, index: index, maxValue: maxValue)
                }
            }
            .frame(height: 176, alignment: .bottom)

            Rectangle().fill(Color(.separator)).frame(height: 1)

            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    checkCell(day, index: index)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    @ViewBuilder
    private func column(_ day: DayStat, index: Int, maxValue: Int) -> some View {
        let value = day.value(kind)
        let isToday = index == days.count - 1
        VStack(spacing: 6) {
            if value > 0 {
                Text(kind == .minutes ? "\(value)′" : "\(value)p").font(.footnote.weight(.semibold))
                BookSpine(color: Color.spinePalette[Calendar.current.component(.weekday, from: day.date) % Color.spinePalette.count],
                          width: 40, height: max(28, CGFloat(value) / CGFloat(maxValue) * maxSpine))
            } else if isToday {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.readieAccent.opacity(0.8), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                    .frame(width: 36, height: 100)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func checkCell(_ day: DayStat, index: Int) -> some View {
        let has = { (i: Int) in days.indices.contains(i) && days[i].value(kind) > 0 }
        let isToday = index == days.count - 1
        let linkLeft = has(index) && has(index - 1)
        let linkRight = has(index) && has(index + 1)
        return VStack(spacing: 6) {
            ZStack {
                HStack(spacing: 0) {
                    Rectangle().fill(linkLeft ? Color.readieAccent.opacity(0.35) : .clear).frame(height: 3)
                    Rectangle().fill(linkRight ? Color.readieAccent.opacity(0.35) : .clear).frame(height: 3)
                }
                if has(index) {
                    Circle().fill(Color.readieAccent).frame(width: 26, height: 26)
                        .overlay { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white) }
                } else if isToday {
                    Circle().strokeBorder(Color.readieAccent.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                        .frame(width: 26, height: 26)
                } else {
                    Circle().fill(Color(.tertiarySystemFill)).overlay(Circle().strokeBorder(Color(.separator), lineWidth: 0.5))
                        .frame(width: 26, height: 26)
                }
            }
            Text(isToday ? String(localized: "Today") : letter(day.date))
                .font(.caption2.weight(has(index) || isToday ? .semibold : .regular))
                .foregroundStyle(has(index) || isToday ? Color.readieAccent : Color.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func letter(_ d: Date) -> String {
        let cal = Calendar.current
        return cal.veryShortWeekdaySymbols[cal.component(.weekday, from: d) - 1]
    }

    private var summary: String {
        let parts = days.map { d -> String in
            let name = d.date.formatted(.dateTime.weekday(.wide))
            return kind == .minutes ? "\(name): \(d.minutes) minutes" : "\(name): \(d.pages) pages"
        }
        return "Last 7 days. " + parts.joined(separator: ", ")
    }
}
