import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../utils/sun_calc.dart';

/// Interactive 24-hour timeline bar for picking a driving window.
///
/// The background shows actual day/night zones based on [sunTimes] (computed
/// from the trip location + date via [SunCalc]). When [sunTimes] is null, it
/// falls back to a fixed 06:00–20:00 day window.
///
/// Two pill-shaped drag handles sit on top — start (left) and end (right).
/// Dragging snaps to [snapMinutes] intervals (default 15 min).
///
/// [onChanged] fires on every snap with (startMinutes, endMinutes), both
/// expressed as minutes from midnight (0–1440).
class DrivingWindowBar extends StatefulWidget {
  const DrivingWindowBar({
    super.key,
    required this.startMinutes,
    required this.endMinutes,
    this.sunTimes,
    this.onChanged,
    this.snapMinutes = 15,
  }) : assert(startMinutes >= 0 && startMinutes < 1440),
       assert(endMinutes > startMinutes && endMinutes <= 1440);

  final int startMinutes;
  final int endMinutes;

  /// Real sunrise/sunset from [SunCalc.compute]. When null, 06:00/20:00 are used.
  final SunTimes? sunTimes;

  final void Function(int startMinutes, int endMinutes)? onChanged;
  final int snapMinutes;

  @override
  State<DrivingWindowBar> createState() => _DrivingWindowBarState();
}

class _DrivingWindowBarState extends State<DrivingWindowBar> {
  late int _start;
  late int _end;

  static const double _trackH = 52.0;
  static const double _handleW = 20.0;
  static const double _handleH = 38.0;
  static const int _dayMinutes = 1440;

  int get _sunriseMin => widget.sunTimes?.sunriseMinutes ?? 360; // 06:00
  int get _sunsetMin => widget.sunTimes?.sunsetMinutes ?? 1200;  // 20:00

  @override
  void initState() {
    super.initState();
    _start = widget.startMinutes;
    _end = widget.endMinutes;
  }

  @override
  void didUpdateWidget(DrivingWindowBar old) {
    super.didUpdateWidget(old);
    if (old.startMinutes != widget.startMinutes) _start = widget.startMinutes;
    if (old.endMinutes != widget.endMinutes) _end = widget.endMinutes;
  }

  int _snap(double raw) {
    final snapped = (raw / widget.snapMinutes).round() * widget.snapMinutes;
    return snapped.clamp(0, _dayMinutes).toInt();
  }

  double _minutesToX(double width, int minutes) =>
      (minutes / _dayMinutes) * width;

  int _xToMinutes(double width, double x) =>
      _snap((x / width) * _dayMinutes);

  String _fmt(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  bool _isNight(int minutes) =>
      minutes < _sunriseMin || minutes >= _sunsetMin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bright = Theme.of(context).brightness == Brightness.dark;
    final l = AppLocalizations.of(context);
    final durationMin = _end - _start;
    final durationH = durationMin ~/ 60;
    final durationM = durationMin % 60;
    final durationStr = durationM == 0
        ? '${durationH}h'
        : '${durationH}h ${durationM}min';

    final startNight = _isNight(_start);
    final endNight = _isNight(_end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Timeline bar ──────────────────────────────────────────────
        LayoutBuilder(builder: (ctx, constraints) {
          final W = constraints.maxWidth;
          final startX = _minutesToX(W, _start);
          final endX = _minutesToX(W, _end);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) {
              final x = d.localPosition.dx.clamp(0.0, W);
              final toStart = (x - startX).abs();
              final toEnd = (x - endX).abs();
              final newMin = _xToMinutes(W, x);
              setState(() {
                if (toStart <= toEnd) {
                  final clamped =
                      newMin.clamp(0, _end - widget.snapMinutes);
                  if (clamped != _start) {
                    _start = clamped;
                    HapticFeedback.selectionClick();
                    widget.onChanged?.call(_start, _end);
                  }
                } else {
                  final clamped =
                      newMin.clamp(_start + widget.snapMinutes, _dayMinutes);
                  if (clamped != _end) {
                    _end = clamped;
                    HapticFeedback.selectionClick();
                    widget.onChanged?.call(_start, _end);
                  }
                }
              });
            },
            child: SizedBox(
              height: _trackH,
              width: W,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── Background: actual day/night gradient ───────────
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CustomPaint(
                        painter: _DayNightPainter(
                          sunriseMin: _sunriseMin,
                          sunsetMin: _sunsetMin,
                          isPolarDay: widget.sunTimes?.isPolarDay ?? false,
                        ),
                      ),
                    ),
                  ),
                  // ── Selection fill ─────────────────────────────────
                  Positioned(
                    left: startX,
                    width: (endX - startX).clamp(0.0, W),
                    top: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.35),
                        border: Border(
                          top: BorderSide(color: scheme.primary, width: 2),
                          bottom:
                              BorderSide(color: scheme.primary, width: 2),
                        ),
                      ),
                    ),
                  ),
                  // ── Sunrise marker ─────────────────────────────────
                  if (!( widget.sunTimes?.isPolarDay ?? false) &&
                      !(widget.sunTimes?.isPolarNight ?? false))
                    _SunMarker(
                      x: _minutesToX(W, _sunriseMin),
                      isRise: true,
                      label: _fmt(_sunriseMin),
                    ),
                  // ── Sunset marker ──────────────────────────────────
                  if (!( widget.sunTimes?.isPolarDay ?? false) &&
                      !(widget.sunTimes?.isPolarNight ?? false))
                    _SunMarker(
                      x: _minutesToX(W, _sunsetMin),
                      isRise: false,
                      label: _fmt(_sunsetMin),
                    ),
                  // ── Hour tick marks ────────────────────────────────
                  ...List.generate(25, (h) {
                    final x = _minutesToX(W, h * 60);
                    final major = h % 6 == 0;
                    return Positioned(
                      left: x - 0.5,
                      top: major ? 0 : _trackH * 0.55,
                      child: Container(
                        width: 1,
                        height: major ? _trackH * 0.55 : _trackH * 0.25,
                        color: Colors.white.withValues(
                            alpha: major ? 0.3 : 0.12),
                      ),
                    );
                  }),
                  // ── 6-hour labels ──────────────────────────────────
                  ...['00', '06', '12', '18', '24'].asMap().entries.map((e) {
                    final h = e.key * 6;
                    final x = _minutesToX(W, h * 60);
                    return Positioned(
                      left: (x - 10).clamp(0, W - 22),
                      bottom: 3,
                      child: Text(
                        e.value,
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: Colors.white60,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }),
                  // ── Start handle ───────────────────────────────────
                  Positioned(
                    left: startX - _handleW / 2,
                    top: (_trackH - _handleH) / 2,
                    child: _Handle(
                      label: _fmt(_start),
                      isNight: startNight,
                      color: scheme.primary,
                    ),
                  ),
                  // ── End handle ─────────────────────────────────────
                  Positioned(
                    left: (endX - _handleW / 2).clamp(0.0, W - _handleW),
                    top: (_trackH - _handleH) / 2,
                    child: _Handle(
                      label: _fmt(_end),
                      isNight: endNight,
                      color: scheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        // ── Summary row ───────────────────────────────────────────────
        Row(
          children: [
            _TimeChip(
              icon: startNight
                  ? Icons.nightlight_round
                  : Icons.wb_sunny_rounded,
              label: _fmt(_start),
              color: startNight
                  ? const Color(0xFF818CF8)
                  : const Color(0xFFFBBF24),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.arrow_forward, size: 13, color: Colors.white54),
            ),
            _TimeChip(
              icon: endNight
                  ? Icons.nightlight_round
                  : Icons.wb_sunny_rounded,
              label: _fmt(_end),
              color: endNight
                  ? const Color(0xFF818CF8)
                  : const Color(0xFFFBBF24),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                durationStr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        // ── Night driving warning ─────────────────────────────────────
        if (startNight || endNight) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.nightlight_round, size: 13,
                  color: Color(0xFF818CF8)),
              const SizedBox(width: 6),
              Text(
                startNight
                    ? l.drivingWindowNightStart
                    : l.drivingWindowNightEnd,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF818CF8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Sunrise/sunset marker ─────────────────────────────────────────────────────

class _SunMarker extends StatelessWidget {
  const _SunMarker({
    required this.x,
    required this.isRise,
    required this.label,
  });

  final double x;
  final bool isRise;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x - 1,
      top: 0,
      bottom: 0,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 2,
            height: 10,
            color: isRise
                ? const Color(0xFFFBBF24).withValues(alpha: 0.8)
                : const Color(0xFFF97316).withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }
}

// ── Drag handle pill ──────────────────────────────────────────────────────────

class _Handle extends StatelessWidget {
  const _Handle({
    required this.label,
    required this.isNight,
    required this.color,
  });

  final String label;
  final bool isNight;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 38,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.55),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded,
            size: 9,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 3),
          for (var i = 0; i < 3; i++) ...[
            Container(width: 8, height: 1.5,
                color: Colors.white.withValues(alpha: 0.5)),
            if (i < 2) const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }
}

// ── Time chip ─────────────────────────────────────────────────────────────────

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Day/Night background painter ──────────────────────────────────────────────

class _DayNightPainter extends CustomPainter {
  const _DayNightPainter({
    required this.sunriseMin,
    required this.sunsetMin,
    required this.isPolarDay,
  });

  final int sunriseMin;
  final int sunsetMin;
  final bool isPolarDay;

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;

    if (isPolarDay) {
      // Polar day — full day gradient
      final paint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF38BDF8), Color(0xFF7DD3FC)],
        ).createShader(Rect.fromLTWH(0, 0, W, H));
      canvas.drawRect(Rect.fromLTWH(0, 0, W, H), paint);
      return;
    }

    // Base: night colour fills everything
    final nightPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
      ).createShader(Rect.fromLTWH(0, 0, W, H));
    canvas.drawRect(Rect.fromLTWH(0, 0, W, H), nightPaint);

    // Day zone between real sunrise and sunset
    final dx = (sunriseMin / 1440.0) * W;
    final dw = ((sunsetMin - sunriseMin) / 1440.0) * W;
    if (dw > 0) {
      final dayPaint = Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF0EA5E9), // dawn/dusk sky blue
            Color(0xFF38BDF8), // midday sky
            Color(0xFFFB923C), // dusk orange
          ],
          stops: [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(dx, 0, dw, H));
      canvas.drawRect(Rect.fromLTWH(dx, 0, dw, H), dayPaint);

      // Soft dawn blend (night → day)
      final blendW = (W * 0.04).clamp(12.0, 40.0);
      final dawnPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0xFF0EA5E9).withValues(alpha:0.7),
          ],
        ).createShader(Rect.fromLTWH(dx - blendW, 0, blendW, H));
      canvas.drawRect(
          Rect.fromLTWH(dx - blendW, 0, blendW, H), dawnPaint);

      // Soft dusk blend (day → night)
      final duskPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFB923C).withValues(alpha:0.7),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(dx + dw, 0, blendW, H));
      canvas.drawRect(Rect.fromLTWH(dx + dw, 0, blendW, H), duskPaint);
    }
  }

  @override
  bool shouldRepaint(_DayNightPainter old) =>
      old.sunriseMin != sunriseMin || old.sunsetMin != sunsetMin;
}
