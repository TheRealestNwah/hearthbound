import SwiftUI

struct JournalCommandActions {
    var settings: (() -> Void)? = nil
    var newJournal: (() -> Void)? = nil
    var write: (() -> Void)? = nil
    var find: (() -> Void)? = nil
}

#if os(macOS)
private struct JournalActionsKey: FocusedValueKey {
    typealias Value = JournalCommandActions
}
extension FocusedValues {
    var journalActions: JournalCommandActions? {
        get { self[JournalActionsKey.self] }
        set { self[JournalActionsKey.self] = newValue }
    }
}
struct JournalCommands: Commands {
    @FocusedValue(\.journalActions) private var actions
    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { actions?.settings?() }
                .keyboardShortcut(",", modifiers: .command)
                .disabled(actions?.settings == nil)
        }
        CommandGroup(replacing: .newItem) {
            Button("Begin a New Journal…") { actions?.newJournal?() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(actions?.newJournal == nil)
            Button("Write a New Entry…") { actions?.write?() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(actions?.write == nil)
        }
        CommandGroup(after: .textEditing) {
            Button("Find…") { actions?.find?() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(actions?.find == nil)
        }
    }
}
#endif

extension View {
    @ViewBuilder func journalCommandActions(_ actions: JournalCommandActions) -> some View {
        #if os(macOS)
        focusedSceneValue(\.journalActions, actions)
        #else
        self
        #endif
    }
}
