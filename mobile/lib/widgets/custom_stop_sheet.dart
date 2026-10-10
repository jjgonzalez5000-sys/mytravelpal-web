import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../domain/my_place.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../screens/my_places_screen.dart' show showAddPlaceSheet;
import 'my_place_category.dart';

/// What the driver picked in [showCustomStopSheet].
class CustomStopChoice {
  const CustomStopChoice({
    required this.place,
    required this.visitMinutes,
    required this.plannedAt,
  });

  final MyPlace place;
  final int visitMinutes;

  /// Approximate local time at the stop; null when the trip has no day to
  /// place it in.
  final DateTime? plannedAt;
}

const List<int> kCustomStopDurations = [15, 30, 45, 60, 90];

/// Pick a stop of your own: one of the saved places, or a new one found by
/// search (which is saved too), then how long to stay and about when.
/// [suggestTime] proposes the time that best fits the day for a place and
/// visit length; the driver can change it.
Future<CustomStopChoice?> showCustomStopSheet(
  BuildContext context, {
  required DateTime? Function(MyPlace place, int visitMinutes) suggestTime,
}) {
  return showModalBottomSheet<CustomStopChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CustomStopSheet(suggestTime: suggestTime),
  );
}

class _CustomStopSheet extends ConsumerStatefulWidget {
  const _CustomStopSheet({required this.suggestTime});

  final DateTime? Function(MyPlace place, int visitMinutes) suggestTime;

  @override
  ConsumerState<_CustomStopSheet> createState() => _CustomStopSheetState();
}

class _CustomStopSheetState extends ConsumerState<_CustomStopSheet> {
  MyPlace? _place;
  int _minutes = 30;
  DateTime? _time;
  bool _timeEdited = false;

  void _select(MyPlace place) {
    setState(() {
      _place = place;
      _time = widget.suggestTime(place, _minutes);
      _timeEdited = false;
    });
  }

  void _setMinutes(int m) {
    setState(() {
      _minutes = m;
      // A new length can change which gap fits; keep a time the driver set.
      if (!_timeEdited && _place != null) {
        _time = widget.suggestTime(_place!, m);
      }
    });
  }

  Future<void> _pickTime() async {
    final t = _time;
    if (t == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: t.hour, minute: t.minute),
      helpText: AppLocalizations.of(context).stopPickTime,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _time = DateTime(t.year, t.month, t.day, picked.hour, picked.minute);
      _timeEdited = true;
    });
  }

  Future<void> _addNew() async {
    final place = await showAddPlaceSheet(context);
    if (place != null && mounted) _select(place);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final places = ref.watch(myPlacesProvider);
    final place = _place;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space16, 0, Tokens.space16, Tokens.space16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: place == null
              ? _chooser(l, scheme, t, places)
              : _details(l, scheme, t, place),
        ),
      ),
    );
  }

  Widget _chooser(
    AppLocalizations l,
    ColorScheme scheme,
    TextTheme t,
    List<MyPlace> places,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.stopAddCustom, style: t.titleMedium),
        const SizedBox(height: Tokens.space8),
        ListTile(
          leading: const Icon(Icons.search),
          title: Text(l.stopSearchPlace),
          trailing: const Icon(Icons.chevron_right),
          onTap: _addNew,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Tokens.space8),
          child: Text(
            l.stopFromMyPlaces,
            style: t.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        if (places.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Tokens.space12),
            child: Text(
              l.stopNoMyPlaces,
              style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final p in places)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                      child: Icon(myPlaceCategoryIcon(p.category), size: 18),
                    ),
                    title: Text(p.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(myPlaceCategoryLabel(l, p.category)),
                    onTap: () => _select(p),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _details(
    AppLocalizations l,
    ColorScheme scheme,
    TextTheme t,
    MyPlace place,
  ) {
    final time = _time;
    final label = time == null
        ? null
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay(hour: time.hour, minute: time.minute),
            alwaysUse24HourFormat: true,
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _place = null),
            ),
            Expanded(
              child: Text(place.name,
                  style: t.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: Tokens.space8),
        Text(l.stopVisitDuration,
            style: t.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: Tokens.space8),
        Wrap(
          spacing: Tokens.space8,
          children: [
            for (final m in kCustomStopDurations)
              ChoiceChip(
                label: Text(l.stopMinutes(m)),
                selected: _minutes == m,
                onSelected: (_) => _setMinutes(m),
              ),
          ],
        ),
        if (label != null) ...[
          const SizedBox(height: Tokens.space16),
          Text(l.stopPickTime,
              style: t.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: Tokens.space4),
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule),
            label: Text(l.stopAtTime(label)),
            onPressed: _pickTime,
          ),
        ],
        const SizedBox(height: Tokens.space16),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(CustomStopChoice(
            place: place,
            visitMinutes: _minutes,
            plannedAt: _time,
          )),
          child: Text(l.dayShiftApply),
        ),
      ],
    );
  }
}
