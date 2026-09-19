import Foundation

nonisolated enum ScreenshotRecordingError: LocalizedError {
    case imageEncodingFailed
    case noScreenshots
    case noAudio
    case incomplete(URL, String)

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "Could not encode the screenshot."
        case .noScreenshots:
            return "No screenshots were captured. Check the selected content and screen recording permissions."
        case .noAudio:
            return "The enabled audio sources did not deliver any samples."
        case .incomplete(let directory, let reason):
            return "\(reason) Any completed screenshots and audio are kept in \(directory.path())."
        }
    }
}
