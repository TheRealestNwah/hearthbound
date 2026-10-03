import SwiftUI
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
typealias PlatformColor = NSColor
typealias PlatformFont = NSFont
#else
import UIKit
typealias PlatformImage = UIImage
typealias PlatformColor = UIColor
typealias PlatformFont = UIFont
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

extension View {
    @ViewBuilder func inlineJournalTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
    @ViewBuilder func journalNavigationBackground() -> some View {
        #if os(iOS)
        toolbarBackground(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
    @ViewBuilder func journalNavigationHidden() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        navigationBarBackButtonHidden(true)
        #endif
    }
    @ViewBuilder func capitalizedWords() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.words)
        #else
        self
        #endif
    }
    /// The automatic Mac form uses a label grid that can overflow a compact sheet.
    @ViewBuilder func journalFormStyle() -> some View {
        #if os(macOS)
        formStyle(.grouped)
        #else
        self
        #endif
    }
    /// Mac sheets need an explicit useful size; iPad keeps its system presentation.
    @ViewBuilder func journalSheetSize() -> some View {
        #if os(macOS)
        frame(minWidth: 560, idealWidth: 640, minHeight: 480, idealHeight: 650)
        #else
        self
        #endif
    }
    @ViewBuilder func journalCover<Item: Identifiable, Content: View>(item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        #if os(macOS)
        sheet(item: item) { item in content(item).journalSheetSize() }
        #else
        fullScreenCover(item: item, content: content)
        #endif
    }
    @ViewBuilder func journalCover<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(macOS)
        sheet(isPresented: isPresented) { content().journalSheetSize() }
        #else
        fullScreenCover(isPresented: isPresented, content: content)
        #endif
    }
}
