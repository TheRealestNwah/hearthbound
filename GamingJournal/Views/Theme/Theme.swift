import CoreText
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Colour and type tokens for the in-game journal look: aged paper and ink for the pages, dark
/// wood for the shelf. Pages stay paper in dark mode, just dimmer, like a book read by candlelight.
enum Theme {
    // MARK: Pages

    /// Aged paper.
    static let paper = dynamic(light: 0xEFE2C6, dark: 0xC2AE88)
    /// The darker, scorched edge of a page. Every page text colour stays readable on it too, since
    /// text in a margin sits close to the edge (ThemeTests checks both surfaces).
    static let paperEdge = dynamic(light: 0xC9AC7C, dark: 0xAA946F, highContrastLight: 0xDCC8A2, highContrastDark: 0xB7A27D)
    /// Written text.
    static let ink = dynamic(light: 0x2E2117, dark: 0x1E150E, highContrastLight: 0x1E150E, highContrastDark: 0x120C07)
    /// Captions, page numbers and hints. Use it at full strength: fading it further drops below AA.
    static let fadedInk = dynamic(light: 0x543E2B, dark: 0x302217, highContrastLight: 0x3E2C1C, highContrastDark: 0x241910)
    /// Red ink for dates and actions, like a scribe's rubric.
    static let rubric = dynamic(light: 0x74291A, dark: 0x561A0F, highContrastLight: 0x5E1F12, highContrastDark: 0x45130A)
    /// The light text on a wax-red action such as "Take up the quill".
    static let waxInk = Color(hex: 0xF3E6CC)

    // MARK: Shelf

    /// Dark wood behind the shelf of journals, in both modes.
    static let wood = Color(hex: 0x21160F)
    static let woodLight = Color(hex: 0x33241A)
    /// Text on wood.
    static let woodInk = Color(hex: 0xEADBC0)
    static let woodFaded = Color(hex: 0xB8A283)
    /// Gilt: clasps, tooling and actions on the shelf.
    static let gold = Color(hex: 0xD6B46A)
    /// A faint warm light falling on the top of the shelf. Shelf text stays AA on wood under it.
    static let candlelight = Color(hex: 0xD6B46A).opacity(0.08)
    /// Sealing wax.
    static let wax = Color(hex: 0x8E2A1C)
    /// A wash of gilt behind searched-for words on a page. Light enough that ink stays readable.
    static let highlight = Color(hex: 0xD6B46A).opacity(0.45)

    // MARK: Type

    /// IM Fell English, the old-book face bundled with the app, scaled with Dynamic Type.
    static func book(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(BookFont.roman, size: size, relativeTo: style)
    }

    static func bookItalic(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(BookFont.italic, size: size, relativeTo: style)
    }

    /// Values already resolved by @ScaledMetric must not scale a second time.
    static func bookFixed(_ size: CGFloat) -> Font {
        .custom(BookFont.roman, fixedSize: size)
    }

    static func bookItalicFixed(_ size: CGFloat) -> Font {
        .custom(BookFont.italic, fixedSize: size)
    }

    /// Small capitals, for dates and headings.
    static func bookCaps(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(BookFont.smallCaps, size: size, relativeTo: style)
    }

    /// Entry text on a page.
    static let prose = book(19)
    /// The date above an entry.
    static let dateLine = bookCaps(19, relativeTo: .headline)
    /// Small-caps controls on a page ("‹ Journals", "Next ›").
    static let pageControl = bookCaps(18, relativeTo: .callout)

    // MARK: Helpers

    /// A colour for light and dark mode, optionally with stronger variants for Increase Contrast.
    static func dynamic(light: UInt32, dark: UInt32, highContrastLight: UInt32? = nil, highContrastDark: UInt32? = nil) -> Color {
        let lightHigh = highContrastLight ?? light
        let darkHigh = highContrastDark ?? dark
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua]) {
            case .darkAqua: NSColor(hex: dark)
            case .accessibilityHighContrastAqua: NSColor(hex: lightHigh)
            case .accessibilityHighContrastDarkAqua: NSColor(hex: darkHigh)
            default: NSColor(hex: light)
            }
        })
        #else
        return Color(UIColor { traits in
            let high = traits.accessibilityContrast == .high
            if traits.userInterfaceStyle == .dark { return UIColor(hex: high ? darkHigh : dark) }
            return UIColor(hex: high ? lightHigh : light)
        })
        #endif
    }

    /// Book-face navigation titles and a quiet navigation bar. Call once at launch.
    static func applyAppearance() {
        #if os(iOS)
        let titles: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: BookFont.smallCaps, size: 19) ?? .preferredFont(forTextStyle: .headline),
        ]
        let largeTitles: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: BookFont.roman, size: 34) ?? .preferredFont(forTextStyle: .largeTitle),
        ]
        let atRest = UINavigationBarAppearance()
        atRest.configureWithTransparentBackground()
        atRest.titleTextAttributes = titles
        atRest.largeTitleTextAttributes = largeTitles
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.titleTextAttributes = titles
        scrolled.largeTitleTextAttributes = largeTitles
        UINavigationBar.appearance().scrollEdgeAppearance = atRest
        UINavigationBar.appearance().standardAppearance = scrolled
        UINavigationBar.appearance().compactAppearance = scrolled
        #endif
    }
}

/// IM Fell English by Igino Marini (SIL Open Font License, see `Fonts/IMFellEnglish-OFL.txt`).
/// The files ship in the app bundle and are registered at launch, before anything draws text.
enum BookFont {
    static let roman = "IM_FELL_English_Roman"
    static let italic = "IM_FELL_English_Italic"
    static let smallCaps = "IM_FELL_English_SC"

    /// Registers every bundled TrueType font with the process. Safe to call more than once.
    static func register(in bundle: Bundle = .main) {
        let urls = (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        for url in urls {
            // Fails harmlessly when the font is already registered.
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension PlatformColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(hex: UInt32) {
        #if os(macOS)
        self.init(nsColor: NSColor(hex: hex))
        #else
        self.init(uiColor: UIColor(hex: hex))
        #endif
    }
}
