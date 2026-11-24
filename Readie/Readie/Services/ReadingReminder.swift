// ReadingReminder.swift
// A daily local notification reminding the reader to read.
import SwiftUI
import UserNotifications

enum ReadingReminder {
    private static let id = "dailyReadingReminder"

    /// Replaces the pending reminder; returns false if notifications aren't allowed.
    // shortcut: fires every day even if you've already read; skip-if-read needs a background refresh task.
    static func schedule(on: Bool, at time: Date) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard on, (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return !on }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time to read")
        content.body = String(localized: "A few pages today keep your streak going.")
        content.sound = .default
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        return true
    }
}

/// Toggle + time picker, used in onboarding and in the goal sheet.
struct ReminderSettings: View {
    @AppStorage("reminderOn") private var on = false
    /// Stored as a reference-date interval because AppStorage can't hold a Date. Default 21:00.
    @AppStorage("reminderTime") private var time = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: .now)!
        .timeIntervalSinceReferenceDate

    var body: some View {
        let date = Binding { Date(timeIntervalSinceReferenceDate: time) } set: { time = $0.timeIntervalSinceReferenceDate }
        Toggle("Daily reminder", systemImage: "bell.fill", isOn: $on)
            .task(id: "\(on)\(time)") {
                // Turned off again when the reader denies notifications.
                if await !ReadingReminder.schedule(on: on, at: date.wrappedValue) { on = false }
            }
        if on {
            DatePicker("Remind me at", selection: date, displayedComponents: .hourAndMinute)
        }
    }
}
