import SwiftUI

/// Where each book lies on screen, in global coordinates. A plain reference, not view state, so
/// scrolling the shelf doesn't redraw it.
final class BookFrames {
    var frames: [UUID: CGRect] = [:]
}

/// A journal being opened from the shelf: the book comes forward, its cover swings open and the
/// page beneath spreads to fill the screen, then the reader takes its place.
struct BookOpening {
    enum Stage { case resting, forward, open }

    let cover: ShelfBook
    /// Where the book lay on the shelf, in global coordinates.
    let frame: CGRect
    var stage = Stage.resting
}

/// Draws a `BookOpening` over the whole shelf. Purely decorative: hidden from VoiceOver, and it
/// holds back taps only while the book is moving.
struct BookOpeningOverlay: View {
    let opening: BookOpening

    var body: some View {
        GeometryReader { geometry in
            let origin = geometry.frame(in: .global).origin
            let start = opening.frame.offsetBy(dx: -origin.x, dy: -origin.y)
            let scale = opening.stage == .resting ? 1 : min(1.15, max(1, (geometry.size.width - 32) / max(start.width, 1)))
            let center = opening.stage == .resting
                ? CGPoint(x: start.midX, y: start.midY)
                : CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let book = CGRect(x: center.x - start.width * scale / 2, y: center.y - start.height * scale / 2,
                              width: start.width * scale, height: start.height * scale)
            let page = opening.stage == .open ? CGRect(origin: .zero, size: geometry.size) : book.insetBy(dx: 4, dy: 4)

            ZStack {
                Color.black.opacity(opening.stage == .resting ? 0 : 0.4)
                PaperBackground()
                    .frame(width: page.width, height: page.height)
                    .clipShape(RoundedRectangle(cornerRadius: opening.stage == .open ? 0 : 8))
                    .position(x: page.midX, y: page.midY)
                opening.cover
                    .frame(width: start.width, height: start.height)
                    .rotation3DEffect(.degrees(opening.stage == .open ? -110 : 0), axis: (x: 0, y: 1, z: 0),
                                      anchor: .leading, perspective: 0.5)
                    .opacity(opening.stage == .open ? 0 : 1)
                    .scaleEffect(scale)
                    .position(x: center.x, y: center.y)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
