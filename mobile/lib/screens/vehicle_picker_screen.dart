import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../domain/vehicle_model.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';

/// Sentinel returned by [VehiclePickerScreen] when the user chooses
/// "Custom vehicle". Callers that receive this value should show their
/// own form to collect tank size and consumption rather than resolving
/// the string against the catalogue.
const String kCustomVehicleId = '__custom__';

/// Full-screen model picker.
///
/// Fetches the catalogue via [vehicleCatalogueProvider] and renders it
/// grouped by make. A search box at the top narrows both makes and
/// models by substring match (case-insensitive). Tapping a model pops
/// the route with the [VehicleModel.id] as the result — callers should
/// treat a null pop as "cancel" and leave the current selection alone.
/// Tapping the "Custom vehicle" tile at the top pops [kCustomVehicleId].
class VehiclePickerScreen extends ConsumerStatefulWidget {
  const VehiclePickerScreen({super.key, this.currentId});

  /// Currently selected id (if any) so the row can be highlighted.
  final String? currentId;

  @override
  ConsumerState<VehiclePickerScreen> createState() =>
      _VehiclePickerScreenState();
}

class _VehiclePickerScreenState extends ConsumerState<VehiclePickerScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(vehicleCatalogueProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.profileVehicleModel),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.space16,
              vertical: Tokens.space12,
            ),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l.vehiclePickerSearchHint,
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: async.when(
              data: (models) => _buildList(theme, models),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(Tokens.space24),
                  child: Text(
                    l.vehiclePickerLoadError,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ThemeData theme, List<VehicleModel> models) {
    final l = AppLocalizations.of(context);
    final filtered = _query.isEmpty
        ? models
        : models.where((m) {
            final q = _query;
            return m.make.toLowerCase().contains(q) ||
                m.model.toLowerCase().contains(q);
          }).toList();

    // Group by make preserving catalogue insertion order.
    final byMake = <String, List<VehicleModel>>{};
    for (final m in filtered) {
      byMake.putIfAbsent(m.make, () => []).add(m);
    }
    final makes = byMake.keys.toList();

    // Custom vehicle tile is always shown at the top (regardless of query).
    final scheme = theme.colorScheme;
    final customTile = ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: Icon(Icons.tune, color: scheme.onSecondaryContainer),
      ),
      title: Text(
        l.vehiclePickerCustomOption,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(l.vehiclePickerCustomOptionSubtitle),
      selected: widget.currentId == kCustomVehicleId,
      trailing: widget.currentId == kCustomVehicleId
          ? const Icon(Icons.check)
          : const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).pop(kCustomVehicleId),
    );

    if (filtered.isEmpty) {
      return Column(
        children: [
          customTile,
          const Divider(),
          Expanded(
            child: Center(
              child: Text(
                l.vehiclePickerEmpty,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      itemCount: makes.length + 1, // +1 for the custom tile
      itemBuilder: (context, i) {
        if (i == 0) return customTile;
        final make = makes[i - 1];
        final variants = byMake[make]!;
        return ExpansionTile(
          initiallyExpanded: _query.isNotEmpty ||
              variants.any((v) => v.id == widget.currentId),
          title: Text(
            make,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text('${variants.length}'),
          children: [
            for (final m in variants)
              ListTile(
                selected: m.id == widget.currentId,
                title: Text(m.model),
                subtitle: Text(m.shortLabel),
                trailing: m.id == widget.currentId
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(m.id),
              ),
          ],
        );
      },
    );
  }
}
