import SwiftUI
import SwiftData

/// Home: every character's journal lying on a dark wood shelf.
struct ShelfView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Journal.updatedAt, order: .reverse) private var journals: [Journal]
    @Binding var path: [JournalRoute]
    @State private var isCreating = false
    @State private var resuming: Journal?
    @State private var draftRevision = 0
    @State private var errorMessage: String?
    @State private var editing: Journal?
    @State private var pendingDelete: Journal?
    @State private var isShowingSettings = false
    @State private var query = ""
    @State private var isSearching = false
    @State private var opening: BookOpening?
    @State private var bookFrames = BookFrames()
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    if isSearching && !journals.isEmpty {
                        BookSearchField(text: $query, prompt: "Search the journals", onWood: true)
                            .focused($searchFocused)
                            .onAppear { searchFocused = true }
                    }
                    if EntrySearch.terms(in: query).isEmpty {
                        books
                    } else {
                        SearchResults(results: EntrySearch.results(for: query, in: journals), query: query) { result in
                            guard let journal = journals.first(where: { $0.id == result.journalID }) else { return }
                            path.append(JournalRoute(journal: journal, entryID: result.entryID, highlight: query))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: 620)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isSearching)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(WoodBackground())
            .navigationTitle("Journals")
            // Inline, so the hidden principal item replaces the title instead of a large one showing.
            .inlineJournalTitle()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // The shelf's own heading does the job; keep the bar clear.
                    Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if !journals.isEmpty {
                        Button(isSearching ? "Close search" : "Search", systemImage: isSearching ? "xmark" : "magnifyingglass") {
                            toggleSearch()
                        }
                        .keyboardShortcut("f", modifiers: .command)
                        .help("Search journals (Command-F)")
                    }
                    Button("Begin a new journal", systemImage: "plus") { isCreating = true }
                        .keyboardShortcut("n", modifiers: [.command, .shift])
                        .help("Begin a new journal (Command-Shift-N)")
                    Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
                        .help("Settings (Command-comma)")
                }
            }
            .tint(Theme.gold)
            .journalNavigationBackground()
            .navigationDestination(for: JournalRoute.self) { route in
                JournalView(journal: route.journal, focusEntryID: route.entryID, highlight: route.highlight,
                            onSettings: { isShowingSettings = true }, onNewJournal: { isCreating = true })
            }
        }
        .overlay {
            if let opening {
                BookOpeningOverlay(opening: opening)
                    .transition(.opacity)
            }
        }
        .journalCommandActions(isCreating || editing != nil || isShowingSettings || resuming != nil ? JournalCommandActions() :
            JournalCommandActions(settings: { isShowingSettings = true }, newJournal: { isCreating = true },
                                  find: journals.isEmpty ? nil : { isSearching = true; searchFocused = true }))
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in draftRevision += 1 }
        .journalCover(item: $resuming) { journal in WriterView(journal: journal) }
        .alert("Could not save the change", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .sheet(isPresented: $isCreating) {
            JournalEditorView { journal in path = [JournalRoute(journal: journal)] }
        }
        .sheet(item: $editing) { journal in
            JournalEditorView(journal: journal)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .confirmationDialog(
            "Delete this journal?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { journal in
            Button("Delete \(journal.characterName)'s journal", role: .destructive) {
                let id = journal.id
                do {
                    try JournalStore.commit(in: context, restore: JournalStore.restoration(for: journal, includingEntries: true)) { context.delete(journal) }
                    path.removeAll { $0.journal.id == id }
                    DraftShelf().discard(for: id)
                    ShelfMemory().forget(id)
                    RibbonShelf().setMark(nil, for: id)
                } catch { errorMessage = "The journal could not be deleted. " + error.localizedDescription }
            }
        } message: { _ in
            Text("Every page in it is lost. This can't be undone.")
        }
        #if os(iOS)
        .sensoryFeedback(.success, trigger: journals.count) { old, new in new > old }
        #endif
    }

    /// The journals on the shelf, or a blank book to begin one when there are none.
    @ViewBuilder
    private var books: some View {
        let _ = draftRevision
        let lastOpened = ShelfMemory().lastOpened
        ForEach(journals) { journal in
            Button { open(journal) } label: {
                cover(for: journal, isLastOpened: journal.id == lastOpened)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the journal")
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { [bookFrames] frame in
                bookFrames.frames[journal.id] = frame
            }
            .contextMenu {
                Button("Edit", systemImage: "pencil") { editing = journal }
                Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = journal }
            }
            if let saved = DraftShelf().saved(for: journal.id) {
                Button { resuming = journal } label: {
                    Label("Continue unfinished page", systemImage: "bookmark")
                        .font(Theme.bookItalic(16, relativeTo: .subheadline))
                        .foregroundStyle(Theme.gold)
                }
                .buttonStyle(.plain)
                .accessibilityHint(saved.preview)
                .accessibilityIdentifier("resumeDraft")
            }
        }
        if journals.isEmpty {
            Button { isCreating = true } label: { BlankBook() }
                .buttonStyle(.plain)
                .accessibilityIdentifier("blankJournal")
                .padding(.top, 12)
        }
    }

    /// A journal's cover, with its latest entry's date as a quiet note of where the story stands.
    private func cover(for journal: Journal, isLastOpened: Bool) -> ShelfBook {
        ShelfBook(name: journal.characterName, subtitle: journal.subtitle, style: journal.coverStyle,
                  caption: journal.latestEntry.map { "Last entry: \($0.heading())" } ?? "",
                  isLastOpened: isLastOpened)
    }

    /// Opens a journal: the book comes forward and its cover swings open onto the reader. With
    /// Reduce Motion, or under UI tests (whose screenshots would catch it mid-way), the reader
    /// opens at once.
    private func open(_ journal: Journal) {
        guard opening == nil else { return }
        let route = JournalRoute(journal: journal)
        guard !reduceMotion, !LaunchOptions.isUITesting, let frame = bookFrames.frames[journal.id] else {
            path.append(route)
            return
        }
        opening = BookOpening(cover: cover(for: journal, isLastOpened: journal.id == ShelfMemory().lastOpened), frame: frame)
        // A turn later, so the overlay is drawn where the book lies before it moves.
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.25)) { opening?.stage = .forward } completion: {
                withAnimation(.easeInOut(duration: 0.3)) { opening?.stage = .open } completion: {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { path.append(route) }
                    withAnimation(.easeIn(duration: 0.2).delay(0.05)) { opening = nil }
                }
            }
        }
    }

    /// Shows the search field, focused, or closes it and clears the search.
    private func toggleSearch() {
        if isSearching {
            query = ""
            isSearching = false
        } else {
            isSearching = true
        }
    }

    private var header: some View {
        Text("Journals")
            .font(Theme.book(40, relativeTo: .largeTitle))
            .foregroundStyle(Theme.woodInk)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 8)
            .padding(.bottom, 6)
    }
}

/// Start a journal, or change an existing one's character, game and cover.
struct JournalEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    private let journal: Journal?
    private let onCreate: ((Journal) -> Void)?
    @State private var characterName: String
    @State private var epithet: String
    @State private var gameTitle: String
    @State private var coverStyle: CoverStyle
    @FocusState private var nameFocused: Bool
    @State private var errorMessage: String?

    init(journal: Journal? = nil, onCreate: ((Journal) -> Void)? = nil) {
        self.journal = journal
        self.onCreate = onCreate
        _characterName = State(initialValue: journal?.characterName ?? "")
        _epithet = State(initialValue: journal?.epithet ?? "")
        _gameTitle = State(initialValue: journal?.gameTitle ?? "")
        _coverStyle = State(initialValue: journal?.coverStyle ?? .ember)
    }

    private var trimmedName: String {
        characterName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ScaledMetric(relativeTo: .body) private var coverChoiceWidth: CGFloat = 76

    /// A labelled field, so what it's for stays clear once something is written in it.
    private func field(_ label: String, text: Binding<String>, prompt: String, font: Font = Theme.book(17),
                       focus: FocusState<Bool>.Binding? = nil, identifier: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Theme.bookCaps(15, relativeTo: .subheadline))
                .foregroundStyle(Theme.fadedInk)
                .accessibilityHidden(true)
            Group {
                if let focus {
                    TextField(label, text: text, prompt: Text(prompt).foregroundStyle(Theme.fadedInk)).focused(focus)
                } else {
                    TextField(label, text: text, prompt: Text(prompt).foregroundStyle(Theme.fadedInk))
                }
            }
            .font(font)
            .foregroundStyle(Theme.ink)
            .capitalizedWords()
            // The caption above names the field; a Mac form would repeat it beside the box.
            .labelsHidden()
            .accessibilityIdentifier(identifier ?? label)
            .paperField()
        }
        .padding(.vertical, 2)
    }

    /// A leather swatch with its name beneath, and a gilt ring and tick on the chosen one, so the
    /// choice doesn't rest on colour alone.
    private func coverChoice(_ style: CoverStyle) -> some View {
        let isChosen = coverStyle == style
        return Button { coverStyle = style } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(LinearGradient(colors: style.colors, startPoint: .bottomLeading, endPoint: .topTrailing))
                    .frame(width: 40, height: 40)
                    .overlay(Circle().strokeBorder(Theme.gold, lineWidth: isChosen ? 3 : 0))
                    .overlay {
                        if isChosen {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.waxInk)
                        }
                    }
                Text(style.label)
                    .font(isChosen ? Theme.bookCaps(15, relativeTo: .footnote) : Theme.book(15, relativeTo: .footnote))
                    .foregroundStyle(isChosen ? Theme.rubric : Theme.fadedInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(style.label)
        .accessibilityAddTraits(isChosen ? [.isButton, .isSelected] : .isButton)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    field("Character's name", text: $characterName, prompt: "e.g. Eira Stormborn",
                          font: Theme.book(20, relativeTo: .title3), focus: $nameFocused, identifier: "characterName")
                    field("Race, class or title", text: $epithet, prompt: "e.g. Nord warrior")
                    field("Game", text: $gameTitle, prompt: "e.g. Skyrim")
                } footer: {
                    PaperSectionFooter("The journal is written by this character, in their own words.")
                }
                .paperRow()

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: coverChoiceWidth), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                        ForEach(CoverStyle.allCases) { style in
                            coverChoice(style)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    PaperSectionHeader("Cover")
                }
                .paperRow()
            }
            .paperForm()
            .paperSheet(
                journal == nil ? "New Journal" : "Edit Journal",
                cancel: SheetAction(title: "Cancel", systemImage: "xmark") { dismiss() },
                confirm: SheetAction(title: journal == nil ? "Begin" : "Save", systemImage: "checkmark", isDisabled: trimmedName.isEmpty, action: save)
            )
            .onAppear { if journal == nil { nameFocused = true } }
        }
        .tint(Theme.rubric)
        .journalSheetSize()
        .journalCommandActions(JournalCommandActions())
        .alert("Could not save the journal", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        do {
            let restore = journal.map { JournalStore.restoration(for: $0) } ?? {}
            let saved = try JournalStore.commit(in: context, restore: restore) {
                if let journal {
                    journal.characterName = trimmedName
                    journal.epithet = epithet.trimmingCharacters(in: .whitespacesAndNewlines)
                    journal.gameTitle = gameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    journal.coverStyle = coverStyle
                    journal.touch()
                    return journal
                }
                let created = Journal(characterName: trimmedName, epithet: epithet, gameTitle: gameTitle, coverStyle: coverStyle)
                context.insert(created)
                return created
            }
            dismiss()
            if journal == nil { onCreate?(saved) }
        } catch { errorMessage = "Your changes are still here. Try saving again. " + error.localizedDescription }
    }
}

/// A journal to open from the shelf, at one entry's page when a search result points there, with
/// the words searched for marked on it.
struct JournalRoute: Hashable {
    let journal: Journal
    var entryID: UUID?
    var highlight = ""
}

/// Entries matching a search on the shelf. Tapping one opens its journal at that page.
private struct SearchResults: View {
    let results: [EntrySearch.Result]
    let query: String
    let onOpen: (EntrySearch.Result) -> Void

    var body: some View {
        if results.isEmpty {
            Text("No entry speaks of “\(query.trimmingCharacters(in: .whitespaces))”.")
                .font(Theme.bookItalic(18))
                .foregroundStyle(Theme.woodFaded)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(results) { result in
                    Button { onOpen(result) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(result.characterName)
                                    .font(Theme.bookCaps(16, relativeTo: .subheadline))
                                    .foregroundStyle(Theme.gold)
                                Spacer(minLength: 8)
                                Text(result.heading)
                                    .font(Theme.bookItalic(15, relativeTo: .footnote))
                                    .foregroundStyle(Theme.woodFaded)
                                    .multilineTextAlignment(.trailing)
                            }
                            if !result.snippet.isEmpty {
                                Text(result.snippet)
                                    .font(Theme.book(17))
                                    .foregroundStyle(Theme.woodInk)
                                    .lineLimit(3)
                            }
                        }
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Opens the journal at this entry")
                    Rectangle()
                        .fill(Theme.gold.opacity(0.25))
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}
