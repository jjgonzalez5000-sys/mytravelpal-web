import 'dart:convert';

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

    if (modelId == kCustomVehicleId) {
      // Custom vehicle: ask for name, fuel type, tank, and consumption.
      final custom = await _promptForCustomGarage(context: context, l: l);
      if (custom == null || !mounted) return;
      final notes = jsonEncode({
        't': custom.tankL,
        'c': custom.consumptionL100km,
        'f': custom.fuelType.name,
      });
      final added = await ref.read(garageProvider.notifier).add(
            name: custom.name,
            modelId: kCustomVehicleId,
            defaultTankPercent: custom.tankPercent,
            notes: notes,
          );
      if (!mounted) return;
      if (added == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.garageAddError)));
      }
      return;
    }

    // 2) Standard model: ask for friendly name + tank level.
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
    if (modelId == kCustomVehicleId) return l.vehicleCustomTitle;
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
    final String subtitle;
    if (vehicle.modelId == kCustomVehicleId) {
      final specs = _parseCustomNotes(vehicle.notes);
      if (specs != null) {
        final unit = specs.fuelType == FuelType.electric ? 'kWh' : 'L';
        subtitle = '${specs.tankL.toStringAsFixed(0)} $unit · '
            '${specs.consumptionL100km.toStringAsFixed(1)} $unit/100km · '
            '${vehicle.defaultTankPercent} %';
      } else {
        subtitle = '${vehicle.defaultTankPercent} %';
      }
    } else if (model == null) {
      subtitle = '${vehicle.defaultTankPercent} %';
    } else {
      subtitle = '${model!.make} ${model!.model} · ${vehicle.defaultTankPercent} %';
    }
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

class _GarageCustomDraft {
  const _GarageCustomDraft({
    required this.name,
    required this.tankPercent,
    required this.fuelType,
    required this.tankL,
    required this.consumptionL100km,
  });
  final String name;
  final int tankPercent;
  final FuelType fuelType;
  final double tankL;
  final double consumptionL100km;
}

/// Decode custom vehicle specs from the notes JSON stored on the backend.
_GarageCustomDraft? _parseCustomNotes(String? notes) {
  if (notes == null) return null;
  try {
    final m = jsonDecode(notes) as Map<String, dynamic>;
    final fuelName = m['f'] as String? ?? 'petrol';
    final ft = FuelType.values.firstWhere(
      (e) => e.name == fuelName,
      orElse: () => FuelType.petrol,
    );
    return _GarageCustomDraft(
      name: '',
      tankPercent: 100,
      fuelType: ft,
      tankL: (m['t'] as num?)?.toDouble() ?? 55.0,
      consumptionL100km: (m['c'] as num?)?.toDouble() ?? 7.5,
    );
  } catch (_) {
    return null;
  }
}

String _fuelTypeLabelGarage(FuelType ft, AppLocalizations l) {
  switch (ft) {
    case FuelType.petrol:
      return l.fuelTypePetrol;
    case FuelType.diesel:
      return l.fuelTypeDiesel;
    case FuelType.electric:
      return l.fuelTypeElectric;
    case FuelType.hybrid:
      return l.fuelTypeHybrid;
    case FuelType.lpg:
      return l.fuelTypeLpg;
  }
}

Future<_GarageCustomDraft?> _promptForCustomGarage({
  required BuildContext context,
  required AppLocalizations l,
}) async {
  final nameCtrl = TextEditingController(text: l.vehicleCustomTitle);
  final tankCtrl = TextEditingController(text: '55');
  final consCtrl = TextEditingController(text: '7.5');
  final formKey = GlobalKey<FormState>();
  FuelType selectedFuelType = FuelType.petrol;
  int tank = 100;
  const notches = <int>[25, 50, 75, 100];

  return showModalBottomSheet<_GarageCustomDraft>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.space16, Tokens.space20, Tokens.space16, Tokens.space16,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.vehicleCustomTitle,
                      style: Theme.of(sheetCtx).textTheme.titleLarge),
                  const SizedBox(height: Tokens.space16),
                  TextFormField(
                    controller: nameCtrl,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l.garageNameHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '!' : null,
                  ),
                  const SizedBox(height: Tokens.space16),
                  Text(l.profileFuelType,
                      style: Theme.of(sheetCtx).textTheme.labelMedium),
                  const SizedBox(height: Tokens.space8),
                  Wrap(
                    spacing: Tokens.space8,
                    runSpacing: Tokens.space4,
                    children: [
                      for (final ft in FuelType.values)
                        ChoiceChip(
                          label: Text(_fuelTypeLabelGarage(ft, l)),
                          selected: selectedFuelType == ft,
                          onSelected: (_) =>
                              setState(() => selectedFuelType = ft),
                        ),
                    ],
                  ),
                  const SizedBox(height: Tokens.space16),
                  TextFormField(
                    controller: tankCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: false),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: selectedFuelType == FuelType.electric
                          ? l.vehicleCustomTankEv
                          : l.vehicleCustomTank,
                      border: const OutlineInputBorder(),
                      suffixText: selectedFuelType == FuelType.electric
                          ? 'kWh'
                          : 'L',
                      isDense: true,
                    ),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n < 1 || n > 300) return '1 – 300';
                      return null;
                    },
                  ),
                  const SizedBox(height: Tokens.space12),
                  TextFormField(
                    controller: consCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: selectedFuelType == FuelType.electric
                          ? l.vehicleCustomConsumptionEv
                          : l.vehicleCustomConsumption,
                      border: const OutlineInputBorder(),
                      suffixText: selectedFuelType == FuelType.electric
                          ? 'kWh/100km'
                          : 'L/100km',
                      isDense: true,
                    ),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n < 0.5 || n > 50) return '0.5 – 50';
                      return null;
                    },
                  ),
                  const SizedBox(height: Tokens.space16),
                  Text(
                      selectedFuelType == FuelType.electric
                          ? l.garageDefaultChargeLevelLabel
                          : l.garageDefaultTankLabel,
                      style: Theme.of(sheetCtx).textTheme.labelMedium),
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
                          if (!formKey.currentState!.validate()) return;
                          Navigator.of(sheetCtx).pop(
                            _GarageCustomDraft(
                              name: nameCtrl.text.trim(),
                              tankPercent: tank,
                              fuelType: selectedFuelType,
                              tankL: double.parse(tankCtrl.text.trim()),
                              consumptionL100km:
                                  double.parse(consCtrl.text.trim()),
                            ),
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
      ),
    ),
  );
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
