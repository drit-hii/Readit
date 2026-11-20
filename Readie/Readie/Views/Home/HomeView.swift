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
    @State private var selectedID: UUID?
    @ScaledMetric(relativeTo: .largeTitle) private var challengeSize: CGFloat = 56
    
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
    
    private var current: Book? { reading.first { $0.id == selectedID } ?? reading.first }
    
    private var todayState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                challenge
                bookCarousel
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Last 7 days").font(.title3.weight(.semibold))
                        Spacer()
                        NavigationLink { HistoryView() } label: {
                            HStack(spacing: 4) {
                                Text("History")
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color.readieAccent)
                        }
                    }
                    WeekChart(days: days, kind: goalKind, goal: target)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .navigationTitle("Hello Reader")
    }
    
    private var challenge: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today's challenge")
                .font(.footnote.weight(.medium)).tracking(0.8).textCase(.uppercase)
                .foregroundStyle(Color.readieAccent)
            
            Button { showGoal = true } label: {
                Text(goalKind == .minutes ? "\(target) min" : "\(target) pages")
                    .font(.system(size: challengeSize, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit your daily goal")
            
            if let usual = Stats.usual(days, kind: goalKind) {
                Text(goalKind == .minutes ? "Your usual is about \(usual) min."
                     : "Your usual is about \(usual) pages.")
                .font(.subheadline).foregroundStyle(.secondary)
            }
            
            Capsule()
                .fill(Color.readieAccent.opacity(0.18))
                .frame(height: 10)
                .overlay(alignment: .leading) {
                    GeometryReader { g in
                        Capsule().fill(Color.readieAccent).frame(width: g.size.width * progress)
                    }
                }
                .padding(.top, 6)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Daily progress")
                .accessibilityValue("\(Int(progress * 100)) percent")
        }
    }
    
    private var bookCarousel: some View {
        VStack(spacing: 14) {
            if reading.isEmpty {
                startButton(nil)   // free reading while the timer is running
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(reading) { book in
                            bookCard(book)
                                .containerRelativeFrame(.horizontal)
                                .id(book.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $selectedID)
                .scrollClipDisabled()
                
                if reading.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(reading) { book in
                            Circle()
                                .fill(book.id == current?.id ? Color.readieAccent : Color(.tertiaryLabel))
                                .frame(width: 7, height: 7)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Book \((reading.firstIndex { $0.id == current?.id } ?? 0) + 1) of \(reading.count)")
                }
            }
        }
    }
    
    private func bookCard(_ book: Book) -> some View {
        Card(fill: Color(.secondarySystemBackground)) {
            VStack(spacing: 20) {
                HStack(alignment: .top, spacing: 16) {
                    BookCover(book: book, width: 120, height: 180)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Now reading")
                            .font(.footnote.weight(.medium)).textCase(.uppercase)
                            .foregroundStyle(Color.readieAccent)
                        Text(book.title).font(.title2).lineLimit(3)
                        Text(book.author).font(.title3).foregroundStyle(.secondary).lineLimit(2)
                        Spacer(minLength: 8)
                        ProgressView(value: book.progress)
                            .tint(Color.readieAccent)
                            .accessibilityHidden(true)
                        Text(book.pageCount > 0 ? "Page \(book.currentPage) of \(book.pageCount)"
                             : "Page \(book.currentPage)")
                        .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                startButton(book)
            }
            .padding(16)
        }
        .accessibilityElement(children: .contain)
    }
    
    private func startButton(_ book: Book?) -> some View {
        Button { start(book) } label: {
            Group {
                if timer.phase == .idle {
                    Label("Start reading", systemImage: "book.fill")
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Label("Resume · \(clock(timer.elapsed(at: ctx.date)))", systemImage: "book.fill")
                            .monospacedDigit()
                    }
                }
            }
            .font(.headline)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .buttonStyle(.glassProminent)
        .tint(.readieButton)
        .controlSize(.large)
    }
    
    private func start(_ book: Book?) {
        if timer.phase == .idle {
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

struct HistoryView: View {
    @Query(sort: \ReadingSession.startedAt, order: .reverse) private var sessions: [ReadingSession]
    
    var body: some View {
        List(sessions) { s in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.book?.title ?? String(localized: "Free reading")).font(.headline)
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
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if sessions.isEmpty {
                ContentUnavailableView("No Sessions Yet", systemImage: "clock",
                                       description: Text("Finished reading sessions appear here."))
            }
        }
    }
}
