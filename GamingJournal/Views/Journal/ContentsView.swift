import SwiftUI

/// A journal's table of contents: every entry with the page it starts on, searchable, and the
/// ribbon if one is laid. Picking a line turns the book to that page.
struct ContentsView: View {
    enum Choice {
        case entry(UUID, query: String)
        case ribbon
    }

    /// Entries in reading order.
    let entries: [Entry]
    let startPages: [UUID: Int]
    let ribbonPage: Int?
    let onChoose: (Choice) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var terms: [String] { EntrySearch.terms(in: query) }

    private var shown: [Entry] {
        guard !terms.isEmpty else { return entries }
        return entries.filter { EntrySearch.matches(heading: $0.headingWithPlace(), body: $0.body, terms: terms) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !entries.isEmpty {
                        BookSearchField(text: $query, prompt: "Search this journal")
                            .padding(.bottom, 10)
                    }
                    if let ribbonPage, terms.isEmpty {
                        Button { onChoose(.ribbon) } label: {
                            HStack(spacing: 10) {
                                RibbonMarker(length: 26)
                                Text("Turn to the ribbon")
                                    .font(Theme.bookItalic(19))
                                    .foregroundStyle(Theme.rubric)
                                Spacer()
                                pageNumber(ribbonPage)
                            }
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        PageRule()
                    }
                    ForEach(shown) { entry in
                        Button { onChoose(.entry(entry.id, query: query)) } label: {
                            line(for: entry)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityHint("Turns to this entry")
                        .accessibilityIdentifier("contentsEntry")
                        PageRule()
                    }
                    if entries.isEmpty {
                        emptyNote("The pages are blank. There's nothing to list yet.")
                    } else if shown.isEmpty {
                        emptyNote("No entry speaks of “\(query.trimmingCharacters(in: .whitespaces))”.")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(PaperBackground())
            .navigationTitle("Contents")
            .inlineJournalTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .journalCommandActions(JournalCommandActions())
        .tint(Theme.rubric)
        .journalSheetSize()
    }

    private func line(for entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.heading())
                    .font(Theme.bookCaps(18, relativeTo: .headline))
                    .foregroundStyle(Theme.rubric)
                Spacer(minLength: 8)
                if let page = startPages[entry.id] {
                    pageNumber(page)
                }
            }
            if !entry.place.isEmpty {
                Text(entry.place)
                    .font(Theme.bookItalic(16))
                    .foregroundStyle(Theme.fadedInk)
            }
            let words = terms.isEmpty ? EntrySearch.opening(of: entry.body, length: 90) : EntrySearch.snippet(of: entry.body, around: terms)
            if !words.isEmpty {
                Text(words)
                    .font(Theme.book(17))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func pageNumber(_ index: Int) -> some View {
        Text("p. \(index + 1)")
            .font(Theme.bookItalic(16, relativeTo: .footnote))
            .foregroundStyle(Theme.fadedInk)
            .accessibilityLabel("page \(index + 1)")
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(Theme.bookItalic(18))
            .foregroundStyle(Theme.fadedInk)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, 24)
    }
}
