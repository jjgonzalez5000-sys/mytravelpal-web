import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';

/// Compact weather chip shown next to an origin/destination pick
/// on the plan screen. Renders icon + current temperature. Tap
/// opens a bottom sheet with the 7-day forecast for the same
/// coordinate.
///
/// Loads its own data when [lat] / [lon] change. Null coord →
/// zero-height sizedbox (no placeholder, no spinner — the plan
/// form is packed enough).
class WeatherChip extends ConsumerStatefulWidget {
  const WeatherChip({
    super.key,
    required this.lat,
    required this.lon,
  });

  final double? lat;
  final double? lon;

  @override
  ConsumerState<WeatherChip> createState() => _WeatherChipState();
}

class _WeatherChipState extends ConsumerState<WeatherChip> {
  WeatherPoint? _data;
  bool _loading = false;
  double? _loadedLat;
  double? _loadedLon;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeFetch();
  }

  @override
  void didUpdateWidget(covariant WeatherChip old) {
    super.didUpdateWidget(old);
    if (old.lat != widget.lat || old.lon != widget.lon) {
      _maybeFetch();
    }
  }

  Future<void> _maybeFetch() async {
    final lat = widget.lat;
    final lon = widget.lon;
    if (lat == null || lon == null) {
      setState(() => _data = null);
      return;
    }
    // Skip if we already loaded this exact coordinate.
    if (_loadedLat == lat && _loadedLon == lon) return;
    setState(() => _loading = true);
    final api = ref.read(apiClientWithPremiumProvider);
    final data = await api.weatherPoint(lat: lat, lon: lon);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
      _loadedLat = lat;
      _loadedLon = lon;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lat == null || widget.lon == null) {
      return const SizedBox.shrink();
    }
    if (_loading && _data == null) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: Padding(
          padding: EdgeInsets.all(6),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final data = _data;
    if (data == null || data.currentTempC == null) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _openForecastSheet(context, data),
      borderRadius: BorderRadius.circular(Tokens.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space8, vertical: 4,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Tokens.radiusPill),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(data.currentIcon),
                size: 16, color: scheme.primary),
            const SizedBox(width: 4),
            Text(
              '${data.currentTempC!.toStringAsFixed(0)}°',
              style: t.labelMedium
                  ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForecastSheet(
    BuildContext context,
    WeatherPoint data,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ForecastSheet(data: data),
    );
  }
}

IconData _iconFor(String? code) => switch (code) {
      'sunny' => Icons.wb_sunny_outlined,
      'partly_cloudy' => Icons.wb_cloudy,
      'cloudy' => Icons.cloud_outlined,
      'fog' => Icons.foggy,
      'drizzle' => Icons.grain,
      'rain' => Icons.water_drop_outlined,
      'heavy_rain' => Icons.thunderstorm,
      'snow' => Icons.ac_unit,
      'heavy_snow' => Icons.severe_cold,
      'thunderstorm' => Icons.flash_on,
      _ => Icons.wb_sunny_outlined,
    };

class _ForecastSheet extends StatelessWidget {
  const _ForecastSheet({required this.data});
  final WeatherPoint data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final dayFmt = DateFormat.EEEE(l.localeName);
    final dateFmt = DateFormat.MMMd(l.localeName);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space20, 0, Tokens.space20, Tokens.space24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.weatherForecastTitle, style: t.titleLarge),
            const SizedBox(height: Tokens.space16),
            for (var i = 0; i < data.daily.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        i == 0
                            ? l.weatherToday
                            : '${_capitalize(dayFmt.format(data.daily[i].date))} '
                                '${dateFmt.format(data.daily[i].date)}',
                        style: t.bodyMedium,
                      ),
                    ),
                    Icon(_iconFor(data.daily[i].icon),
                        size: 22, color: scheme.primary),
                    const SizedBox(width: Tokens.space12),
                    Expanded(
                      child: Text(
                        _tempRange(data.daily[i]),
                        style: t.bodyMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if ((data.daily[i].precipitationMm ?? 0) > 0.1)
                      Row(
                        children: [
                          Icon(Icons.water_drop_outlined,
                              size: 14, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Text(
                            '${data.daily[i].precipitationMm!.toStringAsFixed(0)} mm',
                            style: t.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _tempRange(DailyForecast d) {
    if (d.tempMinC != null && d.tempMaxC != null) {
      return '${d.tempMinC!.toStringAsFixed(0)}° / '
          '${d.tempMaxC!.toStringAsFixed(0)}°';
    }
    if (d.tempMaxC != null) {
      return '${d.tempMaxC!.toStringAsFixed(0)}°';
    }
    return '—';
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
