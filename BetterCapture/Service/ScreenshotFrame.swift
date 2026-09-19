import CoreVideo

/// Retains one immutable ScreenCaptureKit surface while the screenshot actor reads it.
nonisolated struct ScreenshotFrame: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
}
