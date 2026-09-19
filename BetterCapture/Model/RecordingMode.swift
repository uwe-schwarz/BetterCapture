enum RecordingMode: String, CaseIterable, Identifiable {
    case video = "Video"
    case screenshots = "Screenshots"

    var id: String { rawValue }
}
