import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Backup, privacy, sync, reminders and app info, opened from the shelf.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var journals: [Journal]
    @Query private var entries: [Entry]
    @State private var exportDocument: ExportDocument?
    @State private var isImporting = false
    @State private var message: Message?
    @AppStorage(SyncSettings.enabledKey) private var syncEnabled = false
    /// Sync state the store was opened with at launch.
    @State private var syncAtLaunch = SyncSettings().isEnabled
    @State private var syncFellBack = SyncSettings().lastLaunchFellBack

    private struct Message: Identifiable {
        let id = UUID()
        let title: String
        let body: String
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Export Backup", systemImage: "square.and.arrow.up") { exportJSON() }
                    Button("Import Backup", systemImage: "square.and.arrow.down") { isImporting = true }
                } header: {
                    Text("Your journals")
                } footer: {
                    Text("A backup holds every journal, entry and picture. Importing only adds what's missing, so nothing is duplicated.")
                }
                .listRowBackground(Theme.paper.opacity(0.6))

                #if os(iOS)
                LockSection()
                #else
                Section("Privacy") {
                    MacSpotlightSetting()
                }
                #endif

                // Free-team builds can't sign the iCloud entitlement, so there is nothing to sync with.
                #if !FREE_TEAM
                Section {
                    Toggle("iCloud Sync", systemImage: "icloud", isOn: $syncEnabled)
                } header: {
                    Text("Sync")
                } footer: {
                    Text(syncFooter)
                }
                .listRowBackground(Theme.paper.opacity(0.6))
                #endif

                RemindersSection()

                Section("About") {
                    LabeledContent("Journals", value: "\(journals.count)")
                    LabeledContent("Entries", value: "\(entries.count)")
                    LabeledContent("Version", value: Self.appVersion)
                }
                .listRowBackground(Theme.paper.opacity(0.6))
            }
            .journalFormStyle()
            .scrollContentBackground(.hidden)
            .background(PaperBackground())
            .navigationTitle("Settings")
            .inlineJournalTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .fileExporter(
                isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
                document: exportDocument,
                contentType: exportDocument?.contentType ?? .json,
                defaultFilename: exportDocument?.filename
            ) { result in
                if case .failure(let error) = result {
                    message = Message(title: "Export failed", body: error.localizedDescription)
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url): importBackup(from: url)
                case .failure(let error): message = Message(title: "Import failed", body: error.localizedDescription)
                }
            }
            .alert(item: $message) { message in
                Alert(title: Text(message.title), message: Text(message.body))
            }
        }
        .journalCommandActions(JournalCommandActions())
        .tint(Theme.rubric)
        .journalSheetSize()
    }

    private var syncFooter: String {
        if syncEnabled != syncAtLaunch {
            return "Quit and reopen Hearthbound to \(syncEnabled ? "start" : "stop") syncing."
        }
        if syncEnabled && syncFellBack {
            return "iCloud isn't available right now (check you're signed in to iCloud), so your journals are only on this device."
        }
        return syncEnabled
            ? "Your journals sync across devices signed in to the same iCloud account."
            : "Keep your journals in step across your devices using your iCloud account."
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private func exportJSON() {
        do {
            let data = try JournalBackup(exporting: journals).encoded()
            let filename = "Hearthbound-\(Date.now.formatted(.iso8601.year().month().day()))"
            exportDocument = ExportDocument(data: data, contentType: .json, filename: filename)
        } catch {
            message = Message(title: "Export failed", body: error.localizedDescription)
        }
    }

    private func importBackup(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let backup = try JournalBackup.decode(Data(contentsOf: url))
            let report = try JournalImporter.importBackup(backup, into: context)
            message = Message(title: "Import complete", body: report.summary)
        } catch {
            message = Message(title: "Import failed", body: error.localizedDescription)
        }
    }
}

/// Bytes handed to the system file exporter.
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .markdownText, .plainText, .pdf] }

    var data: Data
    var contentType: UTType
    var filename: String

    init(data: Data, contentType: UTType, filename: String) {
        self.data = data
        self.contentType = contentType
        self.filename = filename
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        contentType = configuration.contentType
        filename = configuration.file.filename ?? "Hearthbound"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension UTType {
    /// Markdown, for exported journal books.
    static let markdownText = UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
}

#if os(macOS)
private struct MacSpotlightSetting: View {
    @AppStorage(SpotlightIndex.enabledKey) private var enabled = true
    var body: some View {
        Toggle("Show in Spotlight", systemImage: "magnifyingglass", isOn: $enabled)
    }
}
#endif
