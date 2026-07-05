import 'package:flutter/material.dart';
import '../l10n/app_localizations_extension.dart';
import '../l10n/enum_localizations.dart';
import '../models/user_trick.dart';

class ConsistencySelector extends StatefulWidget {
  final Consistency selected;
  final ValueChanged<Consistency> onChanged;

  const ConsistencySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<ConsistencySelector> createState() => _ConsistencySelectorState();
}

class _ConsistencySelectorState extends State<ConsistencySelector> {
  static const _thumbRadius = 10.0;
  static const _overlayRadius = 20.0;

  double? _dragValue;

  int get _maxLevel => Consistency.values.length - 1;

  Consistency get _displayed => _dragValue != null
      ? Consistency.values[_dragValue!.round()]
      : widget.selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final displayed = _displayed;
    final activeColor = displayed.borderColor(brightness);
    final trackColor = brightness == Brightness.dark
        ? const Color(0xFF3A3A3A)
        : Colors.black;
    final sliderValue = _dragValue ?? widget.selected.index.toDouble();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: LayoutBuilder(builder: (context, constraints) {
          final trackInset = _overlayRadius;
          final trackWidth = constraints.maxWidth - 2 * trackInset;
          // Same-row neighbours are two ticks apart; sizing labels to that
          // distance makes them as wide as possible without overlapping.
          final labelWidth = 2 * trackWidth / _maxLevel;
          double tickCenter(int level) =>
              trackInset + trackWidth * level / _maxLevel;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _labelRow(
                theme,
                brightness,
                displayed,
                tickCenter,
                labelWidth,
                levels: [
                  for (final c in Consistency.values)
                    if (c.index.isOdd) c
                ],
                dotBelowLabel: true,
              ),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 8,
                  trackShape: const RoundedRectSliderTrackShape(),
                  thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: _thumbRadius),
                  overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: _overlayRadius),
                  activeTrackColor: activeColor,
                  inactiveTrackColor: trackColor,
                  thumbColor: activeColor,
                  overlayColor: activeColor.withValues(alpha: 0.2),
                  tickMarkShape: SliderTickMarkShape.noTickMark,
                ),
                child: Slider(
                  value: sliderValue,
                  min: 0,
                  max: _maxLevel.toDouble(),
                  divisions: _maxLevel,
                  onChanged: (v) => setState(() => _dragValue = v),
                  onChangeEnd: (v) {
                    setState(() => _dragValue = null);
                    widget.onChanged(Consistency.values[v.round()]);
                  },
                ),
              ),
              _labelRow(
                theme,
                brightness,
                displayed,
                tickCenter,
                labelWidth,
                levels: [
                  for (final c in Consistency.values)
                    if (c.index.isEven) c
                ],
                dotBelowLabel: false,
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _labelRow(
    ThemeData theme,
    Brightness brightness,
    Consistency displayed,
    double Function(int level) tickCenter,
    double labelWidth, {
    required List<Consistency> levels,
    required bool dotBelowLabel,
  }) {
    return SizedBox(
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final level in levels)
            Positioned(
              left: tickCenter(level.index) - labelWidth / 2,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: labelWidth,
                child: Column(
                  mainAxisAlignment: dotBelowLabel
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: dotBelowLabel
                      ? [
                          _label(theme, brightness, level, displayed),
                          const SizedBox(height: 4),
                          _dot(theme, level, displayed),
                        ]
                      : [
                          _dot(theme, level, displayed),
                          const SizedBox(height: 4),
                          _label(theme, brightness, level, displayed),
                        ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _label(ThemeData theme, Brightness brightness, Consistency level,
      Consistency displayed) {
    final isSelected = level == displayed;
    final levelColor = level.borderColor(brightness);
    final pillTextColor =
        ThemeData.estimateBrightnessForColor(levelColor) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: isSelected
          ? BoxDecoration(
              color: levelColor,
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: Text(
        level.localizedLabel(context.l10n),
        textAlign: TextAlign.center,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? pillTextColor : null,
        ),
      ),
    );
  }

  Widget _dot(ThemeData theme, Consistency level, Consistency displayed) {
    final isSelected = level == displayed;
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? theme.colorScheme.onSurface
            : theme.colorScheme.outlineVariant,
      ),
    );
  }
}
