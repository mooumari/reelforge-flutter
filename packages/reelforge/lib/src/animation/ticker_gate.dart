import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Mutes every [Ticker] inside a composition between the frames the renderer
/// draws.
///
/// The composition's tickers register with the *global* [SchedulerBinding] --
/// the same one the host application's frame loop drives. In a headless render
/// host that is invisible, because nothing else ever asks for a frame. In a
/// live app it is not: the preview and the on-device exporter both run while
/// the engine is still delivering vsync, and each of those real frames ticks
/// the composition's tickers at wall-clock time.
///
/// That is worse than it sounds. A [Ticker] anchors its zero on its *first*
/// tick, so a single stray real frame is enough to anchor an animation at a
/// timestamp the composition clock will never reach -- which surfaces as
/// `elapsedInSeconds >= 0.0` failing inside [AnimationController], or, in
/// release, as an animation frozen at the wrong value.
///
/// [TickerMode] is the one seam the ticker mixins do honour: they watch its
/// notifier and mute their ticker when it goes false. So the composition is
/// wrapped in a [TickerMode] that is left permanently enabled, and its
/// notifier is written directly. Writing the notifier rather than rebuilding
/// the widget is deliberate -- the gate has to close after the frame is
/// painted and before control returns to the engine, and there is no build
/// scope to spend there. Flutter reads that notifier with
/// `getInheritedWidgetOfExactType`, which creates no dependency, so nothing
/// rebuilds either way.
class TickerGate {
  ValueNotifier<bool>? _notifier;

  /// Wraps [child] so the gate can reach the tickers below it.
  Widget wrap(Widget child) {
    return TickerMode(
      enabled: true,
      child: Builder(
        builder: (BuildContext context) {
          _notifier = writableNotifierOf(context);
          return child;
        },
      ),
    );
  }

  /// Lets the composition's tickers run, for exactly as long as the renderer
  /// is the one deciding what time it is.
  void open() => _notifier?.value = true;

  /// Mutes them again, so the engine's next real frame passes them by.
  void close() => _notifier?.value = false;
}

/// Reaches the [ValueNotifier] behind the nearest [TickerMode].
///
/// Flutter hands out a read-only view of a notifier it owns. If that ever
/// stops being true, the caller gets null and does nothing at all rather than
/// doing something wrong. Reading it creates no dependency, so this is safe to
/// call on contexts the caller does not own.
ValueNotifier<bool>? writableNotifierOf(BuildContext context) {
  final ValueListenable<bool> notifier = TickerMode.getNotifier(context);
  assert(
    notifier is ValueNotifier<bool>,
    'TickerMode no longer exposes a writable notifier; muting tickers needs '
    'another route.',
  );
  return notifier is ValueNotifier<bool> ? notifier : null;
}

/// Shields a live application from the composition clock.
///
/// [TickerGate] closes one half of the problem: the host's frames must not
/// tick the composition. This is the other half, and it bites harder. While a
/// frame is being rendered the renderer tells [SchedulerBinding] that the time
/// is the *composition's* time -- a few seconds at most, counted from the
/// composition's own zero. The host application has usually been open far
/// longer than that, so every one of its own animations would be handed a
/// timestamp from before it started, and an [AnimationController] asserts on
/// exactly that (`elapsedInSeconds >= 0.0`). One button ripple in flight is
/// enough to bring the app down.
///
/// Wrapping the application in this widget mutes its tickers for the instant
/// the renderer is driving the clock, and lets them go again immediately
/// afterwards. They never see composition time at all; they simply miss the
/// frames the renderer manufactures, which are not frames of the application.
///
/// The preview installs one of these for you. An app that exports on device
/// should wrap its own root:
///
/// ```dart
/// runApp(const MotionTickerShield(child: MyApp()));
/// ```
class MotionTickerShield extends StatefulWidget {
  const MotionTickerShield({super.key, required this.child});

  final Widget child;

  static final Set<_MotionTickerShieldState> _installed =
      <_MotionTickerShieldState>{};

  static final Map<ValueNotifier<bool>, bool> _restore =
      <ValueNotifier<bool>, bool>{};

  @visibleForTesting
  static int get debugInstalledCount => _installed.length;

  /// Mutes every shielded application tree. Balanced by [unmuteHosts].
  static void muteHosts() {
    for (final _MotionTickerShieldState state in _installed) {
      for (final ValueNotifier<bool> notifier in state._notifiers()) {
        // Whatever the app had asked for is restored afterwards, so a tree it
        // had already disabled -- an offstage route, say -- stays disabled.
        _restore[notifier] = notifier.value;
        notifier.value = false;
      }
    }
  }

  /// Lets them run again, exactly as they were.
  static void unmuteHosts() {
    _restore.forEach((ValueNotifier<bool> notifier, bool was) {
      notifier.value = was;
    });
    _restore.clear();
  }

  @override
  State<MotionTickerShield> createState() => _MotionTickerShieldState();
}

class _MotionTickerShieldState extends State<MotionTickerShield> {
  @override
  void initState() {
    super.initState();
    MotionTickerShield._installed.add(this);
  }

  @override
  void dispose() {
    MotionTickerShield._installed.remove(this);
    super.dispose();
  }

  /// Every [TickerMode] notifier in the shielded subtree, this one included.
  ///
  /// The obvious implementation -- hold one notifier and flip it -- does not
  /// work, because [TickerMode] nests. A [ModalRoute] wraps its contents in a
  /// [TickerMode] of its own, and the ticker mixins only ever watch the
  /// *nearest* one, so a route's animations never hear about a flip further
  /// up. Propagating properly would mean rebuilding the host tree, which is
  /// exactly what there is no time to do between two frames. So the tree is
  /// walked instead and every notifier is flipped directly.
  ///
  /// The walk is redone on each frame rather than cached: routes come and go,
  /// and a stale list would silently stop shielding whatever appeared since.
  List<ValueNotifier<bool>> _notifiers() {
    final List<ValueNotifier<bool>> found = <ValueNotifier<bool>>[];
    void visit(Element element) {
      if (element.widget is TickerMode) {
        // The notifier lives on the inherited widget TickerMode builds, so it
        // is only visible from below.
        Element? child;
        element.visitChildren((Element e) => child ??= e);
        final ValueNotifier<bool>? notifier = child == null
            ? null
            : writableNotifierOf(child!);
        if (notifier != null) found.add(notifier);
      }
      element.visitChildren(visit);
    }

    if (mounted) visit(context as Element);
    return found;
  }

  @override
  Widget build(BuildContext context) {
    return TickerMode(enabled: true, child: widget.child);
  }
}
