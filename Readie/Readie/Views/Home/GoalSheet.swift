// GoalSheet.swift
import SwiftUI

struct GoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("goalKind") private var goalKind: GoalKind = .minutes
    @AppStorage("goalMinutes") private var goalMinutes = 30
    @AppStorage("goalPages") private var goalPages = 20

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Measure by", selection: $goalKind) {
                        ForEach(GoalKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    if goalKind == .minutes {
                        Stepper(value: $goalMinutes, in: 5...480, step: 5) {
                            Text("\(goalMinutes) minutes a day")
                        }
                    } else {
                        Stepper(value: $goalPages, in: 1...500, step: 1) {
                            Text("\(goalPages) pages a day")
                        }
                    }
                } footer: {
                    Text("Your goal ring on the Today screen fills as you read.")
                }
            }
            .navigationTitle("Daily Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}
