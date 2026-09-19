import CoreGraphics
import Testing
@testable import BetterCapture

struct ScreenshotFingerprintTests {
    private let white = [UInt8](repeating: 255, count: 20_000)

    @Test(arguments: [UInt8(20), 100, 200, 255])
    func identicalScreensAndCursorMovementAreIgnored(background: UInt8) {
        let pixels = white.map { _ in background }
        let original = ScreenshotFingerprint(width: 200, pixels: pixels)
        #expect(!original.differsSignificantly(from: original))
        var cursor = pixels
        cursor.replaceSubrange(0..<20, with: repeatElement(background < 128 ? UInt8(255) : 0, count: 20))
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

    @Test func cameraTextureBesideDarkDocumentIsIgnored() {
        var before = [UInt8](repeating: 30, count: 20_000)
        for index in stride(from: 0, to: 15_000, by: 20) { before[index] = 220 }
        var after = before
        for index in 15_000..<20_000 {
            before[index] = UInt8((index * 37) % 256)
            after[index] = UInt8((index * 73) % 256)
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

    @Test(arguments: [0.08, 0.35, 0.80, 1.0], [false, true])
    func browserScrollingIsDetectedInEitherTheme(background: Double, embedded: Bool) throws {
        let original = try ScreenshotFingerprint(image: browser(background: background, embedded: embedded))
        let scrolled = try ScreenshotFingerprint(image: browser(background: background, embedded: embedded, scroll: 12))
        #expect(scrolled.differsSignificantly(from: original))
        #expect(!original.differsSignificantly(from: original))
    }

    @Test(arguments: [0.08, 1.0])
    func browserNavigationAndReturningToAPageAreDetected(background: Double) throws {
        let original = try ScreenshotFingerprint(image: browser(background: background, embedded: true))
        let nextPage = try ScreenshotFingerprint(image: browser(background: background, embedded: true, page: 1))
        #expect(nextPage.differsSignificantly(from: original))
        #expect(original.differsSignificantly(from: nextPage))
    }

    /// Sparse text in a shared browser surrounded by unchanged meeting chrome.
    /// Rendering at capture resolution also exercises the comparison's downsampling.
    private func browser(background: Double, embedded: Bool, scroll: Int = 0, page: Int = 0) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: 1920, height: 1200, bitsPerComponent: 8, bytesPerRow: 1920,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ))
        context.setFillColor(gray: 0.18, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 1920, height: 1200))
        let viewport = embedded ? CGRect(x: 100, y: 180, width: 1200, height: 780)
                                : CGRect(x: 0, y: 0, width: 1920, height: 1200)
        context.clip(to: viewport)
        context.setFillColor(gray: background, alpha: 1)
        context.fill(viewport)
        context.setFillColor(gray: background < 0.5 ? 0.95 : 0.08, alpha: 1)
        for row in 0..<50 {
            let length = 40 + (row * 17 + page * 31) % 45
            for column in 0..<length where !(column + row + page).isMultiple(of: 7) {
                context.fill(CGRect(
                    x: Int(viewport.minX) + 60 + column * 11,
                    y: Int(viewport.minY) + 25 + row * 28 - scroll,
                    width: 6, height: 11
                ))
            }
        }
        return try #require(context.makeImage())
    }
}
