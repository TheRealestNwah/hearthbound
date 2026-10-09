import SwiftUI

/// Settings for the evening reminder. Turning it on asks for notification permission; if that's
/// refused the switch goes back off and says why.
struct RemindersSection: View {
    @AppStorage(CampfireReminders.eveningKey) private var evening = false
    @AppStorage(CampfireReminders.eveningTimeKey) private var eveningTime = CampfireReminders.defaultEveningTime
    @State private var permissionRefused = false
    private let reminders = CampfireReminders.shared

    var body: some View {
        Section {
            Toggle("Remind me every evening", systemImage: "moon.stars", isOn: $evening)
            if evening {
                DatePicker("Time", selection: eveningDate, displayedComponents: .hourAndMinute)
            }
        } header: {
            PaperSectionHeader("Reminder")
        } footer: {
            PaperSectionFooter(permissionRefused
                 ? "Notifications are off for Hearthbound. Turn them on in the Settings app to get reminders."
                 : "A nudge each day at the time you pick to set down what your character did.")
        }
        .paperRow()
        .onChange(of: evening) { _, isOn in
            if isOn {
                confirmPermission { evening = false }
            } else {
                Task { await reminders.applyEveningSetting() }
            }
        }
        .onChange(of: eveningTime) {
            Task { await reminders.applyEveningSetting() }
        }
    }

    /// The time picker works in dates; the setting is minutes after midnight.
    private var eveningDate: Binding<Date> {
        Binding {
            Calendar.current.date(from: CampfireReminders.eveningComponents(minutes: eveningTime)) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            eveningTime = (parts.hour ?? 21) * 60 + (parts.minute ?? 0)
        }
    }

    private func confirmPermission(orUndo undo: @escaping () -> Void) {
        Task {
            let granted = await reminders.enable()
            permissionRefused = !granted
            if granted {
                await reminders.applyEveningSetting()
            } else {
                undo()
            }
        }
    }
}
