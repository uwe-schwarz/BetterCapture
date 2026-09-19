import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Encodes on its own executor; slow disk writes never block the audio callbacks.
actor ScreenshotWriter {
    let directory: URL
    private let mode: ScreenshotMode
    private let interval: Double
    private let audioTracks: [String]
    private let startedAt = Date()
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let journal: FileHandle
    private var previous: ScreenshotFingerprint?
    private var nextCaptureTime = 0.0
    private(set) var count = 0

    init(directory: URL, mode: ScreenshotMode, interval: Int, audioTracks: [String]) throws {
        self.directory = directory
        self.mode = mode
        self.interval = Double(interval)
        self.audioTracks = audioTracks
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let journalURL = directory.appending(path: "screenshots.jsonl")
        try Data().write(to: journalURL, options: .withoutOverwriting)
        journal = try FileHandle(forWritingTo: journalURL)
    }

    /// Saves on an absolute interval grid. A delayed check skips missed intervals
    /// instead of producing a burst of identical screenshots after sleep or slow I/O.
    func capture(_ frame: ScreenshotFrame, at elapsed: Double) throws {
        guard elapsed.isFinite, elapsed >= nextCaptureTime else { return }
        nextCaptureTime = (floor(elapsed / interval) + 1) * interval

        let source = CIImage(cvPixelBuffer: frame.pixelBuffer)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let image = context.createCGImage(source, from: source.extent, format: .RGBA8, colorSpace: colorSpace)
        else { throw ScreenshotRecordingError.imageEncodingFailed }

        let fingerprint = mode == .changes ? try ScreenshotFingerprint(image: image) : nil
        if let fingerprint, let previous, !fingerprint.differsSignificantly(from: previous) { return }

        let milliseconds = Int((elapsed * 1000).rounded())
        let filename = "screenshot-\(milliseconds)ms.png"
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { throw ScreenshotRecordingError.imageEncodingFailed }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ScreenshotRecordingError.imageEncodingFailed }
        try (data as Data).write(to: directory.appending(path: filename), options: .atomic)

        // Append immediately, so a crash still leaves timestamps for completed images.
        let entry = ScreenshotEntry(filename: filename, timestamp: elapsed)
        var line = try JSONEncoder().encode(entry)
        line.append(0x0A)
        try journal.write(contentsOf: line)
        previous = fingerprint
        count += 1
    }

    func finish(duration: Double) throws -> Int {
        try journal.close()
        let metadata: [String: Any] = [
            "version": 1,
            "startedAt": startedAt.ISO8601Format(),
            "duration": duration,
            "mode": mode.rawValue,
            "intervalSeconds": interval,
            "screenshotCount": count,
            "audioFile": audioTracks.isEmpty ? NSNull() : "audio.mov",
            "audioTracks": audioTracks,
            "timestampOrigin": "recording-start",
            "changeDetection": "last-saved-percentage-content-mask-v1"
        ]
        let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: directory.appending(path: "recording.json"), options: .atomic)
        return count
    }
}
