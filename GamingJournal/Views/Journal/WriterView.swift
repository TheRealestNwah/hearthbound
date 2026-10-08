import SwiftUI
import SwiftData
import PhotosUI

/// A blank page to write on: the in-game date, the place, the words, and optionally a picture or two.
struct WriterView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let journal: Journal
    private let entry: Entry?
    @State private var draft: EntryDraft
    /// The page as it opened, to tell whether × would throw anything away.
    private let original: EntryDraft
    @State private var isConfirmingDiscard = false
    /// An unfinished new entry left in this journal, offered back until the writer decides.
    @State private var unfinished: DraftShelf.Saved?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    @State private var photosLoaded = 0
    @State private var photosTotal = 0
    @State private var errorMessage: String?
    @State private var isConfirmingKeep = false
    @State private var failNextSave = LaunchOptions.isUITesting && ProcessInfo.processInfo.arguments.contains("-failNextSave")
    @State private var isShowingCamera = false
    @State private var isImportingPhotos = false
    @FocusState private var bodyFocused: Bool
    @FocusState private var placeFocused: Bool
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 19
    private let drafts = DraftShelf()

    init(journal: Journal, entry: Entry? = nil) {
        self.journal = journal
        self.entry = entry
        let original = entry.map(EntryDraft.init(entry:)) ?? EntryDraft.new(in: journal)
        self.original = original
        _draft = State(initialValue: original)
        _unfinished = State(initialValue: entry == nil ? DraftShelf().saved(for: journal.id) : nil)
    }

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 0) {
                topBar
                PageRule()
                    .padding(.bottom, 12)

                if let unfinished {
                    unfinishedOffer(unfinished)
                }

                Group {
                    TextField("In-game date", text: $draft.inGameDate, prompt: Text("In-game date, e.g. 17th of Last Seed").foregroundStyle(Theme.fadedInk))
                        .font(Theme.dateLine)
                        .foregroundStyle(Theme.rubric)
                        .capitalizedWords()
                        .accessibilityIdentifier("inGameDate")
                        .paperField()
                        .submitLabel(.next)
                        .onSubmit { placeFocused = true }
                    TextField("Place", text: $draft.place, prompt: Text("Where, e.g. Whiterun").foregroundStyle(Theme.fadedInk))
                        .font(Theme.bookItalic(17, relativeTo: .subheadline))
                        .foregroundStyle(Theme.ink)
                        .capitalizedWords()
                        .accessibilityIdentifier("place")
                        .focused($placeFocused)
                        .submitLabel(.next)
                        .onSubmit { bodyFocused = true }
                        .paperField()
                        .padding(.top, 6)
                    if let next = InGameDate.nextDay(after: draft.inGameDate) {
                        nextDayButton(next)
                            .padding(.top, 4)
                    }

                    ZStack(alignment: .topLeading) {
                        if draft.body.isEmpty {
                            Text("Dear journal…")
                                .font(Theme.bookItalicFixed(fontSize))
                                .foregroundStyle(Theme.fadedInk)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .accessibilityHidden(true)
                        }
                        TextEditor(text: $draft.body)
                            .font(Theme.bookFixed(fontSize))
                            .lineSpacing(fontSize * 0.22)
                            .foregroundStyle(Theme.ink)
                            .scrollContentBackground(.hidden)
                            .focused($bodyFocused)
                            .accessibilityLabel("Entry")
                            .accessibilityIdentifier("entryBody")
                    }
                    .padding(.top, 8)

                    if !draft.photos.isEmpty {
                        photoStrip
                    }
                    tools
                }
                .disabled(unfinished != nil)
                draftStatus
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .journalCommandActions(JournalCommandActions())
        .tint(Theme.rubric)
        .onAppear {
            if entry == nil && unfinished == nil { bodyFocused = true }
        }
        // Keep new writing safe from an accidental dismissal or the app being closed, but not over
        // an unfinished page still waiting to be carried on or discarded.
        .onChange(of: draft) { _, draft in
            if entry == nil && unfinished == nil { drafts.keep(draft, for: journal.id) }
        }
        #if os(iOS)
        .journalCover(isPresented: $isShowingCamera) {
            CameraPicker { image in
                isShowingCamera = false
                if let image {
                    isLoadingPhotos = true
                    photosLoaded = 0
                    photosTotal = 1
                    Task { await add(image) }
                }
            }
            .ignoresSafeArea()
        }
        #endif
        .interactiveDismissDisabled()
        #if os(macOS)
        .fileImporter(isPresented: $isImportingPhotos, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): loadFiles(urls)
            case .failure(let error):
                if !FileOperation.isCancellation(error) { errorMessage = error.localizedDescription }
            }
        }
        #endif
        .alert("Could not complete the action", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .confirmationDialog("Keep the words without pictures?", isPresented: $isConfirmingKeep, titleVisibility: .visible) {
            Button("Keep Words") { keepDraft() }
            Button("Keep Writing", role: .cancel) { }
        } message: { Text("Pictures are only kept when you save the entry. You'll need to add them again when you resume this draft.") }
        #if os(macOS)
        .dropDestination(for: URL.self) { urls, _ in
            guard !isLoadingPhotos, unfinished == nil, !urls.isEmpty else { return false }
            loadFiles(urls)
            return true
        }
        #endif
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            load(items)
        }
    }

    // MARK: Parts

    private var topBar: some View {
        HStack {
            Button("Cancel", systemImage: "xmark") {
                if draft == original || unfinished != nil { discard() } else { isConfirmingDiscard = true }
            }
            .help("Cancel writing")
            .disabled(isLoadingPhotos)
            .confirmationDialog("Discard this page?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                Button("Discard Page", role: .destructive, action: discard)
                Button("Keep Writing", role: .cancel) {}
            } message: {
                Text(entry == nil ? "What you've written here will be lost." : "Your changes to this entry will be lost.")
            }
            Spacer()
            if entry == nil && unfinished == nil {
                Button("Keep Draft", systemImage: "bookmark") {
                    if draft.photos.isEmpty { keepDraft() } else { isConfirmingKeep = true }
                }
                .labelStyle(.titleAndIcon)
                .font(Theme.bookItalic(14, relativeTo: .footnote))
                .disabled(isLoadingPhotos || draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Keep these words to finish later")
                .accessibilityIdentifier("keepDraft")
            }
            Button("Done", systemImage: "checkmark", action: save)
                .fontWeight(.semibold)
                .disabled(!draft.isValid || isLoadingPhotos || unfinished != nil)
                .help("Save entry (Command-Return on Mac)")
                #if os(macOS)
                .keyboardShortcut(.return, modifiers: .command)
                #endif
        }
        .labelStyle(.iconOnly)
        .imageScale(.large)
        .font(Theme.pageControl)
        .foregroundStyle(Theme.rubric)
        .buttonStyle(.pageControl)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    /// Steps the in-game date on by a day, for calendars it can read.
    private func nextDayButton(_ next: String) -> some View {
        Button {
            draft.inGameDate = next
        } label: {
            Label("Next day", systemImage: "arrow.forward")
        }
        .font(Theme.bookItalic(15, relativeTo: .footnote))
        .accessibilityHint("Sets the date to \(next)")
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(draft.photos) { photo in
                    ThumbnailImage(data: photo.thumbnailData, side: 64)
                        .overlay(alignment: .topTrailing) {
                            Button {
                                draft.photos.removeAll { $0.id == photo.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                            .padding(3)
                            .accessibilityLabel("Remove picture")
                        }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var tools: some View {
        HStack(alignment: .top, spacing: 22) {
            PhotosPicker(selection: $pickerItems, maxSelectionCount: 6, matching: .images) {
                Label("Add a picture", systemImage: "photo")
            }
            .disabled(isLoadingPhotos)
            .help("Add pictures from Photos")
            #if os(iOS)
            if CameraPicker.isAvailable {
                Button {
                    isShowingCamera = true
                } label: {
                    Label("Take a picture", systemImage: "camera")
                }
                .disabled(isLoadingPhotos)
            }
            #endif
            #if os(macOS)
            Button("Add picture from file", systemImage: "folder") { isImportingPhotos = true }
                .disabled(isLoadingPhotos)
                .help("Add picture files, or drop them onto this page")
            #endif
            if isLoadingPhotos {
                ProgressView()
                Text("Adding pictures \(photosLoaded) of \(photosTotal)…")
                    .font(Theme.bookItalic(14, relativeTo: .footnote))
                    .accessibilityIdentifier("photoImportProgress")
            }
            #if DEBUG
            if LaunchOptions.isUITesting && ProcessInfo.processInfo.arguments.contains("-delayedPhotoImport") {
                Button("Test picture import") {
                    beginImport([PictureImport.Source(name: "Unreadable picture", read: {
                        try await Task.sleep(for: .seconds(3))
                        return Data()
                    })])
                }.disabled(isLoadingPhotos)
            }
            #endif
            Spacer(minLength: 0)
        }
        .labelStyle(.iconOnly)
        .imageScale(.large)
        .font(Theme.pageControl)
        .foregroundStyle(Theme.rubric)
        .padding(.vertical, 10)
    }

    private func unfinishedOffer(_ saved: DraftShelf.Saved) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("An unfinished page was left here \(saved.savedAt.formatted(.relative(presentation: .named))).")
                .font(Theme.bookItalic(16))
                .foregroundStyle(Theme.fadedInk)
            if !saved.preview.isEmpty {
                Text("“\(saved.preview)”")
                    .font(Theme.book(16))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
            }
            HStack(spacing: 20) {
                Button("Carry on writing") {
                    draft = saved.draft
                    unfinished = nil
                    bodyFocused = true
                }
                .fontWeight(.semibold)
                Button("Discard it", role: .destructive) {
                    unfinished = nil
                    // Whatever was written meanwhile becomes the page kept safe.
                    drafts.keep(draft, for: journal.id)
                    bodyFocused = true
                }
            }
            .font(Theme.pageControl)
            .foregroundStyle(Theme.rubric)
        }
        .padding(.bottom, 14)
    }

    private var draftStatus: some View {
        Text(unfinished != nil ? "Choose whether to continue the unfinished page before writing." :
             entry != nil ? "Changes are kept when you save this entry." :
             draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Drafts keep words on this device. Save the entry to keep pictures." :
             "Words kept as a draft on this device. Save the entry to keep pictures.")
            .font(Theme.bookItalic(14, relativeTo: .footnote))
            .foregroundStyle(Theme.fadedInk)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 8)
            .accessibilityIdentifier("draftStatus")
    }

    #if os(macOS)
    private func loadFiles(_ urls: [URL]) {
        beginImport(urls.map { url in
            PictureImport.Source(name: url.lastPathComponent, read: {
                try await Task.detached {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    return try Data(contentsOf: url)
                }.value
            })
        })
    }
    #endif

    private func beginImport(_ sources: [PictureImport.Source]) {
        guard !isLoadingPhotos, unfinished == nil, !sources.isEmpty else { return }
        // Set before scheduling the task: even an immediate Save cannot race the import.
        isLoadingPhotos = true
        photosLoaded = 0
        photosTotal = sources.count
        Task { @MainActor in
            let report = await PictureImport.load(sources) { photosLoaded = $0 }
            draft.photos.append(contentsOf: report.photos)
            pickerItems = []
            isLoadingPhotos = false
            if !report.failures.isEmpty {
                errorMessage = "Couldn't add: " + report.failures.joined(separator: ", ") + ". Try another picture or download it to this device first. Your other pictures and writing are still here."
            }
        }
    }

    private func keepDraft() {
        guard entry == nil, unfinished == nil, !isLoadingPhotos else { return }
        drafts.keep(draft, for: journal.id)
        dismiss()
    }

    // MARK: Actions

    private func discard() {
        if entry == nil && unfinished == nil { drafts.discard(for: journal.id) }
        dismiss()
    }

    private func save() {
        guard draft.isValid, !isLoadingPhotos, unfinished == nil else { return }
        do {
            try JournalStore.save(draft, entry: entry, in: journal, context: context, drafts: drafts) { context in
                if failNextSave {
                    failNextSave = false
                    throw CocoaError(.fileWriteOutOfSpace)
                }
                try context.save()
            }
            dismiss()
        } catch {
            errorMessage = "Your entry could not be saved. Your writing is still here; try again. " + error.localizedDescription
        }
    }

    #if os(iOS)
    private func add(_ image: PlatformImage) async {
        defer { isLoadingPhotos = false }
        guard let processed = await Task.detached(operation: { PhotoProcessor.process(image) }).value else {
            errorMessage = "This picture could not be added. Your writing is still here; try again."
            return
        }
        draft.photos.append(DraftPhoto(imageData: processed.imageData, thumbnailData: processed.thumbnailData))
    }

    #endif

    private func load(_ items: [PhotosPickerItem]) {
        beginImport(items.enumerated().map { index, item in
            PictureImport.Source(name: "Picture \(index + 1)", read: {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadUnknown) }
                return data
            })
        })
    }
}
