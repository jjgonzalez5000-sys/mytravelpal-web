import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../domain/garage_vehicle.dart';
import '../domain/trip_profile.dart' show FuelType;
import '../domain/vehicle_model.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'vehicle_picker_screen.dart';

/// The user's garage: every saved vehicle, add / edit / delete.
///
/// Reached from the Settings screen. When the garage is empty, the
/// screen shows a friendly empty state; the FAB always opens the
/// catalogue picker first (`VehicleModelPickerScreen`), then a
/// small sheet asking for the friendly name + starting tank level
/// before the entry is persisted.
class GarageScreen extends ConsumerStatefulWidget {
  const GarageScreen({super.key});

  @override
  ConsumerState<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends ConsumerState<GarageScreen> {
  @override
  void initState() {
    super.initState();
    // Cold-start / re-entry refresh — cheap single GET.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(garageProvider.notifier).ensureLoaded();
    });
  }

  Future<void> _addFlow() async {
    final l = AppLocalizations.of(context);
    // 1) Catalogue picker → returns a model_id.
    final modelId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const VehiclePickerScreen(),
      ),
    );
    if (modelId == null || modelId.isEmpty) return;
    if (!mounted) return;
    // 2) Ask for friendly name + tank level via a bottom sheet.
    final draft = await _promptForNameAndTank(
      context: context,
      defaultName: _defaultNameFor(modelId, l),
      initialTankPercent: 100,
    );
    if (draft == null) return;
    final added = await ref.read(garageProvider.notifier).add(
          name: draft.name,
          modelId: modelId,
          defaultTankPercent: draft.tankPercent,
        );
    if (!mounted) return;
    if (added == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.garageAddError)),
      );
    }
  }

  Future<void> _editFlow(GarageVehicle v) async {
    final l = AppLocalizations.of(context);
    final draft = await _promptForNameAndTank(
      context: context,
      defaultName: v.name,
      initialTankPercent: v.defaultTankPercent,
      isEdit: true,
    );
    if (draft == null) return;
    final ok = await ref.read(garageProvider.notifier).update(
          id: v.id,
          name: draft.name,
          defaultTankPercent: draft.tankPercent,
        );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.garageAddError)),
      );
    }
  }

  Future<void> _confirmDelete(GarageVehicle v) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(l.garageDeleteTitle),
        content: Text(l.garageDeleteBody(v.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: Text(l.garageCancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: Text(l.garageDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(garageProvider.notifier).remove(v.id);
    // If the deleted vehicle was the per-trip selection, clear it.
    final selected = ref.read(selectedGarageVehicleIdProvider);
    if (selected == v.id) {
      ref.read(selectedGarageVehicleIdProvider.notifier).state = null;
    }
  }

  String _defaultNameFor(String modelId, AppLocalizations l) {
    final async = ref.read(vehicleCatalogueProvider);
    final m = async.valueOrNull?.firstWhere(
      (v) => v.id == modelId,
      orElse: () => VehicleModel(
        id: modelId,
        make: '',
        model: modelId,
        yearFrom: 0,
        yearTo: null,
        fuelType: FuelType.petrol,
        tankLiters: 0,
        consumptionL100km: 0,
      ),
    );
    if (m == null || m.model.isEmpty) return l.garageDefaultName;
    return m.model;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final garage = ref.watch(garageProvider);
    final catalogueAsync = ref.watch(vehicleCatalogueProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.garageTitle)),
      body: garage.isEmpty
          ? _EmptyGarage(onAdd: _addFlow)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(
                vertical: Tokens.space8,
                horizontal: Tokens.space8,
              ),
              itemCount: garage.length,
              itemBuilder: (context, i) {
                final v = garage[i];
                VehicleModel? model;
                if (catalogueAsync.hasValue) {
                  final list = catalogueAsync.value!;
                  final match = list.where((m) => m.id == v.modelId);
                  model = match.isEmpty ? null : match.first;
                }
                return _GarageRow(
                  vehicle: v,
                  model: model,
                  onTap: () => _editFlow(v),
                  onDelete: () => _confirmDelete(v),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFlow,
        icon: const Icon(Icons.add),
        label: Text(l.garageAdd),
      ),
    );
  }
}

class _EmptyGarage extends StatelessWidget {
  const _EmptyGarage({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.garage_outlined,
              size: 72,
              color: scheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: Tokens.space16),
            Text(
              l.garageEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: Tokens.space16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(l.garageAdd),
            ),
          ],
        ),
      ),
    );
  }
}

class _GarageRow extends StatelessWidget {
  const _GarageRow({
    required this.vehicle,
    required this.model,
    required this.onTap,
    required this.onDelete,
  });

  final GarageVehicle vehicle;
  final VehicleModel? model;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final subtitle = model == null
        ? vehicle.modelId
        : '${model!.make} ${model!.model} · ${vehicle.defaultTankPercent} %';
    return Dismissible(
      key: ValueKey('garage-${vehicle.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        // Returning false keeps the row in place; the actual delete
        // ripples through the provider and rebuilds the list.
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.space24),
        color: scheme.errorContainer,
        child: Icon(Icons.delete, color: scheme.onErrorContainer),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(
          horizontal: Tokens.space8,
          vertical: Tokens.space4,
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            child: Icon(
              Icons.directions_car,
              color: scheme.onPrimaryContainer,
            ),
          ),
          title: Text(vehicle.name, style: t.titleMedium),
          subtitle: Text(subtitle, style: t.bodySmall),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _GarageDraft {
  const _GarageDraft({required this.name, required this.tankPercent});
  final String name;
  final int tankPercent;
}

Future<_GarageDraft?> _promptForNameAndTank({
  required BuildContext context,
  required String defaultName,
  required int initialTankPercent,
  bool isEdit = false,
}) async {
  final l = AppLocalizations.of(context);
  final controller = TextEditingController(text: defaultName);
  var tank = initialTankPercent;
  const notches = <int>[25, 50, 75, 100];
  return showModalBottomSheet<_GarageDraft>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
      ),
      child: StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: const EdgeInsets.all(Tokens.space16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? l.garageEdit : l.garageAdd,
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: Tokens.space16),
              TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l.garageNameHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Tokens.space16),
              Text(l.garageDefaultTankLabel),
              const SizedBox(height: Tokens.space8),
              Wrap(
                spacing: Tokens.space8,
                children: [
                  for (final n in notches)
                    ChoiceChip(
                      label: Text('$n %'),
                      selected: tank == n,
                      onSelected: (yes) {
                        if (yes) setState(() => tank = n);
                      },
                    ),
                ],
              ),
              const SizedBox(height: Tokens.space16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    child: Text(l.garageCancel),
                  ),
                  const SizedBox(width: Tokens.space8),
                  FilledButton(
                    onPressed: () {
                      final name = controller.text.trim();
                      if (name.isEmpty) return;
                      Navigator.of(sheetCtx).pop(
                        _GarageDraft(name: name, tankPercent: tank),
                      );
                    },
                    child: Text(l.garageSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
