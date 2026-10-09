#if os(macOS)
import AppKit
import SwiftUI

struct ShareSheet: View {
    let items: [Any]
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 16) {
            if let image = items.first as? NSImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 400)
                    .overlay(Rectangle().strokeBorder(Theme.paperEdge, lineWidth: 1))
                    .layoutPriority(-1)
                    .accessibilityLabel("Picture of the page")
            }
            NativeShareButton(items: items)
                .fixedSize()
        }
        .padding(24)
        .frame(minWidth: 400, minHeight: 360)
        .background(PaperBackground())
        .paperSheet("Share this page", confirm: SheetAction(title: "Close", systemImage: "xmark") { dismiss() })
    }
}

private struct NativeShareButton: NSViewRepresentable {
    let items: [Any]
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "Share…", target: context.coordinator, action: #selector(Coordinator.share(_:)))
        button.bezelStyle = .rounded
        // Sized by its title, so larger text isn't clipped; drawn light to match the paper.
        button.controlSize = .large
        button.appearance = NSAppearance(named: .aqua)
        button.setAccessibilityLabel("Share")
        return button
    }
    func updateNSView(_ button: NSButton, context: Context) { context.coordinator.items = items }
    final class Coordinator: NSObject {
        var items: [Any] = []
        private var picker: NSSharingServicePicker?
        @objc func share(_ sender: NSButton) {
            let picker = NSSharingServicePicker(items: items)
            self.picker = picker
            picker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
}
#endif
