/// Minimal `--key=value` / `--key value` / `--flag` parser.
///
/// Zero dependencies on purpose -- the CLI should be runnable straight from a
/// checkout without a network round trip.
class CliArgs {
  CliArgs(List<String> raw) {
    for (int i = 0; i < raw.length; i++) {
      final String token = raw[i];
      if (!token.startsWith('--')) {
        rest.add(token);
        continue;
      }
      final String body = token.substring(2);
      final int eq = body.indexOf('=');
      if (eq >= 0) {
        _values[body.substring(0, eq)] = body.substring(eq + 1);
      } else if (i + 1 < raw.length && !raw[i + 1].startsWith('--')) {
        _values[body] = raw[++i];
      } else {
        _values[body] = 'true';
      }
    }
  }

  final Map<String, String> _values = <String, String>{};
  final List<String> rest = <String>[];

  bool flag(String key, {bool defaultValue = false}) {
    final String? value = _values[key];
    if (value == null) return defaultValue;
    return value != 'false';
  }

  String? optional(String key) => _values[key];

  String value(String key, String defaultValue) => _values[key] ?? defaultValue;

  String require(String key) {
    final String? v = _values[key];
    if (v == null) {
      throw FormatException('Missing required option --$key');
    }
    return v;
  }

  int? optionalInt(String key) {
    final String? v = _values[key];
    if (v == null) return null;
    final int? parsed = int.tryParse(v);
    if (parsed == null) {
      throw FormatException('--$key must be an integer, got "$v"');
    }
    return parsed;
  }

  /// Parses `--size 1080x1920`.
  (int, int)? optionalSize(String key) {
    final String? v = _values[key];
    if (v == null) return null;
    final List<String> parts = v.toLowerCase().split('x');
    if (parts.length != 2) {
      throw FormatException('--$key must look like 1080x1920, got "$v"');
    }
    final int? w = int.tryParse(parts[0]);
    final int? h = int.tryParse(parts[1]);
    if (w == null || h == null) {
      throw FormatException('--$key must look like 1080x1920, got "$v"');
    }
    return (w, h);
  }
}
