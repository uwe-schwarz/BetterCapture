import Testing
@testable import BetterCapture

struct ScreenshotFingerprintTests {
    private let white = [UInt8](repeating: 255, count: 20_000)

    @Test func identicalScreensAndCursorMovementAreIgnored() {
        let original = ScreenshotFingerprint(width: 200, pixels: white)
        #expect(!original.differsSignificantly(from: original))
        var cursor = white
        cursor.replaceSubrange(0..<20, with: repeatElement(UInt8(0), count: 20))
        #expect(!ScreenshotFingerprint(width: 200, pixels: cursor).differsSignificantly(from: original))
    }

    @Test func sparseDocumentTextChangesAreDetected() {
        var edited = white
        for index in stride(from: 0, to: edited.count, by: 20) { edited[index] = 0 }
        #expect(ScreenshotFingerprint(width: 200, pixels: edited)
            .differsSignificantly(from: ScreenshotFingerprint(width: 200, pixels: white)))
    }

    @Test func cameraMotionOutsideDocumentMaskIsIgnored() {
        var before = white
        var after = white
        for index in 15_000..<20_000 {
            before[index] = 0
            after[index] = 120
        }
        #expect(!ScreenshotFingerprint(width: 200, pixels: after)
            .differsSignificantly(from: ScreenshotFingerprint(width: 200, pixels: before)))
    }

    @Test func largeDiagramChangesOutsideTheMaskAreDetected() {
        var before = white
        var after = white
        for index in 13_000..<20_000 {
            before[index] = 0
            after[index] = 120
        }
        #expect(ScreenshotFingerprint(width: 200, pixels: after)
            .differsSignificantly(from: ScreenshotFingerprint(width: 200, pixels: before)))
    }

    @Test func sceneChangesRequireThirtyPercentAndIgnoreSmallNoise() {
        let dark = [UInt8](repeating: 40, count: 20_000)
        let original = ScreenshotFingerprint(width: 200, pixels: dark)
        #expect(!ScreenshotFingerprint(width: 200, pixels: dark.map { $0 + 23 }).differsSignificantly(from: original))
        var changed = dark
        changed.replaceSubrange(0..<6000, with: repeatElement(UInt8(100), count: 6000))
        #expect(ScreenshotFingerprint(width: 200, pixels: changed).differsSignificantly(from: original))
    }

    @Test func changedDimensionsAndContentModeAreCaptured() {
        let original = ScreenshotFingerprint(width: 200, pixels: white)
        #expect(ScreenshotFingerprint(width: 100, pixels: white).differsSignificantly(from: original))
        #expect(ScreenshotFingerprint(width: 200, pixels: white.map { _ in 0 }).differsSignificantly(from: original))
    }
}
