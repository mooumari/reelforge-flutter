## 0.1.1

* Adds `example/`, so the package page has an Example tab.

## 0.1.0

First release.

* Compositions as pure functions of frame number, with `Video.frame()` and
  `Sequence` for time, and `interpolate`/`spring`/easings for motion.
* Deterministic renderer: the same frame is byte-identical whether reached by
  playing forward, scrubbing backward, or rendering in a fresh process.
* Declaration pass: images preloaded, sounds scheduled, and video decode
  windows found before a single frame is rendered.
* `VideoClip` decodes into the widget tree, so footage can be masked, rounded
  and drawn under Flutter content -- and lands on the same source frame no
  matter how many processes the render was split across.
* `Audio` clips, mixed into the exported file.
* Render hosts stay off screen on macOS -- no window, no Dock icon, no
  stolen focus -- because nothing a host draws is ever presented to its
  window. `--show-window` opts out.
* Scrubber preview with hot reload.
* `VideoEncoder` and `VideoBackend` seams, so the platform-specific steps can
  be swapped for in-app implementations.
