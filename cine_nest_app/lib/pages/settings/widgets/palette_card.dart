import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// 配色方案色卡（原封照搬 Kazumi `lib/bean/card/palette_card.dart`）。
///
/// 用 HCT 色彩空间从种子色推出 primary / tertiary / primaryContainer 三块，
/// 拼成一个四分色环预览，选中时盖一个对勾圆点。和 Kazumi 视觉一致。
class PaletteCard extends StatelessWidget {
  final Color color;
  final bool selected;

  const PaletteCard({
    super.key,
    required this.color,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final Hct hct = Hct.fromInt(color.toARGB32());
    final primary = Color(Hct.from(hct.hue, 20.0, 90.0).toInt());
    final tertiary = Color(Hct.from(hct.hue + 50, 20.0, 85.0).toInt());
    final primaryContainer = Color(Hct.from(hct.hue, 30.0, 50.0).toInt());
    final checkbox = Color(Hct.from(hct.hue, 30.0, 40.0).toInt());
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        children: [
          Card(
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(10),
              child: ClipOval(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(child: Container(color: primary)),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(child: Container(color: tertiary)),
                          Expanded(child: Container(color: primaryContainer)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (selected)
            Center(
              child: Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: checkbox,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
