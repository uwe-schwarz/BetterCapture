import Foundation
import Testing
@testable import BetterCapture

@MainActor
struct MeetingCaptureSettingsTests {
    @Test func preferencesPersistWithoutChangingVideoSettings() throws {
        let suite = "BetterCaptureMeetingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.meetingCapture.recordingMode == .video)
        #expect(settings.meetingCapture.screenshotInterval == 5)
        settings.frameRate = .fps1
        settings.captureHDR = true
        settings.meetingCapture.recordingMode = .screenshots
        settings.meetingCapture.screenshotMode = .changes
        settings.meetingCapture.screenshotInterval = 12
        #expect(settings.hdrPreset == .sdr)
        let restored = SettingsStore(defaults: defaults)
        #expect(restored.frameRate == .fps1)
        #expect(restored.meetingCapture.recordingMode == .screenshots)
        #expect(restored.meetingCapture.screenshotMode == .changes)
        #expect(restored.meetingCapture.screenshotInterval == 12)
        restored.meetingCapture.recordingMode = .video
        #expect(restored.captureHDR)
        #expect(restored.hdrPreset != .sdr)
    }

    @Test func invalidPreferencesFallBackAndIntervalsAreBounded() throws {
        let suite = "BetterCaptureMeetingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("unknown", forKey: "recordingMode")
        defaults.set("unknown", forKey: "screenshotMode")
        defaults.set(-20, forKey: "screenshotInterval")
        let settings = MeetingCaptureSettings(defaults: defaults)
        #expect(settings.recordingMode == .video)
        #expect(settings.screenshotMode == .interval)
        #expect(settings.screenshotInterval == 1)
        settings.screenshotInterval = 9000
        #expect(settings.screenshotInterval == 3600)
        settings.screenshotInterval = 0
        #expect(settings.screenshotInterval == 1)
    }

    @Test func screenshotSessionsHaveDistinctFolders() throws {
        let suite = "BetterCaptureMeetingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        settings.meetingCapture.recordingMode = .screenshots
        let first = settings.generateOutputURL()
        #expect(first != settings.generateOutputURL())
        #expect(first.lastPathComponent.hasSuffix("-screenshots"))
    }
}
