import Foundation

@MainActor
@Observable
final class MeetingCaptureSettings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var recordingMode: RecordingMode {
        get {
            access(keyPath: \.recordingMode)
            return defaults.string(forKey: "recordingMode").flatMap(RecordingMode.init) ?? .video
        }
        set {
            withMutation(keyPath: \.recordingMode) {
                defaults.set(newValue.rawValue, forKey: "recordingMode")
            }
        }
    }

    var screenshotMode: ScreenshotMode {
        get {
            access(keyPath: \.screenshotMode)
            return defaults.string(forKey: "screenshotMode").flatMap(ScreenshotMode.init) ?? .interval
        }
        set {
            withMutation(keyPath: \.screenshotMode) {
                defaults.set(newValue.rawValue, forKey: "screenshotMode")
            }
        }
    }

    /// The saving interval, or the comparison interval when only changes are saved.
    var screenshotInterval: Int {
        get {
            access(keyPath: \.screenshotInterval)
            let value = defaults.object(forKey: "screenshotInterval") as? Int ?? 5
            return min(3600, max(1, value))
        }
        set {
            withMutation(keyPath: \.screenshotInterval) {
                defaults.set(min(3600, max(1, newValue)), forKey: "screenshotInterval")
            }
        }
    }
}
