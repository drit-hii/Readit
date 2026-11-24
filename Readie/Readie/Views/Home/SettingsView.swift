// SettingsView.swift
// Opened from the gear on Home and by tapping the daily goal.
import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .system: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance: Appearance = .system
    @AppStorage("goalKind") private var goalKind: GoalKind = .minutes
    @AppStorage("goalMinutes") private var goalMinutes = 30
    @AppStorage("goalPages") private var goalPages = 20

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Picker("Measure by", selection: $goalKind) {
                        ForEach(GoalKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if goalKind == .minutes {
                        Stepper(value: $goalMinutes, in: 5...480, step: 5) {
                            Text("\(goalMinutes) minutes a day")
                        }
                    } else {
                        Stepper(value: $goalPages, in: 1...500, step: 1) {
                            Text("\(goalPages) pages a day")
                        }
                    }
                } header: {
                    Text("Daily Goal")
                } footer: {
                    Text("Your goal ring on the Today screen fills as you read.")
                }
                Section("Reminder") { ReminderSettings() }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.large])
        // An open sheet doesn't pick up the app's new scheme; apply it here so the change shows at once.
        .preferredColorScheme(appearance.colorScheme)
    }
}
