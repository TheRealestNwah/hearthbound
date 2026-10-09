import SwiftUI

// MARK: - Backgrounds

/// An aged page: warm paper that darkens toward scorched edges, with a faint grain drawn in code.
/// With Increase Contrast the scorch is lighter and the grain is left off, so nothing competes with
/// the writing.
struct PaperBackground: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            Theme.paper
            RadialGradient(
                colors: [.clear, .clear, Theme.paperEdge.opacity(0.55), Theme.paperEdge],
                center: .center,
                startRadius: 0,
                endRadius: 620
            )
            if contrast != .increased {
                grain
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var grain: some View {
            Canvas { context, size in
                guard size.width >= 1, size.height >= 1 else { return }
                // Fixed seed so the grain doesn't shimmer between redraws.
                var generator = SeededGenerator(seed: 0x5EED)
                let specks = Int(size.width * size.height / 700)
                for _ in 0..<specks {
                    let x = CGFloat.random(in: 0..<size.width, using: &generator)
                    let y = CGFloat.random(in: 0..<size.height, using: &generator)
                    let side = CGFloat.random(in: 0.6...1.8, using: &generator)
                    let opacity = Double.random(in: 0.04...0.10, using: &generator)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: side, height: side)),
                        with: .color(Theme.fadedInk.opacity(opacity))
                    )
                }
            }
    }
}

/// Dark wood behind the shelf.
struct WoodBackground: View {
    var body: some View {
        LinearGradient(colors: [Theme.woodLight, Theme.wood], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

/// Small deterministic random generator (SplitMix64) for decorative drawing.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// A thin rule that fades out at both ends, drawn under a page's title.
struct PageRule: View {
    var body: some View {
        LinearGradient(colors: [.clear, Theme.fadedInk.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

// MARK: - Covers

/// Leather colours for a journal's cover.
enum CoverStyle: String, CaseIterable, Identifiable, Codable {
    case ember, forest, frost, arcane, bloodMoon

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ember: "Ember"
        case .forest: "Forest"
        case .frost: "Frost"
        case .arcane: "Arcane"
        case .bloodMoon: "Blood Moon"
        }
    }

    /// Dark-to-light leather tones; covers keep the same colours in light and dark mode.
    var colors: [Color] {
        switch self {
        case .ember: [Color(hex: 0x5A2412), Color(hex: 0x8C3A17)]
        case .forest: [Color(hex: 0x1E3322), Color(hex: 0x3D6340)]
        case .frost: [Color(hex: 0x1D2F42), Color(hex: 0x3F5F80)]
        case .arcane: [Color(hex: 0x2B1C44), Color(hex: 0x5C3F8C)]
        case .bloodMoon: [Color(hex: 0x3A0D12), Color(hex: 0x7E1C24)]
        }
    }
}

/// A journal lying on the shelf: a leather band with the character's name and a gilt clasp.
struct ShelfBook: View {
    let name: String
    var subtitle: String = ""
    var style: CoverStyle = .ember
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Covers keep their colours in both modes, so this cream is fixed too. It is used at full
    /// strength: faded, it drops below AA on the lighter Forest and Frost leathers.
    private let cream = Theme.waxInk

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(Theme.book(25, relativeTo: .title2))
                    .foregroundStyle(cream)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 3)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.bookItalic(15, relativeTo: .subheadline))
                        .foregroundStyle(cream)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.leading, 34)
            .padding(.vertical, 22)
            Spacer(minLength: 12)
            // The gilt clasp.
            LinearGradient(colors: [Color(hex: 0x8A6A2A), Theme.gold, Color(hex: 0x8A6A2A)], startPoint: .leading, endPoint: .trailing)
                .frame(width: 10)
                .opacity(0.85)
                .padding(.trailing, 26)
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .background {
            ZStack(alignment: .leading) {
                LinearGradient(colors: style.colors, startPoint: .bottomLeading, endPoint: .topTrailing)
                // The spine.
                LinearGradient(colors: [.black.opacity(0.45), .black.opacity(0.05)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 22)
            }
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 6, bottomTrailingRadius: 10, topTrailingRadius: 10))
        .shadow(color: .black.opacity(0.5), radius: 6, y: 5)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Seals

/// A round wax seal with a gilt mark, for the quill button and the lock.
struct WaxSeal: View {
    var systemImage = "pencil.and.scribble"
    var size: CGFloat = 58

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xA33A2A), Theme.wax], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.7))
            Circle()
                .strokeBorder(.black.opacity(0.15), lineWidth: size * 0.05)
                .padding(size * 0.08)
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(Theme.gold)
        }
        .frame(width: size, height: size)
        .shadow(color: Color(hex: 0x3C140A).opacity(0.45), radius: 5, y: 3)
    }
}

#Preview("Components") {
    ZStack {
        PaperBackground()
        VStack(spacing: 24) {
            ShelfBook(name: "Eira Stormborn", subtitle: "Nord · Skyrim", style: .ember)
            Text("16th of Last Seed, 4E 201").font(Theme.dateLine).foregroundStyle(Theme.rubric)
            Text("The cart ride ended at a headsman's block.").font(Theme.prose)
            WaxSeal()
        }
        .padding()
    }
}

// MARK: - Search

/// A search field in the book style: gilt on the wood shelf, ink on a page.
struct BookSearchField: View {
    @Binding var text: String
    var prompt: String
    var onWood = false
    @FocusState private var isFocused: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    private var ink: Color { onWood ? Theme.woodInk : Theme.ink }
    private var faded: Color { onWood ? Theme.woodFaded : Theme.fadedInk }
    private var edge: Color {
        if isFocused { return onWood ? Theme.gold : Theme.rubric }
        if contrast == .increased { return onWood ? Theme.gold : Theme.fadedInk }
        return onWood ? Theme.gold.opacity(0.6) : Theme.fadedInk.opacity(0.5)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(faded)
                .accessibilityHidden(true)
            // Plain, so the native field doesn't paint its own light or dark box inside this one.
            TextField(prompt, text: $text, prompt: Text(prompt).foregroundStyle(faded))
                .textFieldStyle(.plain)
                .focused($isFocused)
                .font(Theme.book(18))
                .foregroundStyle(ink)
                .tint(onWood ? Theme.gold : Theme.rubric)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(faded)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 8).fill(onWood ? Color.black.opacity(0.25) : Theme.paperEdge.opacity(0.25)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(edge, lineWidth: isFocused ? 2 : 1))
    }
}

// MARK: - Fields

/// A text field written on the page: no native box (which paints dark in dark mode on a Mac), a
/// faint ruled frame that turns rubric while typing, and ink text. Give the field its own prompt
/// in `Theme.fadedInk`.
struct PaperFieldModifier: ViewModifier {
    @FocusState private var isFocused: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .focused($isFocused)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.paper.opacity(0.7)))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isFocused ? Theme.rubric : contrast == .increased ? Theme.fadedInk : Theme.fadedInk.opacity(0.45),
                                  lineWidth: isFocused ? 2 : 1)
            )
    }
}

extension View {
    func paperField() -> some View { modifier(PaperFieldModifier()) }
}

// MARK: - Forms

/// A settings-style form on a page: book type, ink labels and paper rows, in both modes. Pair
/// with `PaperSectionHeader` and `PaperSectionFooter`; default form headers and labels follow the
/// system's dark-mode text colour, which is light and unreadable on paper.
struct PaperFormModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .journalFormStyle()
            .scrollContentBackground(.hidden)
            .font(Theme.book(17))
            .foregroundStyle(Theme.ink)
            .background(PaperBackground())
    }
}

extension View {
    func paperForm() -> some View { modifier(PaperFormModifier()) }

    /// A row on a paper form.
    func paperRow() -> some View { listRowBackground(Theme.paper.opacity(0.8)) }
}

/// A form section's heading in small capitals.
struct PaperSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(Theme.bookCaps(17, relativeTo: .headline))
            .foregroundStyle(Theme.fadedInk)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The note under a form section.
struct PaperSectionFooter: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Theme.bookItalic(15, relativeTo: .footnote))
            .foregroundStyle(Theme.fadedInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Ribbon

/// A book's silk ribbon, hanging down with a notched end, marking a page.
struct RibbonMarker: View {
    var length: CGFloat = 46
    var width: CGFloat = 14

    var body: some View {
        RibbonShape()
            .fill(LinearGradient(colors: [Theme.wax, Color(hex: 0xA33A2A), Theme.wax], startPoint: .leading, endPoint: .trailing))
            .frame(width: width, height: length)
            .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
    }
}

/// A strip with a swallowtail cut at the bottom.
struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let notch = min(rect.width * 0.6, rect.height * 0.3)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - notch))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Page controls

/// Rubric-ink controls in a page's margins (Prev, Next, Done…). A disabled one fades, so it
/// doesn't look like it can still be turned to.
struct PageControlButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? Theme.rubric : Theme.fadedInk.opacity(0.45))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == PageControlButtonStyle {
    static var pageControl: PageControlButtonStyle { PageControlButtonStyle() }
}

// MARK: - Sheets

/// One of a paper sheet's two actions, such as Cancel and Begin.
struct SheetAction {
    let title: String
    let systemImage: String
    var isDisabled = false
    let action: () -> Void
}

extension View {
    /// The title and actions of a sheet that is a page: the navigation bar on iPhone and iPad, and
    /// on a Mac a header written on the paper itself, in place of the system's bar, which stays
    /// dark in dark mode. The cancel action answers Escape and the confirm action Return.
    @ViewBuilder func paperSheet(_ title: String, cancel: SheetAction? = nil, confirm: SheetAction) -> some View {
        #if os(macOS)
        safeAreaInset(edge: .top, spacing: 0) {
            MacSheetHeader(title: title, cancel: cancel, confirm: confirm)
        }
        #else
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let cancel {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(cancel.title, systemImage: cancel.systemImage, action: cancel.action)
                            .disabled(cancel.isDisabled)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirm.title, systemImage: confirm.systemImage, action: confirm.action)
                        .disabled(confirm.isDisabled)
                }
            }
        #endif
    }
}

#if os(macOS)
/// A Mac sheet's heading in small capitals with its actions in rubric, as on the writer's page.
private struct MacSheetHeader: View {
    let title: String
    let cancel: SheetAction?
    let confirm: SheetAction

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(title)
                    .font(Theme.bookCaps(22, relativeTo: .title3))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 56)
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    if let cancel {
                        button(cancel)
                            .keyboardShortcut(.cancelAction)
                    }
                    Spacer()
                    button(confirm)
                        .keyboardShortcut(cancel == nil ? .cancelAction : .defaultAction)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            PageRule()
        }
        .background(Theme.paper)
    }

    private func button(_ action: SheetAction) -> some View {
        Button(action.title, systemImage: action.systemImage, action: action.action)
            .labelStyle(.iconOnly)
            .imageScale(.large)
            .font(Theme.pageControl)
            .buttonStyle(.pageControl)
            .disabled(action.isDisabled)
            .help(action.title)
    }
}
#endif

// MARK: - Wax actions

/// The page's main action in sealing wax: cream small capitals on wax red with a gilt edge. It
/// draws its own colours, so it reads the same whether the window is active or not.
struct WaxButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.bookCaps(18, relativeTo: .callout))
            .foregroundStyle(Theme.waxInk)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.wax))
            .overlay(Capsule().strokeBorder(Theme.gold.opacity(contrast == .increased ? 1 : 0.7), lineWidth: contrast == .increased ? 2 : 1))
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
    }
}

extension ButtonStyle where Self == WaxButtonStyle {
    static var wax: WaxButtonStyle { WaxButtonStyle() }
}
