import SwiftUI

struct ScreenshotSettingsView: View {
    @Bindable var settings: MeetingCaptureSettings

    var body: some View {
        VStack(alignment: .leading) {
            Picker("Save", selection: $settings.screenshotMode) {
                ForEach(ScreenshotMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            HStack {
                Text(settings.screenshotMode == .changes ? "Check every" : "Save every")
                Spacer()
                TextField("Interval in seconds", value: $settings.screenshotInterval, format: .number.grouping(.never))
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                Text("seconds")
            }
            Text("1–3600 seconds. PNG images and enabled audio tracks are saved together in a recording folder.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if settings.screenshotMode == .changes {
                Text("Saves the first image, then significant changes from the last saved image. Select the shared content to reduce camera motion.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
