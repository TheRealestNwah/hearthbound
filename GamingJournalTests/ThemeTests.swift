import XCTest
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import GamingJournal

/// Keeps the pages and the shelf readable: text colours must meet WCAG AA (4.5:1) on the surfaces
/// they sit on, in both light and dark mode.
final class ThemeContrastTests: XCTestCase {
    /// Every look a page is read in: light and dark, each with and without Increase Contrast.
    private let looks: [(dark: Bool, high: Bool)] = [(false, false), (true, false), (false, true), (true, true)]

    private func lookName(dark: Bool, high: Bool) -> String {
        (dark ? "dark" : "light") + (high ? ", increased contrast" : "")
    }

    private func components(_ color: Color, dark: Bool, high: Bool = false) -> (Double, Double, Double, Double) {
        #if os(macOS)
        var rgba = (0.0, 0.0, 0.0, 1.0)
        let name: NSAppearance.Name = high
            ? (dark ? .accessibilityHighContrastDarkAqua : .accessibilityHighContrastAqua)
            : (dark ? .darkAqua : .aqua)
        NSAppearance(named: name)!.performAsCurrentDrawingAppearance {
            let resolved = NSColor(color).usingColorSpace(.deviceRGB)!
            rgba = (Double(resolved.redComponent), Double(resolved.greenComponent), Double(resolved.blueComponent), Double(resolved.alphaComponent))
        }
        return rgba
        #else
        let traits = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: dark ? .dark : .light),
            UITraitCollection(accessibilityContrast: high ? .high : .normal),
        ])
        let resolved = UIColor(color).resolvedColor(with: traits)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue), Double(alpha))
        #endif
    }

    /// The colour seen when `top` (with its opacity) is drawn over the opaque `bottom`.
    private func composite(_ top: Color, over bottom: Color, dark: Bool, high: Bool = false) -> (Double, Double, Double) {
        let (r, g, b, a) = components(top, dark: dark, high: high)
        let (br, bg, bb, _) = components(bottom, dark: dark, high: high)
        return (r * a + br * (1 - a), g * a + bg * (1 - a), b * a + bb * (1 - a))
    }

    private func luminance(_ rgb: (Double, Double, Double)) -> Double {
        func channel(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(rgb.0) + 0.7152 * channel(rgb.1) + 0.0722 * channel(rgb.2)
    }

    private func luminance(_ color: Color, dark: Bool, high: Bool = false) -> Double {
        let (r, g, b, _) = components(color, dark: dark, high: high)
        return luminance((r, g, b))
    }

    private func ratio(_ la: Double, _ lb: Double) -> Double {
        (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private func contrast(_ a: Color, _ b: Color, dark: Bool, high: Bool = false) -> Double {
        ratio(luminance(a, dark: dark, high: high), luminance(b, dark: dark, high: high))
    }

    private let pageText: [(String, Color)] = [("ink", Theme.ink), ("fadedInk", Theme.fadedInk), ("rubric", Theme.rubric)]

    func testPageTextMeetsAAOnPaper() {
        for (dark, high) in looks {
            for (name, color) in pageText {
                let ratio = contrast(color, Theme.paper, dark: dark, high: high)
                XCTAssertGreaterThanOrEqual(
                    ratio, 4.5,
                    "\(name) on paper (\(lookName(dark: dark, high: high))) is \(String(format: "%.2f", ratio)):1"
                )
            }
        }
    }

    /// PaperBackground darkens all the way to `paperEdge` at a page's corners, where margin
    /// controls and page numbers sit, so text must stay readable on the darkest surface too.
    func testPageTextMeetsAAOnScorchedEdge() {
        for (dark, high) in looks {
            for (name, color) in pageText {
                let ratio = contrast(color, Theme.paperEdge, dark: dark, high: high)
                XCTAssertGreaterThanOrEqual(
                    ratio, 4.5,
                    "\(name) on the paper's edge (\(lookName(dark: dark, high: high))) is \(String(format: "%.2f", ratio)):1"
                )
            }
        }
    }

    /// Paper fields and search boxes lay a translucent wash over the page; hints and typed text
    /// inside them must still read on the darkest page under them.
    func testTextMeetsAAInsidePaperFieldsAndSearch() {
        let washes: [(String, Color)] = [("paper field", Theme.paper.opacity(0.7)), ("page search", Theme.paperEdge.opacity(0.25))]
        for (dark, high) in looks {
            for (washName, wash) in washes {
                let surface = luminance(composite(wash, over: Theme.paperEdge, dark: dark, high: high))
                for (name, color) in pageText {
                    let value = ratio(luminance(color, dark: dark, high: high), surface)
                    XCTAssertGreaterThanOrEqual(
                        value, 4.5,
                        "\(name) in a \(washName) (\(lookName(dark: dark, high: high))) is \(String(format: "%.2f", value)):1"
                    )
                }
            }
        }
    }

    /// Covers keep their colours in both modes; the subtitle must read on each leather's lightest tone.
    func testCoverTextMeetsAAOnEveryLeather() {
        for style in CoverStyle.allCases {
            for tone in style.colors {
                let ratio = contrast(Theme.waxInk, tone, dark: false)
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "Cover text on \(style.label) is \(String(format: "%.2f", ratio)):1")
            }
        }
    }

    func testWaxActionTextMeetsAA() {
        let ratio = contrast(Theme.waxInk, Theme.wax, dark: false)
        XCTAssertGreaterThanOrEqual(ratio, 4.5, "Text on wax is \(String(format: "%.2f", ratio)):1")
    }

    /// Shelf search sits in a dark wash over the wood.
    func testShelfSearchTextMeetsAA() {
        for surface in [Theme.wood, Theme.woodLight] {
            let field = luminance(composite(Color.black.opacity(0.25), over: surface, dark: false))
            for (name, color) in [("woodInk", Theme.woodInk), ("woodFaded", Theme.woodFaded)] {
                let value = ratio(luminance(color, dark: false), field)
                XCTAssertGreaterThanOrEqual(value, 4.5, "\(name) in shelf search is \(String(format: "%.2f", value)):1")
            }
        }
    }

    /// A disabled page control is meant to look unavailable, so it stays clearly fainter than the
    /// enabled rubric rather than meeting text contrast.
    func testDisabledPageControlLooksFainterThanEnabled() {
        for (dark, high) in looks {
            let disabled = ratio(luminance(composite(Theme.fadedInk.opacity(0.45), over: Theme.paper, dark: dark, high: high)),
                                 luminance(Theme.paper, dark: dark, high: high))
            let enabled = contrast(Theme.rubric, Theme.paper, dark: dark, high: high)
            XCTAssertLessThan(disabled * 2, enabled, "Disabled and enabled controls look too alike (\(lookName(dark: dark, high: high)))")
        }
    }

    func testShelfTextMeetsAAOnWood() {
        let text: [(String, Color)] = [("woodInk", Theme.woodInk), ("woodFaded", Theme.woodFaded), ("gold", Theme.gold)]
        for (name, color) in text {
            for surface in [Theme.wood, Theme.woodLight] {
                let ratio = contrast(color, surface, dark: false)
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(name) on wood is \(String(format: "%.2f", ratio)):1")
            }
        }
    }

    /// The candlelight warms the top of the shelf, where the heading and first books sit.
    func testShelfTextMeetsAAUnderCandlelight() {
        for surface in [Theme.wood, Theme.woodLight] {
            let lit = luminance(composite(Theme.candlelight, over: surface, dark: false))
            for (name, color) in [("woodInk", Theme.woodInk), ("woodFaded", Theme.woodFaded), ("gold", Theme.gold)] {
                let measured = ratio(luminance(color, dark: false), lit)
                XCTAssertGreaterThanOrEqual(measured, 4.5, "\(name) under candlelight is \(String(format: "%.2f", measured)):1")
            }
        }
    }

    /// The gilt name sits on each cover's title plate.
    func testGiltTitleMeetsAAOnEveryPlate() {
        for style in CoverStyle.allCases {
            for (name, color) in [("gold", Theme.gold), ("cream", Theme.waxInk)] {
                let ratio = contrast(color, style.plate, dark: false)
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(name) on the \(style.label) plate is \(String(format: "%.2f", ratio)):1")
            }
        }
    }

    func testSeededGeneratorIsDeterministic() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        XCTAssertEqual((0..<5).map { _ in a.next() }, (0..<5).map { _ in b.next() })
    }
}

/// The bundled book face must load, or every page silently falls back to the system font.
final class BookFontTests: XCTestCase {
    func testBundledFontsAreRegistered() {
        BookFont.register()
        for name in [BookFont.roman, BookFont.italic, BookFont.smallCaps] {
            XCTAssertNotNil(PlatformFont(name: name, size: 17), "\(name) isn't available")
        }
    }
}
