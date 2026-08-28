/// The data a document draws from, and the item a `repeat` is currently on.
///
/// A document is a template; this is what fills it. Lookups inside a repeat
/// check the item first and fall back to the root, so a nested template can
/// say `{{ label }}` for the item's own field and `{{ period }}` for something
/// from the top without either needing a prefix.
///
/// A plain value rather than only an InheritedWidget, because not everything a
/// repeat produces is a widget. `barChart.bars` repeats into `BarDatum`s, which
/// have no build context to hang a scope off; those resolve against one of
/// these passed by hand.
class DataScope {
  const DataScope({required this.data, this.item, this.itemIndex = -1});

  /// The root object, from `MotionDocument.build(data: ...)`.
  final Map<String, Object?> data;

  /// The element a `repeat` is on, when inside one.
  final Object? item;

  /// Its position, or -1 outside a repeat. Available as `{{ @index }}`.
  final int itemIndex;

  DataScope forItem(Object? item, int index) =>
      DataScope(data: data, item: item, itemIndex: index);

  /// Follows a dotted path, through maps by key and lists by index.
  ///
  /// Returns null for anything missing rather than throwing: a template that
  /// names a field the data does not have should render empty, not take the
  /// whole video down.
  Object? resolve(String path) {
    final String trimmed = path.trim();
    if (trimmed == '@index') return itemIndex;
    if (trimmed == '@item') return item;

    final List<String> parts = trimmed.split('.');

    // The item first, then the root. A repeat over `weeks` can say `label`
    // for the week and `period` for the report without a prefix on either.
    if (item != null) {
      final Object? fromItem = _walk(item, parts);
      if (fromItem != null) return fromItem;
    }
    return _walk(data, parts);
  }

  static Object? _walk(Object? from, List<String> parts) {
    Object? current = from;
    for (final String part in parts) {
      if (current is Map) {
        current = current[part];
      } else if (current is List) {
        final int? i = int.tryParse(part);
        if (i == null || i < 0 || i >= current.length) return null;
        current = current[i];
      } else {
        return null;
      }
      if (current == null) return null;
    }
    return current;
  }
}

/// Whether [value] is a string containing at least one `{{ }}` binding.
bool isBinding(Object? value) =>
    value is String && value.contains('{{') && value.contains('}}');

/// Whether [value] is a string that is *nothing but* one binding.
///
/// Those keep their type: `"{{ releases }}"` used where a number is wanted
/// gives the number, not the string `"128"`.
bool isWholeBinding(Object? value) {
  if (value is! String) return false;
  final String trimmed = value.trim();
  return trimmed.startsWith('{{') &&
      trimmed.endsWith('}}') &&
      trimmed.indexOf('{{', 2) == -1;
}

final RegExp _binding = RegExp(r'\{\{([^}]*)\}\}');

/// Resolves every `{{ }}` in [template] and returns the result as a string.
String fillString(DataScope scope, String template) =>
    template.replaceAllMapped(_binding, (Match match) {
      final Object? value = _evaluate(scope, match.group(1)!);
      return value == null ? '' : _stringify(value);
    });

/// Resolves a whole-string binding to its underlying value, type intact.
Object? fillValue(DataScope scope, String template) {
  final Match? match = _binding.firstMatch(template);
  if (match == null) return template;
  return _evaluate(scope, match.group(1)!);
}

/// `path | filter | filter(arg)`.
///
/// The filter set is deliberately five things long. Formatting a number for
/// display is genuinely necessary -- a template cannot render `+18.4%` from a
/// raw double without it -- and everything past that is a programming language
/// nobody asked for.
Object? _evaluate(DataScope scope, String expression) {
  final List<String> parts = expression.split('|');
  Object? value = scope.resolve(parts.first);
  for (int i = 1; i < parts.length; i++) {
    value = _applyFilter(value, parts[i].trim());
  }
  return value;
}

Object? _applyFilter(Object? value, String filter) {
  if (filter == 'round') {
    return value is num ? value.round() : value;
  }
  if (filter == 'upper') return _stringify(value).toUpperCase();
  if (filter == 'lower') return _stringify(value).toLowerCase();
  if (filter == 'sign') {
    // Applies to an already-formatted string as well as a number, so
    // `fixed(1) | sign` reads left to right and gives "+18.4" rather than
    // forcing the sign to be applied before the rounding it describes.
    final String text = value is num ? _stringify(value) : '$value';
    if (value is! num && double.tryParse(text) == null) return value;
    return text.startsWith('-') ? text : '+$text';
  }
  if (filter.startsWith('fixed')) {
    final int digits =
        int.tryParse(filter.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return value is num ? value.toStringAsFixed(digits) : value;
  }
  // An unknown filter is reported at parse time; at build time the value
  // passes through rather than the frame failing.
  return value;
}

/// Filters this package knows, for validation to check names against.
const Set<String> knownFilters = <String>{
  'round',
  'upper',
  'lower',
  'sign',
  'fixed',
};

/// Every filter name used anywhere in [expression].
List<String> filtersIn(String expression) => <String>[
  for (final Match match in _binding.allMatches(expression))
    ...match
        .group(1)!
        .split('|')
        .skip(1)
        .map((String f) => f.trim().replaceAll(RegExp(r'\(.*\)'), '')),
];

/// The data paths every `{{ }}` in [expression] reads, filters stripped.
///
/// `"{{ shipped | round }} of {{ totals.releases }}"` gives
/// `['shipped', 'totals.releases']`. `@index` and `@item` come back as
/// written; they resolve from the scope itself rather than from the data, and
/// a caller checking bindings against data has to know not to look for them.
List<String> bindingPathsIn(String expression) => <String>[
  for (final Match match in _binding.allMatches(expression))
    match.group(1)!.split('|').first.trim(),
];

String _stringify(Object? value) {
  if (value == null) return '';
  if (value is double && value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}
