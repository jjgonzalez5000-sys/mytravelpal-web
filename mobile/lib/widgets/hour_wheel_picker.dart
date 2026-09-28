import 'package:flutter/material.dart';

import '../design/tokens.dart';

part 'duration_wheel_picker.dart';

/// A horizontal band that scrolls to pick an hour value.
///
/// Three items are always visible: the current pick is centered under a
/// pill highlight, with the previous and next values peeking on either
/// side to preview the swipe direction. Users can swipe left/right OR
/// tap the peripheral values to move by one.
///
/// The [DurationWheelPicker] sibling (see duration_wheel_picker.dart)
/// reuses the same [_WheelBand] core with a different value formatter.
class HourWheelPicker extends StatefulWidget {
  const HourWheelPicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.label,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  /// Optional label rendered above the band. Callers that already print
  /// their own label can leave this null.
  final String? label;

  @override
  State<HourWheelPicker> createState() => _HourWheelPickerState();
}

class _HourWheelPickerState extends State<HourWheelPicker> {
  @override
  Widget build(BuildContext context) {
    return _WheelBand(
      value: widget.value,
      min: widget.min,
      max: widget.max,
      onChanged: widget.onChanged,
      label: widget.label,
      formatter: _formatHour,
      leadingIcon: Icons.schedule,
    );
  }

  static String _formatHour(int h) => '${h.toString().padLeft(2, '0')}:00';
}

/// Shared internals for [HourWheelPicker] + [DurationWheelPicker].
///
/// A [PageController] with `viewportFraction ≈ 0.28` renders three items
/// side-by-side so the centered pick shows its neighbours. Swiping snaps
/// to the nearest page and calls [_WheelBand.onChanged]; tapping a
/// peripheral value animates to it.
class _WheelBand extends StatefulWidget {
  const _WheelBand({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.formatter,
    required this.leadingIcon,
    this.label,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String Function(int) formatter;
  final IconData leadingIcon;
  final String? label;

  @override
  State<_WheelBand> createState() => _WheelBandState();
}

class _WheelBandState extends State<_WheelBand> {
  late PageController _controller;
  late int _currentIndex;

  int get _count => widget.max - widget.min + 1;

  int _clamp(int v) => v.clamp(widget.min, widget.max);

  int _indexFor(int value) => _clamp(value) - widget.min;

  int _valueFor(int index) => widget.min + index;

  @override
  void initState() {
    super.initState();
    _currentIndex = _indexFor(widget.value);
    _controller = PageController(
      initialPage: _currentIndex,
      viewportFraction: 0.28,
    );
  }

  @override
  void didUpdateWidget(covariant _WheelBand oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _indexFor(widget.value);
    if (target != _currentIndex) {
      _currentIndex = target;
      // Programmatic value change from the outside — snap silently
      // without firing onChanged again.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        _controller.animateToPage(
          target,
          duration: Tokens.motionFast,
          curve: Tokens.curveOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    widget.onChanged(_valueFor(index));
  }

  void _jumpTo(int index) {
    final target = index.clamp(0, _count - 1);
    _controller.animateToPage(
      target,
      duration: Tokens.motionFast,
      curve: Tokens.curveOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(widget.leadingIcon, size: 16,
                    color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.label!,
                    style: t.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Highlight pill anchored to the centre — sits behind the
              // page view so the centred item reads as "held" by it.
              IgnorePointer(
                child: AnimatedContainer(
                  duration: Tokens.motionFast,
                  curve: Tokens.curveOut,
                  width: 88,
                  height: 56,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius:
                        BorderRadius.circular(Tokens.radiusPill),
                  ),
                ),
              ),
              PageView.builder(
                controller: _controller,
                itemCount: _count,
                onPageChanged: _onPageChanged,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final value = _valueFor(index);
                  final isCurrent = index == _currentIndex;
                  final label = widget.formatter(value);
                  return _WheelItem(
                    label: label,
                    isCurrent: isCurrent,
                    onTap: isCurrent ? null : () => _jumpTo(index),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WheelItem extends StatelessWidget {
  const _WheelItem({
    required this.label,
    required this.isCurrent,
    required this.onTap,
  });

  final String label;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final color = isCurrent
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant.withValues(alpha: 0.7);
    final style = (isCurrent ? t.titleLarge : t.titleMedium)?.copyWith(
      color: color,
      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: Tokens.motionFast,
          curve: Tokens.curveOut,
          style: style ?? const TextStyle(),
          child: Text(label),
        ),
      ),
    );
  }
}
