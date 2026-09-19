import AVFoundation
import Foundation
import ScreenCaptureKit
import os

/// Keeps one recent screen surface and routes audio directly to its own writer.
/// Lifecycle operations run on the main actor; capture callbacks only touch the lock.
@MainActor
final class ScreenshotRecorder: CaptureEngineSampleBufferDelegate {
    let directory: URL
    private let writer: ScreenshotWriter
    nonisolated private let audioWriter: AssetWriter?
    nonisolated private let latestFrame = OSAllocatedUnfairLock<ScreenshotFrame?>(initialState: nil)
    private let anchor: CMTime
    private var samplingTask: Task<Void, Never>?
    private var samplingError: Error?

    init(directory: URL, settings: SettingsStore, anchor: CMTime = CMClockGetTime(CMClockGetHostTimeClock())) throws {
        self.directory = directory
        self.anchor = anchor
        let tracks = [(settings.captureSystemAudio, "system"), (settings.captureMicrophone, "microphone")]
            .filter { $0.0 }.map { $0.1 }
        try FileManager.default.createDirectory(at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
        writer = try ScreenshotWriter(
            directory: directory, mode: settings.meetingCapture.screenshotMode,
            interval: settings.meetingCapture.screenshotInterval, audioTracks: tracks
        )
        if tracks.isEmpty {
            audioWriter = nil
        } else {
            let audio = AssetWriter()
            do {
                try audio.setup(url: directory.appending(path: "audio.mov"), settings: settings, videoSize: .zero, includeVideo: false)
                try audio.startWriting(at: anchor)
            } catch {
                audio.cancel()
                try? FileManager.default.removeItem(at: directory)
                throw error
            }
            audioWriter = audio
        }
    }

    func startSampling(onFailure: @escaping @MainActor (Error) -> Void) {
        samplingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    try await self.sample(at: CMClockGetTime(CMClockGetHostTimeClock()))
                } catch {
                    self.samplingError = error
                    onFailure(error)
                    return
                }
                do {
                    try await Task.sleep(for: .milliseconds(100))
                } catch {
                    return
                }
            }
        }
    }

    /// Reads the retained frame even when ScreenCaptureKit emits no new surface.
    func sample(at time: CMTime) async throws {
        guard let frame = latestFrame.withLock({ $0 }) else { return }
        try await writer.capture(frame, at: max(0, (time - anchor).seconds))
    }

    func finishWriting(at time: CMTime = CMClockGetTime(CMClockGetHostTimeClock())) async throws -> Int {
        await stopSampling()
        var failure = samplingError
        do {
            // Also covers a recording stopped before the first polling tick.
            if failure == nil { try await sample(at: time) }
        } catch { failure = error }
        if let audioWriter {
            do {
                _ = try await audioWriter.finishWriting()
            } catch AssetWriterError.noFramesWritten {
                failure = failure ?? ScreenshotRecordingError.noAudio
            } catch {
                failure = failure ?? error
            }
        }
        var count = 0
        do {
            count = try await writer.finish(duration: max(0, (time - anchor).seconds))
        } catch { failure = failure ?? error }
        latestFrame.withLock { $0 = nil }
        if let failure {
            throw ScreenshotRecordingError.incomplete(directory, failure.localizedDescription)
        }
        guard count > 0 else { throw ScreenshotRecordingError.incomplete(directory, ScreenshotRecordingError.noScreenshots.localizedDescription) }
        return count
    }

    /// Only used for a failed start, before a recording has been established.
    func cancel() async {
        await stopSampling()
        audioWriter?.cancel()
        _ = try? await writer.finish(duration: 0)
        latestFrame.withLock { $0 = nil }
        try? FileManager.default.removeItem(at: directory)
    }

    private func stopSampling() async {
        samplingTask?.cancel()
        await samplingTask?.value
        samplingTask = nil
    }

    nonisolated func captureEngine(_ engine: CaptureEngine, didOutputVideoSampleBuffer sampleBuffer: CMSampleBuffer) {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[String: Any]],
              let value = attachments.first?[SCStreamFrameInfo.status.rawValue] as? Int,
              let status = SCFrameStatus(rawValue: value) else { return }
        if status == .complete, let pixelBuffer = sampleBuffer.imageBuffer {
            let frame = ScreenshotFrame(pixelBuffer: pixelBuffer)
            latestFrame.withLock { $0 = frame }
        } else if status != .idle {
            // Do not keep saving stale content after the source becomes unavailable.
            latestFrame.withLock { $0 = nil }
        }
    }

    nonisolated func captureEngine(_ engine: CaptureEngine, didOutputAudioSampleBuffer sampleBuffer: CMSampleBuffer) {
        audioWriter?.appendAudioSample(sampleBuffer)
    }

    nonisolated func captureEngine(_ engine: CaptureEngine, didOutputMicrophoneSampleBuffer sampleBuffer: CMSampleBuffer) {
        audioWriter?.appendMicrophoneSample(sampleBuffer)
    }
}
