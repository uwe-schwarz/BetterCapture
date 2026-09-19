import AVFoundation
import Testing
@testable import BetterCapture

// MARK: - Meeting recordings

extension AssetWriterTests {
    @Test func oneFPSRetainsNewContentAfterTheClockFilledItsSlot() async throws {
        let settings = makeStore()
        settings.frameRate = .fps1
        let writer = AssetWriter()
        try writer.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try writer.startWriting()
        writer.appendVideoSample(try makeVideoSampleBuffer(at: .zero))
        writer.advanceVideo(to: CMTime(value: 1, timescale: 1))
        writer.appendVideoSample(try makeVideoSampleBuffer(at: CMTime(value: 1500, timescale: 1000), brightness: 255))
        writer.appendVideoSample(try makeVideoSampleBuffer(at: CMTime(value: 1200, timescale: 1000)))
        writer.advanceVideo(to: CMTime(value: 2, timescale: 1))
        let result = try await writer.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: result.url))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = try await generator.image(at: CMTime(value: 2, timescale: 1)).image
        let fingerprint = try ScreenshotFingerprint(image: image)
        #expect(fingerprint.pixels.allSatisfy { $0 > 220 })
    }

    @Test(arguments: [VideoCodec.h264, .hevc, .proRes422, .proRes4444])
    func oneFPSKeepsLongStaticScreensAndAudio(codec: VideoCodec) async throws {
        let settings = makeStore()
        settings.frameRate = .fps1
        settings.videoCodec = codec
        settings.captureSystemAudio = true
        settings.audioCodec = .pcm
        let writer = AssetWriter()
        try writer.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try writer.startWriting()
        writer.appendVideoSample(try makeVideoSampleBuffer(at: .zero))

        // No new screen surfaces for 25 seconds, including a silent audio tail.
        writer.appendAudioSample(try makeSilentAudioSampleBuffer(at: CMTime(value: 25, timescale: 1)))
        writer.advanceVideo(to: CMTime(value: 25_500, timescale: 1000))
        let result = try await writer.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }
        let times = try await videoPresentationTimes(of: result.url)
        #expect(times == (0..<26).map { CMTime(value: CMTimeValue($0), timescale: 1) })
        let asset = AVURLAsset(url: result.url)
        let track = try #require(await asset.loadTracks(withMediaType: .video).first)
        #expect(try await track.load(.nominalFrameRate) == 1)
        #expect(try await asset.load(.duration).seconds == 26)
        let audio = try #require(await asset.loadTracks(withMediaType: .audio).first)
        #expect(try await audio.load(.timeRange).end.seconds > 25)
    }

    @Test(arguments: [BetterCapture.AudioCodec.aac, .pcm])
    func explicitAudioOnlyOutputUsesTheScreenshotTimeline(codec: BetterCapture.AudioCodec) async throws {
        let settings = makeStore()
        settings.captureSystemAudio = true
        settings.captureMicrophone = true
        settings.audioCodec = codec
        let writer = AssetWriter()
        try writer.setup(url: makeOutputURL(), settings: settings, videoSize: .zero, includeVideo: false)
        try writer.startWriting(at: CMTime(value: 100, timescale: 1))
        writer.appendAudioSample(try makeSilentAudioSampleBuffer(at: CMTime(value: 101, timescale: 1)))
        writer.appendMicrophoneSample(try makeSilentAudioSampleBuffer(at: CMTime(value: 102, timescale: 1)))
        let result = try await writer.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }
        let asset = AVURLAsset(url: result.url)
        #expect(try await asset.loadTracks(withMediaType: .video).isEmpty)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        #expect(tracks.count == 2)
        for track in tracks {
            #expect(try await track.load(.timeRange).start == .zero)
        }
        #expect(try await asset.load(.duration).seconds > 2)
    }
}
