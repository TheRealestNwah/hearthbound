import SwiftUI

#if os(iOS)
import UIKit

extension View {
    /// Covers the app while the journal is locked, and hides it in the app switcher when the lock
    /// is on. Seals again whenever the app goes to the background.
    func appLock(_ lock: AppLock) -> some View {
        modifier(AppLockModifier(lock: lock))
    }

    /// iOS covers sheets from its own window, so they need nothing extra.
    func lockCover() -> some View { self }
}

private struct AppLockModifier: ViewModifier {
    let lock: AppLock
    @Environment(\.scenePhase) private var scenePhase
    /// Only a return from the background should prompt: the Face ID sheet itself makes the app
    /// briefly inactive, and prompting on that would loop after a cancel.
    @State private var returningFromBackground = false

    private enum Cover: Equatable {
        case none, sealed, locked
    }

    private var cover: Cover {
        if lock.isLocked { return .locked }
        // What the app switcher snapshots: no pages on show.
        if lock.isEnabled && scenePhase != .active { return .sealed }
        return .none
    }

    func body(content: Content) -> some View {
        content
            // In its own window so it covers sheets and alerts too, not just the root view.
            .onChange(of: cover, initial: true) { _, cover in
                switch cover {
                case .none: LockWindow.shared.hide()
                case .sealed: LockWindow.shared.show(SealedCover())
                case .locked: LockWindow.shared.show(LockScreen(lock: lock))
                }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    lock.seal()
                    returningFromBackground = true
                case .active where returningFromBackground:
                    returningFromBackground = false
                    Task { await lock.unlock() }
                default:
                    break
                }
            }
    }
}

/// A window above everything else in the app (sheets, alerts, the keyboard) for the lock.
@MainActor
private final class LockWindow {
    static let shared = LockWindow()
    private var window: UIWindow?

    func show(_ view: some View) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState != .unattached })
        else { return }
        let window = window ?? UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        let host = UIHostingController(rootView: AnyView(view))
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = false
        self.window = window
    }

    func hide() {
        window?.isHidden = true
        window = nil
    }
}

#endif

#if os(macOS)
import AppKit
import Combine

extension View {
    /// Covers the window while the journal is locked and seals it whenever the owner steps away:
    /// the app is hidden, its window minimised or closed, the screen locked or asleep, or another
    /// user takes over. Switching to another app leaves it open.
    func appLock(_ lock: AppLock) -> some View {
        modifier(MacAppLockModifier(lock: lock))
    }

    /// Covers a sheet's own window too. Mac sheets are separate windows, so the window's cover
    /// doesn't reach them.
    func lockCover() -> some View {
        modifier(LockCoverModifier())
    }
}

private struct MacAppLockModifier: ViewModifier {
    let lock: AppLock
    /// Only a return from stepping away should prompt: the Touch ID panel itself makes the app
    /// briefly inactive, and prompting on that would loop after a cancel.
    @State private var promptOnReturn = false

    private static let sealing: [Notification.Name] = [
        NSApplication.didHideNotification,
        NSWindow.willMiniaturizeNotification,
    ]
    private static let workspaceSealing: [Notification.Name] = [
        NSWorkspace.screensDidSleepNotification,
        NSWorkspace.willSleepNotification,
        NSWorkspace.sessionDidResignActiveNotification,
    ]

    func body(content: Content) -> some View {
        content
            .modifier(LockCover(lock: lock))
            .onAppear {
                if lock.isLocked && NSApp.isActive { prompt() }
            }
            // Closing the window keeps the app running; it reopens sealed.
            .onDisappear { seal() }
            .onReceive(merged(NotificationCenter.default, Self.sealing)) { _ in seal() }
            .onReceive(merged(NSWorkspace.shared.notificationCenter, Self.workspaceSealing)) { _ in seal() }
            .onReceive(DistributedNotificationCenter.default().publisher(for: .init("com.apple.screenIsLocked"))) { _ in seal() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in returned() }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didDeminiaturizeNotification)) { _ in returned() }
            .onReceive(DistributedNotificationCenter.default().publisher(for: .init("com.apple.screenIsUnlocked"))) { _ in returned() }
    }

    private func merged(_ center: NotificationCenter, _ names: [Notification.Name]) -> some Publisher<Notification, Never> {
        Publishers.MergeMany(names.map { center.publisher(for: $0) })
    }

    private func seal() {
        guard lock.isEnabled else { return }
        lock.seal()
        promptOnReturn = true
    }

    private func returned() {
        guard promptOnReturn, NSApp.isActive else { return }
        promptOnReturn = false
        prompt()
    }

    private func prompt() {
        Task { await lock.unlock() }
    }
}

private struct LockCoverModifier: ViewModifier {
    @Environment(AppLock.self) private var lock

    func body(content: Content) -> some View {
        content.modifier(LockCover(lock: lock))
    }
}

/// The sealed shelf over a window's content.
private struct LockCover: ViewModifier {
    let lock: AppLock

    func body(content: Content) -> some View {
        content
            // Hidden from VoiceOver and the keyboard too, not just covered.
            .disabled(lock.isLocked)
            .accessibilityHidden(lock.isLocked)
            .overlay {
                if lock.isLocked {
                    LockScreen(lock: lock, promptsOnAppear: false)
                }
            }
    }
}
#endif

/// The closed journal, with a way to open it.
private struct LockScreen: View {
    let lock: AppLock
    /// Asks straight away. Off on Mac, where the cover also shows while the app is hidden, so
    /// the prompt waits for the owner to come back.
    var promptsOnAppear = true

    var body: some View {
        ZStack {
            SealedCover()
            VStack(spacing: 20) {
                Spacer()
                WaxSeal(systemImage: "lock.fill", size: 88)
                    .accessibilityLabel("Sealed")
                Text("Your journals are sealed")
                    .font(Theme.book(28, relativeTo: .title2))
                    .foregroundStyle(Theme.woodInk)
                Text("Only you can break the seal.")
                    .font(Theme.bookItalic(18))
                    .foregroundStyle(Theme.woodFaded)
                Button("Unlock with \(lock.method)") {
                    Task { await lock.unlock() }
                }
                .font(Theme.book(20, relativeTo: .headline))
                .foregroundStyle(Theme.gold)
                .padding(.top, 8)
                Spacer()
            }
            .multilineTextAlignment(.center)
            .padding(32)
        }
        .task {
            if promptsOnAppear { await lock.unlock() }
        }
    }
}

/// The closed shelf over everything.
private struct SealedCover: View {
    var body: some View {
        WoodBackground()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
