import 'dart:async';
import 'dart:typed_data';

/// Reads fixed-size frames out of a byte stream, with backpressure.
///
/// A raw 1080p frame is 8 MB, so letting ffmpeg run ahead unbounded would cost
/// hundreds of megabytes on a long clip. The subscription is paused once a few
/// frames are buffered and resumed as they are consumed.
class FrameReader {
  FrameReader(Stream<List<int>> stream, {required this.maxBufferedBytes}) {
    _subscription = stream.listen(
      _onData,
      onDone: _onDone,
      onError: _onError,
      cancelOnError: true,
    );
  }

  final int maxBufferedBytes;

  late final StreamSubscription<List<int>> _subscription;
  final List<Uint8List> _chunks = <Uint8List>[];
  int _buffered = 0;
  bool _paused = false;
  bool _done = false;
  Object? _error;

  int _want = 0;
  Completer<Uint8List?>? _pending;

  /// Completes with exactly [n] bytes, or null if the stream ended first.
  Future<Uint8List?> read(int n) {
    assert(_pending == null, 'Concurrent reads from one decoder.');
    if (_error != null) return Future<Uint8List?>.error(_error!);

    if (_buffered >= n) {
      final Uint8List frame = _take(n);
      _maybeResume();
      return Future<Uint8List?>.value(frame);
    }
    if (_done) return Future<Uint8List?>.value(null);

    _maybeResume();
    _want = n;
    final Completer<Uint8List?> completer = Completer<Uint8List?>();
    _pending = completer;
    return completer.future;
  }

  void _onData(List<int> data) {
    _chunks.add(data is Uint8List ? data : Uint8List.fromList(data));
    _buffered += data.length;
    _settle();
    if (!_paused && _buffered >= maxBufferedBytes && _pending == null) {
      _paused = true;
      _subscription.pause();
    }
  }

  void _onDone() {
    _done = true;
    _settle();
    final Completer<Uint8List?>? pending = _pending;
    if (pending != null && _buffered < _want) {
      _pending = null;
      pending.complete(null);
    }
  }

  void _onError(Object error) {
    _error = error;
    final Completer<Uint8List?>? pending = _pending;
    if (pending != null) {
      _pending = null;
      pending.completeError(error);
    }
  }

  void _settle() {
    final Completer<Uint8List?>? pending = _pending;
    if (pending == null || _buffered < _want) return;
    _pending = null;
    final Uint8List frame = _take(_want);
    _maybeResume();
    pending.complete(frame);
  }

  /// Lets ffmpeg run again once the buffer has drained below the cap. Waiting
  /// until a read actually blocks would stop and start the pipe on every
  /// frame instead of keeping it flowing.
  void _maybeResume() {
    if (!_paused || _buffered >= maxBufferedBytes) return;
    _paused = false;
    _subscription.resume();
  }

  Uint8List _take(int n) {
    final Uint8List out = Uint8List(n);
    int written = 0;
    while (written < n) {
      final Uint8List head = _chunks.first;
      final int take = head.length <= n - written ? head.length : n - written;
      out.setRange(written, written + take, head);
      written += take;
      if (take == head.length) {
        _chunks.removeAt(0);
      } else {
        _chunks[0] = Uint8List.sublistView(head, take);
      }
    }
    _buffered -= n;
    return out;
  }

  void cancel() {
    _chunks.clear();
    _buffered = 0;
    _subscription.cancel();
  }
}
