// The render host runs inside whatever the user's app is allowed to do. When
// a helper process will not start, the errno is the only evidence, and the two
// common causes want opposite advice.
import 'dart:io';

import 'package:fluttermotion/src/media/spawn.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a sandbox denial is reported as a sandbox denial', () {
    final String message = Spawn.explain(
      '/opt/homebrew/bin/ffmpeg',
      const ProcessException(
        '/opt/homebrew/bin/ffmpeg',
        <String>[],
        'Operation not permitted',
        1,
      ),
    );
    expect(message, contains('sandboxed'));
    expect(message, contains('app-sandbox'));
    expect(message, contains('Release.entitlements'));
    // The opposite advice must not also be present, or the user has to guess.
    expect(message, isNot(contains('brew install')));
  });

  test('a missing binary is reported as a missing binary', () {
    final String message = Spawn.explain(
      'ffprobe',
      const ProcessException('ffprobe', <String>[], 'No such file', 2),
    );
    expect(message, contains('could not find ffprobe'));
    expect(message, contains('brew install ffmpeg'));
    expect(message, isNot(contains('sandbox')));
  });

  test('anything else still says what happened', () {
    final String message = Spawn.explain(
      'ffmpeg',
      const ProcessException('ffmpeg', <String>[], 'Too many open files', 24),
    );
    expect(message, contains('Too many open files'));
  });

  test('the explanation replaces the message and keeps the errno', () async {
    // The host reports failures as JSON over stdout, so what survives is the
    // exception's message -- which is why the diagnosis has to live there
    // rather than being printed alongside.
    await expectLater(
      Spawn.run('/definitely/not/a/binary', const <String>[]),
      throwsA(
        isA<ProcessException>()
            .having(
              (ProcessException e) => e.message,
              'message',
              contains('could not find'),
            )
            .having((ProcessException e) => e.errorCode, 'errorCode', 2),
      ),
    );
  });
}
