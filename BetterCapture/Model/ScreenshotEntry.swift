nonisolated struct ScreenshotEntry: Codable, Sendable {
    let filename: String
    /// Seconds from the common origin of the screenshots and audio tracks.
    let timestamp: Double
}
