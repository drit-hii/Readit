// OnboardingView.swift
// Shown once on first launch: what the app does, then the daily goal.
import SwiftUI

struct OnboardingView: View {
    @AppStorage("didOnboard") private var didOnboard = false
    @AppStorage("goalKind") private var goalKind: GoalKind = .minutes
    @AppStorage("goalMinutes") private var goalMinutes = 30
    @AppStorage("goalPages") private var goalPages = 20
    @State private var askGoal = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text(askGoal ? "Set a daily goal" : "Welcome to Readit")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 60)
                    if askGoal { goal } else { features }
                }
                .padding(.horizontal, 32)
            }
            .scrollBounceBehavior(.basedOnSize)

            Button {
                if askGoal { didOnboard = true } else { withAnimation(.smooth) { askGoal = true } }
            } label: {
                Text(askGoal ? "Start Reading" : "Continue").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.readieButton)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 24) {
            row("timer", "Time your reading", "Start a session for a book, or read freely, like a newspaper.")
            row("barcode.viewfinder", "Scan your books", "Point the camera at the barcode and the book is added for you.")
            row("waveform", "Keep what stuck", "After each session, save a quote or a voice note. It's summarised on your iPhone.")
            row("flame.fill", "Build a streak", "Read every day. Two missed days a month are saved for you.")
        }
    }

    private var goal: some View {
        VStack(spacing: 20) {
            Text("How much do you want to read each day, and when should we remind you? You can change it later.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Picker("Measure by", selection: $goalKind) {
                ForEach(GoalKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            if goalKind == .minutes {
                Stepper(value: $goalMinutes, in: 5...480, step: 5) { Text("\(goalMinutes) minutes a day").font(.title3) }
            } else {
                Stepper(value: $goalPages, in: 1...500, step: 1) { Text("\(goalPages) pages a day").font(.title3) }
            }
            Divider()
            ReminderSettings().tint(.readieButton)
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private func row(_ icon: String, _ title: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(Color.readieAccent)
                .frame(width: 40)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview { OnboardingView() }
