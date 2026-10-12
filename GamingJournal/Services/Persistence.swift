import Foundation
import SwiftData

enum Persistence {
    static let cloudKitContainerID = "iCloud.com.gamingjournal.GamingJournal"
    /// Store file name. The one-journal-per-character redesign started a fresh store rather than
    /// migrating the notebook one (nothing had shipped).
    static let storeName = "Journals"
    #if FREE_TEAM && os(macOS)
    /// The Mac free build's app group only carries the widget snapshot. Its journals stay in the
    /// app's own container, where they were before the build had a group.
    static let storeGroup: ModelConfiguration.GroupContainer = .none
    #else
    static let storeGroup: ModelConfiguration.GroupContainer = .automatic
    #endif

    /// Opens the journal store, migrating older schema versions. Pass `url` to use a specific file
    /// (tests); otherwise the default store location is used. `cloudSync` mirrors the store to the
    /// user's private CloudKit database.
    static func makeContainer(inMemory: Bool = false, url: URL? = nil, cloudSync: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let database: ModelConfiguration.CloudKitDatabase = cloudSync ? .private(cloudKitContainerID) : .none
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: database)
        } else {
            configuration = ModelConfiguration(
                storeName,
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                groupContainer: storeGroup,
                cloudKitDatabase: database
            )
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: HearthboundMigrationPlan.self,
            configurations: configuration
        )
    }

    /// The app's store: synced when the user turned sync on, falling back to local-only if CloudKit
    /// can't be set up (no iCloud account, missing entitlements). The fallback is recorded in
    /// `SyncSettings.lastLaunchFellBack` so Settings can say so.
    static func makeAppContainer(settings: SyncSettings = SyncSettings()) throws -> ModelContainer {
        if settings.isEnabled {
            do {
                let container = try makeContainer(cloudSync: true)
                settings.lastLaunchFellBack = false
                return container
            } catch {
                settings.lastLaunchFellBack = true
            }
        } else {
            settings.lastLaunchFellBack = false
        }
        return try makeContainer()
    }
}

/// The user's iCloud sync choice. The store is opened once at launch, so changes apply next launch.
struct SyncSettings {
    static let enabledKey = "sync.iCloudEnabled"
    static let fellBackKey = "sync.lastLaunchFellBack"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Off unless the user turned it on.
    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.enabledKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.enabledKey) }
    }

    /// True when sync was on at the last launch but the synced store couldn't be opened.
    var lastLaunchFellBack: Bool {
        get { defaults.bool(forKey: Self.fellBackKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.fellBackKey) }
    }
}
