import Foundation

/// Loads pictures in selection order and reports failed items without dropping successes.
@MainActor
enum PictureImport {
    struct Source {
        var name: String
        var read: () async throws -> Data
    }
    struct Report {
        var photos: [DraftPhoto] = []
        var failures: [String] = []
    }
    static func load(_ sources: [Source], progress: (Int) -> Void) async -> Report {
        var report = Report()
        for (index, source) in sources.enumerated() {
            do {
                let data = try await source.read()
                guard let image = await Task.detached(operation: { PhotoProcessor.process(data) }).value else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                report.photos.append(DraftPhoto(imageData: image.imageData, thumbnailData: image.thumbnailData))
            } catch {
                report.failures.append(source.name)
            }
            progress(index + 1)
        }
        return report
    }
}
