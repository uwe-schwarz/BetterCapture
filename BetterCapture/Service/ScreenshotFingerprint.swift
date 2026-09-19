import CoreGraphics
import Foundation

/// A bounded grayscale comparison, based on meeting-transcribe's content masks.
/// Bright document regions use a lower threshold so small text edits count, while
/// camera tiles and cursor-sized changes usually do not.
nonisolated struct ScreenshotFingerprint: Sendable {
    let width: Int
    let pixels: [UInt8]
    private let isDocument: Bool
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
        isDocument = Double(pixels.filter { $0 >= 235 }.count) / Double(pixels.count) > 0.5
        documentMask = isDocument ? Self.makeDocumentMask(width: width, pixels: pixels) : []
    }

    func differsSignificantly(from previous: Self) -> Bool {
        guard width == previous.width, pixels.count == previous.pixels.count,
              isDocument == previous.isDocument else { return true }

        var globalChanges = 0
        var documentChanges = 0
        var comparedPixels = 0
        for index in pixels.indices {
            let changed = abs(Int(pixels[index]) - Int(previous.pixels[index])) >= 24
            if changed { globalChanges += 1 }
            if isDocument && documentMask[index] && previous.documentMask[index] {
                comparedPixels += 1
                if changed { documentChanges += 1 }
            }
        }

        if Double(globalChanges) / Double(pixels.count) >= 0.30 { return true }
        guard isDocument else { return false }
        return comparedPixels == 0 || Double(documentChanges) / Double(comparedPixels) >= 0.02
    }

    private static func makeDocumentMask(width: Int, pixels: [UInt8]) -> [Bool] {
        let height = pixels.count / width
        let tile = max(1, Int((Double(width) / 20).rounded()))
        var mask = [Bool](repeating: false, count: pixels.count)
        for top in stride(from: 0, to: height, by: tile) {
            for left in stride(from: 0, to: width, by: tile) {
                let bottom = min(top + tile, height)
                let right = min(left + tile, width)
                var bright = 0
                for row in top..<bottom {
                    for column in left..<right where pixels[row * width + column] >= 235 {
                        bright += 1
                    }
                }
                guard Double(bright) / Double((bottom - top) * (right - left)) >= 0.80 else { continue }
                for row in top..<bottom {
                    for column in left..<right { mask[row * width + column] = true }
                }
            }
        }
        return mask
    }
}
