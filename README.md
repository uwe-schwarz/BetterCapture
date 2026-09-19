<p align="center">
  <img src="website/public/bettercapture-header.png" alt="BetterCapture Header">
</p>

<p align="center">
    The macOS screen recorder for the rest of us - always free and open source with a native look and feel 📺 
</p>

<p align="center">
  <a href="https://bettercapture.app">Website</a> ·
  <a href="#installation">Installation</a> ·
  <a href="#features">Features</a> ·
  <a href="#contributing">Contributing</a>
</p>

<p align="center">Sponsored by</p>

<p align="center">
  <a href="https://docs.recall.ai/docs/desktop-sdk?utm_source=github&utm_medium=sponsorship&utm_campaign=jsattler-BetterCapture">
    <img src="docs/assets/recallai-badge.png" alt="Recall.ai" width="160">
  </a>
</p>

<p align="center">If you're looking for a hosted desktop recording API, consider checking out <a href="https://docs.recall.ai/docs/desktop-sdk?utm_source=github&utm_medium=sponsorship&utm_campaign=jsattler-BetterCapture">Recall.ai</a>,<br>an API that records Zoom, Google Meet, Microsoft Teams, in-person meetings, and more.</p>

## Features

- **Native macOS integration**: Built with SwiftUI and ScreenCaptureKit, lives in your menu bar
- **Professional encoding**: ProRes 422/4444, HEVC (H.265), and H.264 codecs with support for alpha channel and HDR
- **Flexible audio capture**: Record system audio and microphone simultaneously
- **Meeting recording**: Record video at 1 fps, or save screenshots at fixed intervals or only when content changes, with optional continuous audio
- **Content filtering**: Exclude specific content from recordings
- **Privacy-focused**: No tracking, no analytics, all recordings stored locally
- **MIT licensed**: Free and open source

## Installation

### Homebrew

```bash
brew install bettercapture
```

### Direct Download

Download the latest release from [GitHub Releases](https://github.com/jsattler/BetterCapture/releases/latest) and open `BetterCapture.dmg`.

**Requirements**: macOS 15.2 (Sequoia) or later

## Meeting Recording

In the menu bar, keep **Output → Video** and select **Frame Rate → 1 fps** for
meetings with mostly static content. Audio stays at its normal sample rate. The
video repeats the last image during static periods and extends through the end of
the recording, rounded up to a whole second.

Select **Output → Screenshots** to save PNG images instead of a video track:

- **Fixed Interval** saves the first available image, then an image every 1–3600
  seconds (5 seconds by default), including unchanged screens.
- **Only Changes** checks at the same configurable interval and saves significant
  changes relative to the last saved image. Returning to an earlier slide is saved
  again. Select the shared window or slide area to reduce unrelated camera motion.

Each session creates a unique folder in the selected output location containing
PNG images, `screenshots.jsonl` (one filename and timestamp in seconds per line),
and `recording.json` (duration and settings). If enabled, system audio and microphone
are saved as separate tracks in `audio.mov`, using the selected audio codec.
Image timestamps and audio share the same recording origin. With both audio
sources disabled, the folder contains only images and metadata.

Screenshots use SDR and honor the selected content, resolution, and content
filters. Video codec, HDR, and alpha settings apply to video recordings. No image
is saved while the capture source reports itself unavailable. Checks delayed by
sleep or slow storage skip missed intervals instead of creating a burst of images.

The change detector compares grayscale images at up to 640 pixels wide and ignores
brightness differences below 24/255. It identifies text against locally uniform
backgrounds in light and dark themes, including a browser shared inside a meeting
window. A 2% change within those content regions saves an image, provided at least
0.2% of the whole image changes; that minimum filters cursor-sized changes. Large
scene changes affecting at least 30% of the image are also saved. These are visual
heuristics; camera motion can still trigger captures, and tiny edits, brief
transitions between checks, or color changes with similar brightness may be missed.

## Automation

BetterCapture supports a custom URL scheme for external tools (Raycast, Shortcuts, Alfred):

| URL | Action |
|---|---|
| `bettercapture://toggle` | Stop recording if active; otherwise open content selection (Pick Content or Select Area) before recording |
| `bettercapture://toggle-copy` | Same as `toggle`, but copies the saved recording to the clipboard when stopping |
| `bettercapture://open-recordings` | Open the output folder in Finder |

Example:

```bash
open "bettercapture://toggle"
```

## Contributing

We welcome contributions of all kinds! Please see our [Contributing Guidelines](CONTRIBUTING.md) for more details on how to get involved.

**Note**: Any issues or pull requests for feature requests submitted without prior discussion will be closed immediately.

## Acknowledgments

Special thanks to these projects for their excellent work and inspiration:

- [**QuickRecorder**](https://github.com/lihaoyun6/QuickRecorder)
- [**Azayaka**](https://github.com/Mnpn/Azayaka)
- [**Ghostty**](https://github.com/ghostty-org/ghostty)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
