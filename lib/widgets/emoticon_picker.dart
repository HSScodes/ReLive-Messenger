import 'package:flutter/material.dart';

import '../utils/emoticon_map.dart';

/// Compact grid popup that lets the user tap an emoticon to insert its code.
class EmoticonPicker extends StatelessWidget {
  const EmoticonPicker({super.key, required this.onPicked});

  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(4),
      color: const Color(0xFFF5F5F5),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(6),
        child: Wrap(
          spacing: 2,
          runSpacing: 2,
          children: [
            for (final def in emoticonDefs)
              _Cell(def: def, onTap: () => onPicked(def.codes.first)),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.def, required this.onTap});
  final EmoticonDef def;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${def.name}  ${def.codes.first}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: SizedBox(
              width: emoticonCellSize,
              height: emoticonCellSize,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: emoticonCellSize * emoticonCount,
                  maxHeight: emoticonCellSize,
                  child: Transform.translate(
                    offset: Offset(-emoticonCellSize * def.index, 0),
                    child: Image.asset(
                      emoticonSpriteAsset,
                      width: emoticonCellSize * emoticonCount,
                      height: emoticonCellSize,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
