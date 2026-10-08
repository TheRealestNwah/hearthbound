import SwiftUI
import SwiftData

@main
struct GamingJournalApp: App {
    let container: ModelContainer
    @State private var appLock: AppLock

    init() {
        BookFont.register()
        Theme.applyAppearance()
        do {
            if LaunchOptions.isUITesting {
                // Start each UI test from first launch unless it pre-sets values as launch arguments.
                UserDefaults.standard.removeObject(forKey: OnboardingView.completedKey)
                container = try Persistence.makeContainer(inMemory: true)
                _appLock = State(initialValue: AppLock(defaults: LaunchOptions.uiTestingDefaults()))
            } else {
                container = try Persistence.makeAppContainer()
                _appLock = State(initialValue: AppLock())
            }
        } catch {
            fatalError("Could not open the journal store: \(error)")
        }
        if !LaunchOptions.isUITesting {
            NotificationRouter.shared.install()
            // Keeps the evening reminder in step with Settings, e.g. after a restore.
            Task { await CampfireReminders.shared.applyEveningSetting() }
        }
        if LaunchOptions.seedsDemoData {
            DemoData.seed(into: container.mainContext)
        }
    }

    var body: some Scene {
        #if os(macOS)
        Window("Hearthbound", id: "journals") {
            RootView()
                .environment(appLock)
                .uiTestLook()
                .frame(minWidth: 640, minHeight: 540)
        }
        .modelContainer(container)
        .defaultSize(width: LaunchOptions.compactWindow ? 640 : 1100, height: LaunchOptions.compactWindow ? 540 : 800)
        .commands {
            // Keep one journal workflow while using normal Mac launch/reopen behavior.
            JournalCommands()
            TextEditingCommands()
        }
        #else
        WindowGroup {
            RootView()
                .environment(appLock)
                .appLock(appLock)
                .uiTestLook()
        }
        .modelContainer(container)
        #endif
    }
}

private extension View {
    /// The appearance and text size a UI test asked for, if any.
    @ViewBuilder func uiTestLook() -> some View {
        let scheme: ColorScheme? = switch LaunchOptions.appearance {
        case "dark": .dark
        case "light": .light
        default: nil
        }
        if LaunchOptions.largeText {
            preferredColorScheme(scheme).dynamicTypeSize(.accessibility2)
        } else {
            preferredColorScheme(scheme)
        }
    }
}
