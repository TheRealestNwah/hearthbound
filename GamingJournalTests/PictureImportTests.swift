import XCTest
@testable import GamingJournal

@MainActor
final class PictureImportTests: XCTestCase {
    func testPartialFailureKeepsSuccessfulPhotosAndReportsProgress() async throws {
        let png = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNocFAAAAIkAOGrWWInAAAAAElFTkSuQmCC"))
        var progress: [Int] = []
        let sources = [
            PictureImport.Source(name: "Good picture", read: { png }),
            PictureImport.Source(name: "Corrupt picture", read: { Data([0, 1]) }),
            PictureImport.Source(name: "Unavailable picture", read: { throw CocoaError(.fileReadNoPermission) })
        ]
        let report = await PictureImport.load(sources) { progress.append($0) }
        XCTAssertEqual(report.photos.count, 1)
        XCTAssertEqual(report.failures, ["Corrupt picture", "Unavailable picture"])
        XCTAssertEqual(progress, [1, 2, 3])
    }
}
