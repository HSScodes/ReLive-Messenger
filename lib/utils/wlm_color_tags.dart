import 'package:flutter/painting.dart';

/// WLM 2009 colour palette for `[c=N]` BBCode-style display name tags.
///
/// Index 0 is the default text colour.  Indices 1–31 map to the selectable
/// colours from the WLM nick colour picker.  Unknown indices fall back to [0].
const List<Color> wlmColorPalette = <Color>[
  Color(0xFF000000), //  0 — black (default)
  Color(0xFF0000FF), //  1 — blue
  Color(0xFF008000), //  2 — green
  Color(0xFF00BFFF), //  3 — deep sky blue
  Color(0xFFFF0000), //  4 — red
  Color(0xFFFF8C00), //  5 — dark orange
  Color(0xFFFF00FF), //  6 — magenta
  Color(0xFF9ACD32), //  7 — yellow green
  Color(0xFFFF6347), //  8 — tomato
  Color(0xFF808080), //  9 — grey
  Color(0xFF00CED1), // 10 — dark turquoise
  Color(0xFF8A2BE2), // 11 — blue violet
  Color(0xFF4B0082), // 12 — indigo
  Color(0xFFBA55D3), // 13 — medium orchid
  Color(0xFF2E8B57), // 14 — sea green
  Color(0xFFA0522D), // 15 — sienna
  Color(0xFF1E90FF), // 16 — dodger blue
  Color(0xFFDAA520), // 17 — goldenrod
  Color(0xFF696969), // 18 — dim grey
  Color(0xFF5F9EA0), // 19 — cadet blue
  Color(0xFFCD853F), // 20 — peru
  Color(0xFFB8860B), // 21 — dark goldenrod
  Color(0xFFDB7093), // 22 — pale violet red
  Color(0xFFD2691E), // 23 — chocolate
  Color(0xFF191970), // 24 — midnight blue
  Color(0xFF8B0000), // 25 — dark red
  Color(0xFF556B2F), // 26 — dark olive green
  Color(0xFF800080), // 27 — purple
  Color(0xFF008B8B), // 28 — dark cyan
  Color(0xFFB22222), // 29 — firebrick
  Color(0xFF6B8E23), // 30 — olive drab
  Color(0xFF2F4F4F), // 31 — dark slate grey
];

/// A single segment of a parsed WLM display name.
class WlmTextSegment {
  const WlmTextSegment(this.text, this.color);

  /// The plain text content (no BBCode markup).
  final String text;

  /// The resolved colour for this segment (from [wlmColorPalette]).
  final Color color;
}

/// The regex that matches one `[c=N]...[/c=N]` block (including nesting-free
/// cases and optional closing index).
final RegExp _colorTagRe = RegExp(
  r'\[c=(\d+)\](.*?)\[/c(?:=\d+)?\]',
  caseSensitive: false,
  dotAll: true,
);

/// Parses a WLM display name that may contain `[c=N]...[/c=N]` colour tags
/// into a list of [WlmTextSegment]s.
///
/// Text outside any colour tag receives [defaultColor].
/// Unknown palette indices fall back to [defaultColor].
List<WlmTextSegment> parseWlmColorTags(
  String raw, {
  Color defaultColor = const Color(0xFF000000),
}) {
  final segments = <WlmTextSegment>[];
  var cursor = 0;

  for (final m in _colorTagRe.allMatches(raw)) {
    // Text before the tag.
    if (m.start > cursor) {
      final before = raw.substring(cursor, m.start);
      if (before.isNotEmpty) {
        segments.add(WlmTextSegment(before, defaultColor));
      }
    }

    final idx = int.tryParse(m.group(1) ?? '') ?? 0;
    final color =
        (idx >= 0 && idx < wlmColorPalette.length) ? wlmColorPalette[idx] : defaultColor;
    final inner = m.group(2) ?? '';
    if (inner.isNotEmpty) {
      segments.add(WlmTextSegment(inner, color));
    }

    cursor = m.end;
  }

  // Trailing text.
  if (cursor < raw.length) {
    final tail = raw.substring(cursor);
    if (tail.isNotEmpty) {
      segments.add(WlmTextSegment(tail, defaultColor));
    }
  }

  // If no tags were found, return the raw text as a single segment.
  if (segments.isEmpty) {
    segments.add(WlmTextSegment(raw, defaultColor));
  }

  return segments;
}

/// Returns the plain text of a WLM display name with all `[c=N]` / `[/c=N]`
/// tags stripped.
String stripWlmColorTags(String raw) {
  return raw
      .replaceAllMapped(_colorTagRe, (m) => m.group(2) ?? '')
      .replaceAll(RegExp(r'\[/?c(?:=\d+)?\]'), '');
}

/// Returns the **first** colour index found in a WLM display name, or `null`
/// if the name has no colour tags.
int? firstWlmColorIndex(String raw) {
  final m = _colorTagRe.firstMatch(raw);
  if (m == null) return null;
  return int.tryParse(m.group(1) ?? '');
}
