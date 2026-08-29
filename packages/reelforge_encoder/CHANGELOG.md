## 0.2.0

Requires Flutter 3.41 or newer, with `reelforge` 0.2.0.

* No code change. Noted in the README that the plugin has no `Package.swift`
  yet: Flutter 3.47 warns that the CocoaPods fallback will be removed.

## 0.1.0

First release.

* `NativeVideoEncoder` -- H.264 through AVAssetWriter, with the declared sounds
  mixed in, so an app can export video with no ffmpeg present.
* `NativeVideoBackend` -- video decoding through AVAssetReader, verified to land
  on the same source frames as the ffmpeg decoder.
* iOS and macOS. Android is not implemented yet.
