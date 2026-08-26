## 0.1.0

First release.

* `NativeVideoEncoder` -- H.264 through AVAssetWriter, with the declared sounds
  mixed in, so an app can export video with no ffmpeg present.
* `NativeVideoBackend` -- video decoding through AVAssetReader, verified to land
  on the same source frames as the ffmpeg decoder.
* iOS and macOS. Android is not implemented yet.
