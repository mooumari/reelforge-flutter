/// A failure the user can act on, as opposed to one they can only report.
///
/// The CLI prints these verbatim: no `Bad state:` prefix, no stack trace. If a
/// message is worth writing carefully it is worth showing as written.
class CliError implements Exception {
  const CliError(this.message);

  final String message;

  @override
  String toString() => message;
}
