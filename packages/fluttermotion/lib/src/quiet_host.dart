import 'dart:ffi';
import 'dart:io';

/// Keeps a render host off the screen.
///
/// ## Why there is a window to hide at all
///
/// A composition is Flutter code, so rendering it needs a Flutter engine, and
/// on macOS the way to get one is to build the user's own app -- which is the
/// point, because that is what brings their assets, fonts and plugins along.
/// The cost is a stock `Runner`: `MainMenu.xib` makes a visible `NSWindow`,
/// the app takes a Dock icon, and it steals focus. Render with `--shards 4`
/// and four of them appear.
///
/// That window is pure ceremony. [CompositionRenderer] owns its own
/// `BuildOwner` and `PipelineOwner`, flushes them by hand and rasterises
/// through `toImage`; not one pixel is ever presented to the window. The
/// engine's view is used once, as the handle `RenderView` is built against,
/// and never as a target.
///
/// So a video that looks like it was screen-recorded is exactly the wrong
/// first impression of a tool whose whole claim is that it wasn't.
///
/// ## Why this is FFI rather than a plugin or a build setting
///
/// `LSBackgroundOnly` in the bundle's `Info.plist` does the same job, but the
/// only place to set it is the user's shared `Runner` target, which their
/// real app uses too. Patching the built bundle instead means mutating a
/// signed app: it works for a locally built ad-hoc signature and destroys a
/// Developer ID one, entitlements included.
///
/// A plugin would need `fluttermotion` to gain a native side purely for this,
/// and would not reach a host that was already built. Three Objective-C
/// messages at startup reach every host, including one `--no-build` reuses.
///
/// ## What it does
///
///     [[NSApplication sharedApplication] setActivationPolicy:
///         NSApplicationActivationPolicyProhibited];
///
/// One message, because a prohibited application "may not create windows or
/// be activated" -- the nib's window is never shown in the first place, so
/// there is nothing left to hide.
///
/// Hiding it explicitly as well, with `orderOut:` over `NSApp.windows`, is
/// what the first version did and it ended the render: the host printed its
/// startup line, produced no frames, and exited 0, because closing out the
/// last window terminates a Flutter macOS app and a terminated app raster-
/// ises nothing. `--list` still worked, which is exactly how a bug like this
/// stays hidden -- it exits before the app has time to notice.
///
/// Returns whether the host was quietened, and never throws: a window is a
/// blemish, and a blemish must not be the thing that fails a render.
bool quietHost() {
  if (!Platform.isMacOS) return false;
  try {
    return _quiet();
  } catch (_) {
    return false;
  }
}

/// `NSApplicationActivationPolicyProhibited`.
const int _prohibited = 2;

bool _quiet() {
  final DynamicLibrary process = DynamicLibrary.process();

  final _GetClass getClass =
      process.lookupFunction<_GetClassC, _GetClass>('objc_getClass');
  final _Selector selector =
      process.lookupFunction<_SelectorC, _Selector>('sel_registerName');

  // `objc_msgSend` is one symbol with one signature per call site. Casting it
  // per message is how every Objective-C bridge works, including
  // `package:objective_c`; on arm64 the named arguments here go in registers
  // exactly as a direct call would put them.
  final Pointer<Void> send = process.lookup<Void>('objc_msgSend');
  final _SendId sendId = send.cast<NativeFunction<_SendIdC>>().asFunction();
  final _SendPolicy sendPolicy =
      send.cast<NativeFunction<_SendPolicyC>>().asFunction();

  final Pointer<Void> nsApplication = _withCString('NSApplication', getClass);
  // AppKit is not linked into every process that can run this code -- the
  // Flutter test harness is one. An absent class is a reason to do nothing,
  // not to fail.
  if (nsApplication == nullptr) return false;

  final Pointer<Void> app =
      sendId(nsApplication, _withCString('sharedApplication', selector));
  if (app == nullptr) return false;

  return sendPolicy(
    app,
    _withCString('setActivationPolicy:', selector),
    _prohibited,
  );
}

/// Runs [use] against a C string of [value], and frees it afterwards.
///
/// `malloc` is looked up in the process rather than taken from `package:ffi`
/// so that the framework keeps its empty dependency list for the sake of
/// three strings on one platform. libc is in every process that has an
/// Objective-C runtime to talk to.
Pointer<Void> _withCString(
  String value,
  Pointer<Void> Function(Pointer<Uint8>) use,
) {
  final DynamicLibrary process = DynamicLibrary.process();
  final _Malloc malloc = process.lookupFunction<_MallocC, _Malloc>('malloc');
  final _Free free = process.lookupFunction<_FreeC, _Free>('free');

  final List<int> bytes = value.codeUnits;
  final Pointer<Uint8> buffer = malloc(bytes.length + 1);
  if (buffer == nullptr) throw StateError('Out of memory for "$value".');
  try {
    for (int i = 0; i < bytes.length; i++) {
      buffer[i] = bytes[i];
    }
    buffer[bytes.length] = 0;
    return use(buffer);
  } finally {
    free(buffer);
  }
}

typedef _GetClassC = Pointer<Void> Function(Pointer<Uint8>);
typedef _GetClass = Pointer<Void> Function(Pointer<Uint8>);

typedef _SelectorC = Pointer<Void> Function(Pointer<Uint8>);
typedef _Selector = Pointer<Void> Function(Pointer<Uint8>);

typedef _MallocC = Pointer<Uint8> Function(IntPtr);
typedef _Malloc = Pointer<Uint8> Function(int);

typedef _FreeC = Void Function(Pointer<Uint8>);
typedef _Free = void Function(Pointer<Uint8>);

/// `id (*)(id, SEL)`
typedef _SendIdC = Pointer<Void> Function(Pointer<Void>, Pointer<Void>);
typedef _SendId = Pointer<Void> Function(Pointer<Void>, Pointer<Void>);

/// `BOOL (*)(id, SEL, NSInteger)`
typedef _SendPolicyC = Bool Function(Pointer<Void>, Pointer<Void>, IntPtr);
typedef _SendPolicy = bool Function(Pointer<Void>, Pointer<Void>, int);
