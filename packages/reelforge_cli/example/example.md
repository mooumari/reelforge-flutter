# Rendering from the command line

```bash
dart pub global activate reelforge_cli
```

## Adding it to an app

`init` writes the dependency, somewhere for compositions to live, and the two
entry points that serve them -- the preview you work in and the host the CLI
renders with. Nothing it writes overwrites anything, so running it twice is
safe:

```bash
cd my_app
reelforge init                  # a Dart composition
reelforge init --json           # a starter document and its data instead
```

On macOS a render host cannot be sandboxed, because it spawns ffmpeg and writes
outside the container. `init --fix-entitlements` turns App Sandbox off in the
release entitlements and touches nothing else. Put it back before shipping to
the Mac App Store.

## Previewing and rendering

```bash
reelforge preview
reelforge render --composition Reel --out reel.mp4
```

A JSON document renders directly, with the host entry point generated for you:

```bash
reelforge render reel.json --data report.json --out reel.mp4
```

Useful flags:

```
--shards <n|auto>     renderer processes to run
--size 1080x1920      override the composition's size
--fps 60              override the frame rate
--codec libx264       h264_videotoolbox by default
--no-build            reuse the existing release build
--show-window         let the render hosts appear on screen
```

Hosts render off-screen by default: no windows appear, because nothing is ever
drawn to a screen in the first place.

## Checking before you build

```bash
reelforge validate reel.json --data report.json
```

`validate` needs no project and no build -- a document is data, and checking it
is a question about JSON. Given `--data` it answers the second question too:
whether that data actually fills the document's bindings. A document and its
data can each be valid and still render nothing together, which is how you get
sixty seconds of empty scenes and an exit code of zero. `render` runs the same
check before the build and warns.

## Seeing what a project contains

```bash
reelforge list                  # compositions, ids and durations
reelforge inspect               # assets, audio and video clips, per frame range
```
