import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as ll;

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../domain/vignette_info.dart';
import '../services/currency_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows a full trip toll breakdown grouped by day.
/// Tolls can be toggled (pay / skip) from here — changes propagate
/// to [onToggle] which updates the parent result screen state.
Future<void> showTollSummarySheet({
  required BuildContext context,
  required List<PartialTollSkip> partialTollSkips,
  required List<DayPlan> days,
  required Set<int> tollSkipEnabled,
  required void Function(int idx, bool pay) onToggle,
  required double routeTollCostEur,
  required double vignetteCostEur,
  required List<String> vignetteCountries,
  List<VignetteLine> vignettes = const [],
  required String ccy,
  DateTime? tripDepartureAt,
  double? routeFreeFlowMinutes,
  double? routeTotalKm,
  HourlyTollReport? hourlyReport,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => _TollSummarySheet(
      partialTollSkips: partialTollSkips,
      days: days,
      initialEnabled: Set.of(tollSkipEnabled),
      onToggle: onToggle,
      routeTollCostEur: routeTollCostEur,
      vignetteCostEur: vignetteCostEur,
      vignetteCountries: vignetteCountries,
      vignettes: vignettes,
      ccy: ccy,
      tripDepartureAt: tripDepartureAt,
      routeFreeFlowMinutes: routeFreeFlowMinutes,
      routeTotalKm: routeTotalKm,
      hourlyReport: hourlyReport,
    ),
  );
}

// ---------------------------------------------------------------------------

class _TollSummarySheet extends StatefulWidget {
  const _TollSummarySheet({
    required this.partialTollSkips,
    required this.days,
    required this.initialEnabled,
    required this.onToggle,
    required this.routeTollCostEur,
    required this.vignetteCostEur,
    required this.vignetteCountries,
    this.vignettes = const [],
    required this.ccy,
    this.tripDepartureAt,
    this.routeFreeFlowMinutes,
    this.routeTotalKm,
    this.hourlyReport,
  });

  final List<PartialTollSkip> partialTollSkips;
  final List<DayPlan> days;
  final Set<int> initialEnabled;
  final void Function(int, bool) onToggle;
  final double routeTollCostEur;
  final double vignetteCostEur;
  final List<String> vignetteCountries;
  final List<VignetteLine> vignettes;
  final String ccy;
  final DateTime? tripDepartureAt;
  final double? routeFreeFlowMinutes;
  final double? routeTotalKm;
  final HourlyTollReport? hourlyReport;

  @override
  State<_TollSummarySheet> createState() => _TollSummarySheetState();
}

class _TollSummarySheetState extends State<_TollSummarySheet> {
  late Set<int> _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = Set.of(widget.initialEnabled);
  }

  void _toggle(int idx, bool pay) {
    setState(() {
      if (pay) {
        _enabled.add(idx);
      } else {
        _enabled.remove(idx);
      }
    });
    widget.onToggle(idx, pay);
  }

  /// Bucket partialTollSkips into day segments using DayPlan km ranges.
  /// Returns list of (dayIndex, dayPlan, [(globalIndex, skip)]).
  List<(int, DayPlan, List<(int, PartialTollSkip)>)> _bucketByDay() {
    final out = <(int, DayPlan, List<(int, PartialTollSkip)>)>[];
    for (var d = 0; d < widget.days.length; d++) {
      final day = widget.days[d];
      final bucket = <(int, PartialTollSkip)>[];
      for (var i = 0; i < widget.partialTollSkips.length; i++) {
        final s = widget.partialTollSkips[i];
        if (s.distanceFromOriginKm >= day.fromKm &&
            s.distanceFromOriginKm <= day.toKm) {
          bucket.add((i, s));
        }
      }
      if (bucket.isNotEmpty) {
        out.add((d, day, bucket));
      }
    }
    // Any skip not assigned to a day (edge case) → last bucket.
    final assigned = out.expand((t) => t.$3.map((e) => e.$1)).toSet();
    final unassigned = [
      for (var i = 0; i < widget.partialTollSkips.length; i++)
        if (!assigned.contains(i)) (i, widget.partialTollSkips[i]),
    ];
    if (unassigned.isNotEmpty && widget.days.isNotEmpty) {
      final last = widget.days.last;
      out.add((widget.days.length - 1, last, unassigned));
    }
    return out;
  }

  /// Estimated hour of arrival at a booth, for the hourly verdict badge.
  int? _etaHour(PartialTollSkip s) {
    final dep = widget.tripDepartureAt;
    final ff = widget.routeFreeFlowMinutes;
    final total = widget.routeTotalKm;
    if (dep == null || ff == null || total == null || total <= 0) return null;
    final frac = (s.distanceFromOriginKm / total).clamp(0.0, 1.0);
    return dep.add(Duration(minutes: (ff * frac).round())).toLocal().hour;
  }

  double get _effectiveTolls {
    if (widget.partialTollSkips.isEmpty) return widget.routeTollCostEur;
    var paid = 0.0;
    for (var i = 0; i < widget.partialTollSkips.length; i++) {
      if (_enabled.contains(i)) paid += widget.partialTollSkips[i].savingsEur;
    }
    return paid + widget.vignetteCostEur;
  }

  double get _savedEur {
    var saved = 0.0;
    for (var i = 0; i < widget.partialTollSkips.length; i++) {
      if (!_enabled.contains(i)) saved += widget.partialTollSkips[i].savingsEur;
    }
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final buckets = _bucketByDay();
    final saved = _savedEur;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Tokens.radiusXl),
          ),
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: Tokens.space12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space20, Tokens.space16, Tokens.space20, 0),
              child: Row(
                children: [
                  Icon(Icons.toll_outlined, color: scheme.primary),
                  const SizedBox(width: Tokens.space8),
                  Expanded(
                    child: Text(
                      l.tollSummaryTitle,
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  // Map button (nothing to map on a vignette-only trip)
                  if (widget.partialTollSkips.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.map_outlined, color: scheme.primary),
                      tooltip: l.tollSummaryMapButton,
                      onPressed: () => _openTollMap(context),
                    ),
                ],
              ),
            ),
            // Total pill
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.space20, vertical: Tokens.space8),
              child: Row(
                children: [
                  Text(
                    formatMoney(_effectiveTolls, widget.ccy),
                    style: t.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                  if (saved > 0.5) ...[
                    const SizedBox(width: Tokens.space8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '−${formatMoney(saved, widget.ccy)}',
                        style: t.labelMedium?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (widget.vignetteCostEur > 0)
                    Text(
                      AppLocalizations.of(context).vignetteInTotal(
                        formatMoney(widget.vignetteCostEur, widget.ccy),
                      ),
                      style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            Divider(color: scheme.outlineVariant),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: Tokens.space24),
                children: [
                  for (final (_, day, tolls) in buckets)
                    _DaySummarySection(
                      day: day,
                      tolls: tolls,
                      enabled: _enabled,
                      onToggle: _toggle,
                      etaHour: _etaHour,
                      bestHours: widget.hourlyReport?.bestHoursToSkip ?? const [],
                      worstHours: widget.hourlyReport?.worstHoursToSkip ?? const [],
                      ccy: widget.ccy,
                    ),
                  if (widget.vignetteCountries.isNotEmpty)
                    _VignetteSection(
                      countries: widget.vignetteCountries,
                      lines: widget.vignettes,
                      totalEur: widget.vignetteCostEur,
                      ccy: widget.ccy,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTollMap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _TollMapScreen(
          partialTollSkips: widget.partialTollSkips,
          enabled: _enabled,
          onToggle: _toggle,
          ccy: widget.ccy,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day section inside the sheet
// ---------------------------------------------------------------------------

class _DaySummarySection extends StatefulWidget {
  const _DaySummarySection({
    required this.day,
    required this.tolls,
    required this.enabled,
    required this.onToggle,
    required this.etaHour,
    required this.bestHours,
    required this.worstHours,
    required this.ccy,
  });

  final DayPlan day;
  final List<(int, PartialTollSkip)> tolls;
  final Set<int> enabled;
  final void Function(int, bool) onToggle;
  final int? Function(PartialTollSkip) etaHour;
  final List<int> bestHours;
  final List<int> worstHours;
  final String ccy;

  @override
  State<_DaySummarySection> createState() => _DaySummarySectionState();
}

class _DaySummarySectionState extends State<_DaySummarySection> {
  bool _open = true;

  double get _dayPaid {
    var total = 0.0;
    for (final (idx, s) in widget.tolls) {
      if (widget.enabled.contains(idx)) total += s.savingsEur;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final dayPaid = _dayPaid;
    final skippedCount = widget.tolls.where((e) => !widget.enabled.contains(e.$1)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.space16, vertical: Tokens.space12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${widget.day.dayIndex + 1}',
                      style: t.labelMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Tokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dayLabel(widget.day),
                        style: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (skippedCount > 0)
                        Text(
                          '$skippedCount peaje${skippedCount > 1 ? 's' : ''} omitido${skippedCount > 1 ? 's' : ''}',
                          style: t.labelSmall?.copyWith(
                            color: Colors.green.shade700,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  dayPaid > 0 ? formatMoney(dayPaid, widget.ccy) : '—',
                  style: t.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: skippedCount > 0 ? Colors.green.shade700 : null,
                  ),
                ),
                const SizedBox(width: Tokens.space4),
                Icon(
                  _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          for (final (idx, skip) in widget.tolls)
            _SlimTollRow(
              skipIndex: idx,
              skip: skip,
              paying: widget.enabled.contains(idx),
              onToggle: widget.onToggle,
              etaHour: widget.etaHour(skip),
              bestHours: widget.bestHours,
              worstHours: widget.worstHours,
              ccy: widget.ccy,
            ),
        ],
        Divider(color: Theme.of(context).colorScheme.outlineVariant, height: 1),
      ],
    );
  }

  String _dayLabel(DayPlan d) {
    final date = d.startAt.toLocal();
    const weekDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun',
                    'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final wd = weekDays[(date.weekday - 1) % 7];
    final mo = months[date.month - 1];
    final from = d.fromName ?? 'km ${d.fromKm.toStringAsFixed(0)}';
    final to = d.toName ?? 'km ${d.toKm.toStringAsFixed(0)}';
    return '$wd ${date.day} $mo  ·  $from → $to';
  }
}

// ---------------------------------------------------------------------------
// Slim toll row
// ---------------------------------------------------------------------------

class _SlimTollRow extends StatelessWidget {
  const _SlimTollRow({
    required this.skipIndex,
    required this.skip,
    required this.paying,
    required this.onToggle,
    required this.bestHours,
    required this.worstHours,
    required this.ccy,
    this.etaHour,
  });

  final int skipIndex;
  final PartialTollSkip skip;
  final bool paying;
  final void Function(int, bool) onToggle;
  final int? etaHour;
  final List<int> bestHours;
  final List<int> worstHours;
  final String ccy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    Color? verdictColor;
    if (etaHour != null) {
      if (bestHours.contains(etaHour)) verdictColor = Colors.green.shade700;
      if (worstHours.contains(etaHour)) verdictColor = Colors.orange.shade800;
    }

    return InkWell(
      onTap: () => onToggle(skipIndex, !paying),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        color: paying
            ? Colors.transparent
            : scheme.primaryContainer.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space20, vertical: Tokens.space12),
        child: Row(
          children: [
            Icon(
              paying ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 18,
              color: paying ? scheme.primary : scheme.outlineVariant,
            ),
            const SizedBox(width: Tokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skip.label.isEmpty
                        ? 'Peaje ${skipIndex + 1}'
                        : skip.label,
                    style: t.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: paying ? null : scheme.onSurfaceVariant,
                      decoration:
                          paying ? null : TextDecoration.lineThrough,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text.rich(
                    TextSpan(
                      style: t.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant),
                      children: [
                        TextSpan(
                          text: 'km ${skip.distanceFromOriginKm.toStringAsFixed(0)}',
                        ),
                        if (skip.timePenaltyMinutes > 0) ...[
                          const TextSpan(text: '  ·  '),
                          TextSpan(
                            text: '+${skip.timePenaltyMinutes.round()} min'
                                '  +${skip.extraDistanceKm.toStringAsFixed(1)} km',
                            style: t.labelSmall?.copyWith(
                              color: paying
                                  ? scheme.onSurfaceVariant
                                  : Colors.green.shade700,
                            ),
                          ),
                        ],
                        if (etaHour != null && verdictColor != null) ...[
                          const TextSpan(text: '  ·  '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Icon(Icons.schedule,
                                size: 11, color: verdictColor),
                          ),
                          TextSpan(
                            text: ' ${etaHour.toString().padLeft(2, '0')}h',
                            style: t.labelSmall?.copyWith(
                                color: verdictColor),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              paying
                  ? formatMoney(skip.savingsEur, ccy, decimals: 2)
                  : '−${formatMoney(skip.savingsEur, ccy, decimals: 2)}',
              style: t.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: paying ? null : Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vignette row
// ---------------------------------------------------------------------------

class _VignetteSection extends StatelessWidget {
  const _VignetteSection({
    required this.countries,
    required this.lines,
    required this.totalEur,
    required this.ccy,
  });

  final List<String> countries;
  final List<VignetteLine> lines;
  final double totalEur;
  final String ccy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    // An older server sends only the countries and the total: show the
    // countries, with the total once in the header.
    final perCountry = lines.isNotEmpty
        ? lines
        : [for (final c in countries) VignetteLine(country: c, costEur: 0)];
    final listed = lines.fold(0.0, (s, v) => s + v.costEur);
    final other = lines.isEmpty ? 0.0 : totalEur - listed;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space20, vertical: Tokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_play_outlined,
                  size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: Tokens.space12),
              Expanded(
                child: Text(
                  l.vignetteSectionTitle,
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                formatMoney(totalEur, ccy),
                style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space4),
          Text(
            l.vignetteSectionNote,
            style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          for (final v in perCountry) _VignetteCountryRow(line: v, ccy: ccy),
          if (other > 0.5)
            Padding(
              padding: const EdgeInsets.only(top: Tokens.space8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l.vignetteOther, style: t.bodyMedium),
                  ),
                  Text(formatMoney(other, ccy), style: t.labelLarge),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VignetteCountryRow extends StatelessWidget {
  const _VignetteCountryRow({required this.line, required this.ccy});

  final VignetteLine line;
  final String ccy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final info = vignetteInfoFor(line.country);
    final name = Country.fromCode(line.country).displayName;
    final muted = t.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (line.costEur > 0)
                Text(
                  formatMoney(line.costEur, ccy),
                  style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          if (info != null) ...[
            Text(
              info.sticker ? l.vignetteKindSticker : l.vignetteKindDigital,
              style: muted,
            ),
            Text(l.vignetteBuyBefore, style: muted),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: Text(l.vignetteBuyOfficial),
                onPressed: () => launchUrl(
                  Uri.parse(info.officialUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-screen map of toll booths
// ---------------------------------------------------------------------------

class _TollMapScreen extends StatefulWidget {
  const _TollMapScreen({
    required this.partialTollSkips,
    required this.enabled,
    required this.onToggle,
    required this.ccy,
  });

  final List<PartialTollSkip> partialTollSkips;
  final Set<int> enabled;
  final void Function(int, bool) onToggle;
  final String ccy;

  @override
  State<_TollMapScreen> createState() => _TollMapScreenState();
}

class _TollMapScreenState extends State<_TollMapScreen> {
  late Set<int> _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = Set.of(widget.enabled);
  }

  void _toggle(int idx) {
    final nowPaying = !_enabled.contains(idx);
    setState(() {
      if (nowPaying) {
        _enabled.add(idx);
      } else {
        _enabled.remove(idx);
      }
    });
    widget.onToggle(idx, nowPaying);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    // Compute map center from all booth coordinates.
    final points = [
      for (final s in widget.partialTollSkips)
        ll.LatLng(s.coordinate.lat, s.coordinate.lon),
    ];
    if (points.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Sin datos de peajes')),
      );
    }

    final centerLat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final centerLon =
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;

    var bounds = fmap.LatLngBounds.fromPoints(points);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Peajes del trayecto',
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          fmap.FlutterMap(
            options: fmap.MapOptions(
              initialCenter: ll.LatLng(centerLat, centerLon),
              initialCameraFit: fmap.CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.fromLTRB(40, 100, 40, 120),
                maxZoom: 13,
              ),
              interactionOptions: const fmap.InteractionOptions(
                flags: fmap.InteractiveFlag.all,
              ),
            ),
            children: [
              fmap.TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mytravelpal.travel',
              ),
              fmap.MarkerLayer(
                markers: [
                  for (var i = 0; i < widget.partialTollSkips.length; i++)
                    _buildMarker(context, i, widget.partialTollSkips[i], scheme),
                ],
              ),
            ],
          ),
          // Bottom legend / list
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.94),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(Tokens.radiusLg),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxHeight: 280),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        vertical: Tokens.space8),
                      itemCount: widget.partialTollSkips.length,
                      itemBuilder: (context, i) {
                        final skip = widget.partialTollSkips[i];
                        final paying = _enabled.contains(i);
                        return InkWell(
                          onTap: () => _toggle(i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Tokens.space16, vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: paying
                                        ? Colors.orange.shade700
                                        : Colors.grey.shade400,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: Tokens.space12),
                                Expanded(
                                  child: Text(
                                    skip.label.isEmpty
                                        ? 'Peaje ${i + 1}'
                                        : skip.label,
                                    style: t.bodySmall?.copyWith(
                                      color: paying
                                          ? null
                                          : scheme.onSurfaceVariant,
                                      decoration: paying
                                          ? null
                                          : TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                                Text(
                                  paying
                                      ? formatMoney(skip.savingsEur, widget.ccy, decimals: 2)
                                      : '—',
                                  style: t.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: paying
                                        ? null
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: Tokens.space4),
                                Icon(
                                  paying
                                      ? Icons.check_circle
                                      : Icons.remove_circle_outline,
                                  size: 16,
                                  color: paying
                                      ? Colors.orange.shade700
                                      : scheme.outlineVariant,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  fmap.Marker _buildMarker(
    BuildContext context,
    int idx,
    PartialTollSkip skip,
    ColorScheme scheme,
  ) {
    final paying = _enabled.contains(idx);
    return fmap.Marker(
      point: ll.LatLng(skip.coordinate.lat, skip.coordinate.lon),
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () => _toggle(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: paying
                ? Colors.orange.shade700
                : Colors.grey.shade400,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.toll,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
