part of 'hour_wheel_picker.dart';

/// A horizontal band that scrolls to pick a duration in whole hours,
/// suffixed with `h` (e.g. `8h`). Same visual language as
/// [HourWheelPicker] — the two share the [_WheelBand] core so they
/// stay pixel-identical.
///
/// Intended for driving-cap style pickers where the value is a duration,
/// not a clock time.
class DurationWheelPicker extends StatefulWidget {
  const DurationWheelPicker({
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
  final String? label;

  @override
  State<DurationWheelPicker> createState() => _DurationWheelPickerState();
}

class _DurationWheelPickerState extends State<DurationWheelPicker> {
  @override
  Widget build(BuildContext context) {
    return _WheelBand(
      value: widget.value,
      min: widget.min,
      max: widget.max,
      onChanged: widget.onChanged,
      label: widget.label,
      formatter: (v) => '${v}h',
      leadingIcon: Icons.timelapse,
    );
  }
}
