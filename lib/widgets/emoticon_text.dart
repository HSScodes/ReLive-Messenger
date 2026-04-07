import 'package:flutter/widgets.dart';

import '../utils/emoticon_map.dart';

/// Returns true for parenthesized codes like `(S)`, `(brb)`, etc.
/// These are matched case-insensitively to align with WLM 2009 behaviour.
bool _isParenCode(String code) => code.startsWith('(') && code.endsWith(')');

/// Parses [text] and returns a [TextSpan] tree where known WLM emoticon
/// short-codes are replaced with inline sprite images from the sprite sheet.
InlineSpan buildEmoticonSpan(String text, TextStyle? style) {
  final children = <InlineSpan>[];
  var i = 0;

  while (i < text.length) {
    int? matchedIndex;
    String? matchedCode;

    // Try each known code at current position (longest first).
    // Parenthesized codes like (S) are matched case-insensitively to match
    // WLM 2009 behaviour.
    for (final code in allEmoticonCodes) {
      if (i + code.length <= text.length) {
        final segment = text.substring(i, i + code.length);
        final matches = _isParenCode(code)
            ? segment.toLowerCase() == code.toLowerCase()
            : segment == code;
        if (matches) {
          matchedIndex = emoticonIndex(code);
          matchedCode = code;
          break;
        }
      }
    }

    if (matchedIndex != null && matchedCode != null) {
      children.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _EmoticonSprite(index: matchedIndex),
      ));
      i += matchedCode.length;
    } else {
      // Accumulate plain text until the next potential match.
      final start = i;
      i++;
      while (i < text.length) {
        var found = false;
        for (final code in allEmoticonCodes) {
          if (i + code.length <= text.length) {
            final segment = text.substring(i, i + code.length);
            final matches = _isParenCode(code)
                ? segment.toLowerCase() == code.toLowerCase()
                : segment == code;
            if (matches) {
              found = true;
              break;
            }
          }
        }
        if (found) break;
        i++;
      }
      children.add(TextSpan(text: text.substring(start, i), style: style));
    }
  }

  if (children.length == 1) return children.first;
  return TextSpan(children: children, style: style);
}

/// Renders a single 19×19 emoticon from the sprite sheet.
class _EmoticonSprite extends StatelessWidget {
  const _EmoticonSprite({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: emoticonCellSize,
      height: emoticonCellSize,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: emoticonCellSize * emoticonCount,
          maxHeight: emoticonCellSize,
          child: Transform.translate(
            offset: Offset(-emoticonCellSize * index, 0),
            child: Image.asset(
              emoticonSpriteAsset,
              width: emoticonCellSize * emoticonCount,
              height: emoticonCellSize,
              filterQuality: FilterQuality.none,
            ),
          ),
        ),
      ),
    );
  }
}
