nonisolated enum ScreenshotMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case interval = "Fixed Interval"
    case changes = "Only Changes"

    var id: String { rawValue }
}
