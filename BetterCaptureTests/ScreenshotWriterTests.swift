import AVFoundation
import ImageIO
import ScreenCaptureKit
import Testing
@testable import BetterCapture

@MainActor
struct ScreenshotWriterTests {
    @Test func fixedIntervalsSaveUnchangedScreensAndReadableImages() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = try ScreenshotWriter(directory: directory, mode: .interval, interval: 5, audioTracks: [])
        let frame = try makeFrame(brightness: 200)
        for time in [0.0, 1, 5, 5.2, 10] { try await writer.capture(frame, at: time) }
        #expect(try await writer.finish(duration: 12) == 3)
        let entries = try readEntries(directory)
        #expect(entries.map(\.timestamp) == [0, 5, 10])
        for entry in entries {
            let source = try #require(CGImageSourceCreateWithURL(directory.appending(path: entry.filename) as CFURL, nil))
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            #expect(image.width == 200)
            #expect(image.height == 100)
        }
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "audio.mov").path()))
    }

    @Test func changesUseLastSavedImageAndCaptureReturningSlides() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = try ScreenshotWriter(directory: directory, mode: .changes, interval: 5, audioTracks: [])
        let first = try makeFrame(brightness: 255)
        let second = try makeFrame(brightness: 20)
        try await writer.capture(first, at: 0)
        try await writer.capture(first, at: 5)
        try await writer.capture(second, at: 10)
        try await writer.capture(first, at: 15)
        #expect(try await writer.finish(duration: 16) == 3)
        #expect(try readEntries(directory).map(\.timestamp) == [0, 10, 15])
    }

    @Test func skippedComparisonsAccumulateAgainstSavedImage() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = try ScreenshotWriter(directory: directory, mode: .changes, interval: 1, audioTracks: [])
        // Each edit is below the pixel threshold relative to the preceding check.
        for (index, value) in [UInt8(40), 50, 60, 100].enumerated() {
            try await writer.capture(makeFrame(brightness: value), at: Double(index))
        }
        #expect(try await writer.finish(duration: 4) == 2)
        #expect(try readEntries(directory).map(\.timestamp) == [0, 3])
    }

    @Test func delayedChecksDoNotCreateCatchUpBursts() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = try ScreenshotWriter(directory: directory, mode: .interval, interval: 5, audioTracks: [])
        let frame = try makeFrame(brightness: 255)
        for time in [0.0, 62, 62.1, 65] { try await writer.capture(frame, at: time) }
        #expect(try await writer.finish(duration: 66) == 3)
        #expect(try readEntries(directory).map(\.timestamp) == [0, 62, 65])
    }

    @Test func retainedFrameIsSavedDuringIdleAndClearedWhenUnavailable() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "ScreenshotRecorderTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        settings.captureSystemAudio = false
        let recorder = try ScreenshotRecorder(directory: directory, settings: settings, anchor: .zero)
        let engine = CaptureEngine()
        let frame = try makeFrame(brightness: 255)
        recorder.captureEngine(engine, didOutputVideoSampleBuffer: try makeSample(frame, status: .complete))
        try await recorder.sample(at: .zero)
        recorder.captureEngine(engine, didOutputVideoSampleBuffer: try makeSample(frame, status: .idle))
        try await recorder.sample(at: CMTime(value: 5, timescale: 1))
        recorder.captureEngine(engine, didOutputVideoSampleBuffer: try makeSample(frame, status: .suspended))
        #expect(try await recorder.finishWriting(at: CMTime(value: 10, timescale: 1)) == 2)
        #expect(try readEntries(directory).map(\.timestamp) == [0, 5])
    }

    @Test func imageWriteFailurePreservesEarlierScreenshots() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = try ScreenshotWriter(directory: directory, mode: .interval, interval: 5, audioTracks: [])
        let frame = try makeFrame(brightness: 255)
        try await writer.capture(frame, at: 0)
        try FileManager.default.createDirectory(at: directory.appending(path: "screenshot-5000ms.png"), withIntermediateDirectories: false)
        await #expect(throws: (any Error).self) { try await writer.capture(frame, at: 5) }
        #expect(try await writer.finish(duration: 5) == 1)
        #expect(try readEntries(directory).count == 1)
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "screenshot-0ms.png").path()))
    }

    @Test func missingAudioReportsFailureButKeepsScreenshots() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "ScreenshotRecorderTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        settings.captureSystemAudio = true
        let recorder = try ScreenshotRecorder(directory: directory, settings: settings, anchor: .zero)
        recorder.captureEngine(CaptureEngine(), didOutputVideoSampleBuffer: try makeSample(makeFrame(brightness: 255), status: .complete))
        await #expect(throws: ScreenshotRecordingError.self) {
            _ = try await recorder.finishWriting(at: .zero)
        }
        #expect(try readEntries(directory).count == 1)
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "screenshot-0ms.png").path()))
    }

    @Test func stoppingWithoutScreenFramesDoesNotReportSuccess() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "ScreenshotRecorderTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        settings.captureSystemAudio = false
        let recorder = try ScreenshotRecorder(directory: directory, settings: settings, anchor: .zero)
        await #expect(throws: ScreenshotRecordingError.self) {
            _ = try await recorder.finishWriting(at: CMTime(value: 2, timescale: 1))
        }
        #expect(try readEntries(directory).isEmpty)
    }

    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "ScreenshotTests-\(UUID().uuidString)")
    }

    private func readEntries(_ directory: URL) throws -> [ScreenshotEntry] {
        let data = try Data(contentsOf: directory.appending(path: "screenshots.jsonl"))
        return try data.split(separator: 0x0A).map { try JSONDecoder().decode(ScreenshotEntry.self, from: Data($0)) }
    }

    private func makeFrame(brightness: UInt8) throws -> ScreenshotFrame {
        var buffer: CVPixelBuffer?
        #expect(CVPixelBufferCreate(kCFAllocatorDefault, 200, 100, kCVPixelFormatType_32BGRA, nil, &buffer) == kCVReturnSuccess)
        let pixelBuffer = try #require(buffer)
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        let base = try #require(CVPixelBufferGetBaseAddress(pixelBuffer))
        let stride = CVPixelBufferGetBytesPerRow(pixelBuffer)
        for row in 0..<100 {
            let bytes = base.advanced(by: row * stride).assumingMemoryBound(to: UInt8.self)
            for column in 0..<200 {
                for channel in 0..<3 { bytes[column * 4 + channel] = brightness }
                bytes[column * 4 + 3] = 255
            }
        }
        return ScreenshotFrame(pixelBuffer: pixelBuffer)
    }

    private func makeSample(_ frame: ScreenshotFrame, status: SCFrameStatus) throws -> CMSampleBuffer {
        var format: CMVideoFormatDescription?
        #expect(CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: frame.pixelBuffer,
                                                           formatDescriptionOut: &format) == noErr)
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 1), presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        let description = try #require(format)
        #expect(CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: frame.pixelBuffer,
                                                       formatDescription: description, sampleTiming: &timing, sampleBufferOut: &sample) == noErr)
        let result = try #require(sample)
        let attachments = try #require(CMSampleBufferGetSampleAttachmentsArray(result, createIfNecessary: true) as? [NSMutableDictionary])
        try #require(attachments.first)[SCStreamFrameInfo.status.rawValue] = status.rawValue
        return result
    }
}
