// ReadingLiveActivity.swift
// The reading timer on the Lock Screen and in the Dynamic Island.
import ActivityKit
import WidgetKit
import SwiftUI

private let accent = Color(red: 0.85, green: 0.58, blue: 0.51)
/// Handled by RootView's onOpenURL: opens the reading session.
private let sessionURL = URL(string: "readie://session")

struct ElapsedText: View {
    let state: ReadingActivityAttributes.ContentState
    var body: some View {
        // The system counts up by itself; no app updates needed every second.
        Text(timerInterval: state.startDate...Date.distantFuture, pauseTime: state.pausedAt, countsDown: false)
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}

/// Ring that fills toward the daily goal. While running, the system animates it without app updates.
struct GoalRing: View {
    let context: ActivityViewContext<ReadingActivityAttributes>
    var icon = true

    var body: some View {
        let state = context.state
        let goal = context.attributes.goalSeconds
        Group {
            if let pausedAt = state.pausedAt {
                ProgressView(value: min(pausedAt.timeIntervalSince(state.startDate) / goal, 1)) { EmptyView() }
            } else {
                ProgressView(timerInterval: state.startDate...state.startDate.addingTimeInterval(goal),
                             countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
            }
        }
        .progressViewStyle(.circular)
        .tint(accent)
        .overlay {
            if icon {
                Image(systemName: state.pausedAt == nil ? "book.fill" : "pause.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(accent)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
    }
}

struct ReadingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Color(.secondarySystemBackground).opacity(0.9))
                .widgetURL(sessionURL)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    GoalRing(context: context).frame(width: 40, height: 40)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedText(state: context.state).font(.title2.weight(.semibold)).frame(maxWidth: 110, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.bookTitle).font(.subheadline).lineLimit(1)
                }
            } compactLeading: {
                GoalRing(context: context)
            } compactTrailing: {
                ElapsedText(state: context.state).frame(maxWidth: 56)
            } minimal: {
                GoalRing(context: context)
            }
            .widgetURL(sessionURL)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<ReadingActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "book.fill").font(.title2).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.bookTitle).font(.subheadline).lineLimit(1)
                    if context.state.pausedAt != nil {
                        Text("Paused").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                ElapsedText(state: context.state)
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .frame(maxWidth: 150, alignment: .trailing)
            }
            // Shown only when the reader has saved a favourite quote; otherwise nothing is added.
            if let quote = context.attributes.quote, !quote.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("“\(quote)”").font(.footnote).italic().lineLimit(3)
                    if let source = context.attributes.quoteSource, !source.isEmpty {
                        Text(source).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
        }
        .padding(16)
    }
}
