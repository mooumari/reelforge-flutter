import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttermotion/src/quiet_host.dart';

/// What can be checked about [quietHost] from a test, which is less than it
/// looks.
///
/// The risky part of this file is the `objc_msgSend` casts, and a wrong cast
/// does not fail an expectation -- it corrupts the stack or crashes the
/// process. A test can only reach them where AppKit is linked, and the Flutter
/// test harness is a command-line binary where it is not, so passing here says
/// only that the lookups are safe when the runtime is absent.
///
/// The real evidence is a render: the host is launched, `lsappinfo` is asked
/// whether it registered as a UI application, and the frames it produces are
/// compared byte for byte against a windowed host's. See the commit that added
/// this file.
void main() {
  test('quietening a host never throws, whatever the process is', () {
    expect(quietHost, returnsNormally);
  });

  test('a host is only quietened where there is a window to hide', () {
    if (!Platform.isMacOS) {
      expect(quietHost(), isFalse);
    }
  }, skip: Platform.isMacOS ? 'macOS is the platform this does something on' : null);

  test('asking twice is not an error', () {
    expect(quietHost(), quietHost());
  });
}
