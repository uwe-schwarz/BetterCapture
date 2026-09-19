import CoreGraphics
import Foundation

/// A bounded grayscale comparison of text on locally uniform backgrounds.
/// Content masks work in either theme, even inside a larger meeting window.
nonisolated struct ScreenshotFingerprint: Sendable {
    let width: Int
    let pixels: [UInt8]
    private let documentMask: [Bool]

    init(image: CGImage) throws {
        let width = min(640, image.width)
        let height = max(1, Int((Double(image.height) * Double(width) / Double(image.width)).rounded()))
        var pixels = [UInt8](repeating: 0, count: width * height)
        let rendered = pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else { throw ScreenshotRecordingError.imageEncodingFailed }
        self.init(width: width, pixels: pixels)
    }

    init(width: Int, pixels: [UInt8]) {
        precondition(width > 0 && !pixels.isEmpty && pixels.count.isMultiple(of: width))
        self.width = width
        self.pixels = pixels
        documentMask = Self.makeDocumentMask(width: width, pixels: pixels)
    }

    func differsSignificantly(from previous: Self) -> Bool {
        guard width == previous.width, pixels.count == previous.pixels.count else { return true }

        var globalChanges = 0
        var documentChanges = 0
        var comparedPixels = 0
        for index in pixels.indices {
            let changed = abs(Int(pixels[index]) - Int(previous.pixels[index])) >= 24
            if changed { globalChanges += 1 }
            // Include newly occupied and cleared text regions when scrolling.
            if documentMask[index] || previous.documentMask[index] {
                comparedPixels += 1
                if changed { documentChanges += 1 }
            }
        }

        if Double(globalChanges) / Double(pixels.count) >= 0.30 { return true }
        // A cursor on an otherwise blank page must not become the entire comparison.
        guard Double(documentChanges) / Double(pixels.count) >= 0.002, comparedPixels > 0 else { return false }
        return Double(documentChanges) / Double(comparedPixels) >= 0.02
    }

    private static func makeDocumentMask(width: Int, pixels: [UInt8]) -> [Bool] {
        let height = pixels.count / width
        let tile = max(1, Int((Double(width) / 20).rounded()))
        var mask = [Bool](repeating: false, count: pixels.count)
        for top in stride(from: 0, to: height, by: tile) {
            for left in stride(from: 0, to: width, by: tile) {
                let bottom = min(top + tile, height)
                let right = min(left + tile, width)
                var histogram = [Int](repeating: 0, count: 16)
                for row in top..<bottom {
                    for column in left..<right {
                        histogram[Int(pixels[row * width + column]) / 16] += 1
                    }
                }
                let dominant = histogram.indices.max { histogram[$0] < histogram[$1] } ?? 0
                let background = dominant * 16 + 8
                var foreground = 0
                for row in top..<bottom {
                    for column in left..<right where abs(Int(pixels[row * width + column]) - background) >= 24 {
                        foreground += 1
                    }
                }
                // Text has a dominant background and sparse contrasting strokes.
                // Blank tiles and most photographic regions do not contribute.
                guard foreground > 0, Double(foreground) / Double((bottom - top) * (right - left)) <= 0.20 else { continue }
                for row in top..<bottom {
                    for column in left..<right { mask[row * width + column] = true }
                }
            }
        }
        return mask
    }
}
