import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';
import '../domain/trip_profile.dart' show FuelType;
import '../domain/vehicle_kind.dart';
import '../l10n/app_localizations.dart';
import 'vehicle_picker_screen.dart';

/// What the wizard hands back: everything the garage needs to save a vehicle.
class NewVehicleDraft {
  const NewVehicleDraft({
    required this.name,
    required this.modelId,
    required this.tankPercent,
    required this.notes,
  });

  final String name;

  /// A catalogue id, or [kCustomVehicleId] when the driver typed the specs.
  final String modelId;
  final int tankPercent;

  /// [VehicleSpecs] as JSON (type, fuel, tank, consumption, measures).
  final String notes;
}

enum _Step { type, how, specs, dims, name }

class _Defaults {
  const _Defaults({
    required this.fuel,
    required this.tank,
    required this.consumption,
    this.height = 0,
    this.length = 0,
    this.weight = 0,
    this.axles = 2,
  });

  final FuelType fuel;
  final double tank;
  final double consumption;
  final double height;
  final double length;
  final double weight;
  final int axles;
}

const Map<VehicleKind, _Defaults> _defaults = {
  VehicleKind.car:
      _Defaults(fuel: FuelType.petrol, tank: 55, consumption: 7.5),
  VehicleKind.motorbike:
      _Defaults(fuel: FuelType.petrol, tank: 14, consumption: 5),
  VehicleKind.van: _Defaults(
    fuel: FuelType.diesel, tank: 70, consumption: 10,
    height: 2.4, length: 5.5, weight: 3.5,
  ),
  VehicleKind.camper: _Defaults(
    fuel: FuelType.diesel, tank: 90, consumption: 12,
    height: 3.1, length: 7, weight: 3.5,
  ),
  VehicleKind.truck: _Defaults(
    fuel: FuelType.diesel, tank: 400, consumption: 30,
    height: 3.8, length: 12, weight: 18, axles: 2,
  ),
};

/// Starting battery (kWh) and consumption (kWh/100 km) per kind.
const Map<VehicleKind, (double, double)> _evDefaults = {
  VehicleKind.car: (60, 16),
  VehicleKind.motorbike: (8, 8),
  VehicleKind.van: (75, 25),
  VehicleKind.camper: (100, 35),
  VehicleKind.truck: (300, 110),
};

/// Add-a-vehicle wizard: first the type, then only the steps that type needs
/// (a car can come from the catalogue; vans, campers and trucks also ask for
/// height, length and weight; a truck for its axles).
///
/// Pops with a [NewVehicleDraft], or null when the driver backs out.
class AddVehicleWizardScreen extends StatefulWidget {
  const AddVehicleWizardScreen({super.key, required this.defaultNameFor});

  /// Name to propose for a catalogue model id (null for a typed-in vehicle).
  final String Function(String? modelId) defaultNameFor;

  @override
  State<AddVehicleWizardScreen> createState() => _AddVehicleWizardScreenState();
}

class _AddVehicleWizardScreenState extends State<AddVehicleWizardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tank = TextEditingController();
  final _consumption = TextEditingController();
  final _height = TextEditingController();
  final _length = TextEditingController();
  final _weight = TextEditingController();
  final _name = TextEditingController();

  VehicleKind? _kind;
  bool _nameTouched = false;
  bool _useCatalogue = true;
  String? _catalogueId;
  FuelType _fuel = FuelType.petrol;
  int _axles = 2;
  int _tankPercent = 100;
  int _index = 0;

  @override
  void dispose() {
    for (final c in [_tank, _consumption, _height, _length, _weight, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  List<_Step> get _steps {
    final k = _kind;
    if (k == null) return const [_Step.type];
    return [
      _Step.type,
      if (k.hasCatalogue) _Step.how,
      if (!k.hasCatalogue || !_useCatalogue) _Step.specs,
      if (k.needsDimensions) _Step.dims,
      _Step.name,
    ];
  }

  bool get _isElectric => _fuel == FuelType.electric;

  void _selectKind(VehicleKind k) {
    final d = _defaults[k]!;
    setState(() {
      _kind = k;
      _useCatalogue = k.hasCatalogue;
      _catalogueId = null;
      _fuel = d.fuel;
      _axles = d.axles;
      _tank.text = _fmt(d.tank);
      _consumption.text = _fmt(d.consumption);
      _height.text = d.height > 0 ? _fmt(d.height) : '';
      _length.text = d.length > 0 ? _fmt(d.length) : '';
      _weight.text = d.weight > 0 ? _fmt(d.weight) : '';
    });
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  void _back() {
    if (_index > 0) {
      setState(() => _index--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _next() async {
    final step = _steps[_index];
    if (step == _Step.type && _kind == null) return;

    if (step == _Step.how && _useCatalogue) {
      final id = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => VehiclePickerScreen(currentId: _catalogueId),
        ),
      );
      if (!mounted || id == null) return;
      if (id == kCustomVehicleId) {
        // "Custom vehicle" inside the picker: carry on with typed-in specs.
        setState(() {
          _useCatalogue = false;
          _catalogueId = null;
          _index++;
        });
        return;
      }
      setState(() {
        _catalogueId = id;
        _index++;
      });
      _proposeName();
      return;
    }

    if (!(_formKey.currentState?.validate() ?? true)) return;

    if (_index < _steps.length - 1) {
      setState(() => _index++);
      if (_steps[_index] == _Step.name) _proposeName();
    } else {
      _finish();
    }
  }

  /// Offer a name for what was chosen, unless the driver already typed one:
  /// going back and picking another vehicle must not keep the old proposal.
  void _proposeName() {
    if (!_nameTouched) {
      _name.text = widget.defaultNameFor(_catalogueId);
    }
  }

  /// Fuel chosen. Moving between a combustion fuel and electricity swaps the
  /// preset tank and consumption too: litres and L/100 km would otherwise
  /// pass as kWh and kWh/100 km and give an absurd range.
  void _selectFuel(FuelType f) {
    final wasElectric = _isElectric;
    setState(() {
      _fuel = f;
      if ((f == FuelType.electric) != wasElectric) {
        final k = _kind ?? VehicleKind.car;
        if (f == FuelType.electric) {
          final e = _evDefaults[k]!;
          _tank.text = _fmt(e.$1);
          _consumption.text = _fmt(e.$2);
        } else {
          final d = _defaults[k]!;
          _tank.text = _fmt(d.tank);
          _consumption.text = _fmt(d.consumption);
        }
      }
    });
  }

  void _finish() {
    final k = _kind!;
    final fromCatalogue = k.hasCatalogue && _useCatalogue && _catalogueId != null;
    double parse(TextEditingController c) =>
        double.parse(c.text.trim().replaceAll(',', '.'));
    final specs = fromCatalogue
        ? VehicleSpecs(kind: k)
        : VehicleSpecs(
            kind: k,
            fuelType: _fuel,
            tankL: parse(_tank),
            consumptionL100km: parse(_consumption),
            heightM: k.needsDimensions ? parse(_height) : null,
            lengthM: k.needsDimensions ? parse(_length) : null,
            weightT: k.needsDimensions ? parse(_weight) : null,
            axles: k == VehicleKind.truck ? _axles : null,
          );
    final typed = _name.text.trim();
    Navigator.of(context).pop(
      NewVehicleDraft(
        name: typed.isEmpty
            ? widget.defaultNameFor(fromCatalogue ? _catalogueId : null)
            : typed,
        modelId: fromCatalogue ? _catalogueId! : kCustomVehicleId,
        tankPercent: _tankPercent,
        notes: specs.toNotes(),
      ),
    );
  }

  // ---- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final steps = _steps;
    final step = steps[_index];
    final isLast = _index == steps.length - 1;
    final needsKind = step == _Step.type && _kind == null;

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.garageAdd),
          leading: BackButton(onPressed: _back),
        ),
        body: Column(
          children: [
            LinearProgressIndicator(value: (_index + 1) / steps.length),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space16, Tokens.space12, Tokens.space16, 0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l.vehicleWizardStepOf(_index + 1, steps.length),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Tokens.space16),
                child: Form(key: _formKey, child: _stepBody(step, l)),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Tokens.space16, Tokens.space8, Tokens.space16, Tokens.space12,
                ),
                child: Row(
                  children: [
                    if (_index > 0)
                      TextButton(
                        onPressed: _back,
                        child: Text(l.vehicleWizardBack),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: needsKind ? null : _next,
                      child: Text(isLast ? l.garageSave : l.vehicleWizardNext),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBody(_Step step, AppLocalizations l) {
    switch (step) {
      case _Step.type:
        return _typeStep(l);
      case _Step.how:
        return _howStep(l);
      case _Step.specs:
        return _specsStep(l);
      case _Step.dims:
        return _dimsStep(l);
      case _Step.name:
        return _nameStep(l);
    }
  }

  String _kindLabel(VehicleKind k, AppLocalizations l) => switch (k) {
        VehicleKind.car => l.vehicleTypeCar,
        VehicleKind.motorbike => l.vehicleTypeMotorbike,
        VehicleKind.van => l.vehicleTypeVan,
        VehicleKind.camper => l.vehicleTypeCamper,
        VehicleKind.truck => l.vehicleTypeTruck,
      };

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: Tokens.space16),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );

  Widget _typeStep(AppLocalizations l) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(l.vehicleWizardTypeTitle),
        Wrap(
          spacing: Tokens.space12,
          runSpacing: Tokens.space12,
          children: [
            for (final k in VehicleKind.values)
              SizedBox(
                width: 150,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  color: _kind == k ? scheme.primaryContainer : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Tokens.radiusMd),
                    side: BorderSide(
                      color: _kind == k ? scheme.primary : scheme.outlineVariant,
                      width: _kind == k ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    key: ValueKey('vehicle-kind-${k.code}'),
                    onTap: () => _selectKind(k),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: Tokens.space16, horizontal: Tokens.space8,
                      ),
                      child: Column(
                        children: [
                          Icon(k.icon, size: 32, color: scheme.primary),
                          const SizedBox(height: Tokens.space8),
                          Text(
                            _kindLabel(k, l),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _howStep(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(l.vehicleWizardHowTitle),
        // ignore: deprecated_member_use
        RadioListTile<bool>(
          key: const ValueKey('vehicle-how-catalogue'),
          value: true,
          groupValue: _useCatalogue,
          onChanged: (v) => setState(() => _useCatalogue = v ?? true),
          title: Text(l.vehicleWizardHowSearch),
          subtitle: Text(l.vehicleWizardHowSearchSub),
        ),
        // ignore: deprecated_member_use
        RadioListTile<bool>(
          key: const ValueKey('vehicle-how-manual'),
          value: false,
          groupValue: _useCatalogue,
          onChanged: (v) => setState(() => _useCatalogue = v ?? false),
          title: Text(l.vehiclePickerCustomOption),
          subtitle: Text(l.vehiclePickerCustomOptionSubtitle),
        ),
      ],
    );
  }

  String? _range(String? v, double min, double max, AppLocalizations l) {
    final n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
    if (n == null || n < min || n > max) {
      return l.vehicleWizardRange(_fmt(min), _fmt(max));
    }
    return null;
  }

  String _fuelLabel(FuelType f, AppLocalizations l) => switch (f) {
        FuelType.petrol => l.fuelTypePetrol,
        FuelType.diesel => l.fuelTypeDiesel,
        FuelType.hybrid => l.fuelTypeHybrid,
        FuelType.electric => l.fuelTypeElectric,
        FuelType.lpg => l.fuelTypeLpg,
        FuelType.e85 => l.fuelTypeE85,
      };

  Widget _specsStep(AppLocalizations l) {
    final big = _kind == VehicleKind.truck;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(l.vehicleWizardSpecsTitle),
        Text(l.profileFuelType, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: Tokens.space8),
        Wrap(
          spacing: Tokens.space8,
          runSpacing: Tokens.space4,
          children: [
            for (final f in FuelType.values)
              ChoiceChip(
                label: Text(_fuelLabel(f, l)),
                selected: _fuel == f,
                onSelected: (_) => _selectFuel(f),
              ),
          ],
        ),
        const SizedBox(height: Tokens.space16),
        TextFormField(
          controller: _tank,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: InputDecoration(
            labelText: _isElectric ? l.vehicleCustomTankEv : l.vehicleCustomTank,
            suffixText: _isElectric ? 'kWh' : 'L',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          validator: (v) => _range(
            v, 1, big && !_isElectric ? 1000 : (_isElectric ? 800 : 300), l,
          ),
        ),
        const SizedBox(height: Tokens.space12),
        TextFormField(
          controller: _consumption,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: InputDecoration(
            labelText: _isElectric
                ? l.vehicleCustomConsumptionEv
                : l.vehicleCustomConsumption,
            suffixText: _isElectric ? 'kWh/100km' : 'L/100km',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          validator: (v) => _range(
            v, 0.5, _isElectric ? (big ? 150 : 50) : (big ? 80 : 50), l,
          ),
        ),
      ],
    );
  }

  Widget _dimsStep(AppLocalizations l) {
    final truck = _kind == VehicleKind.truck;
    final scheme = Theme.of(context).colorScheme;
    Widget field(
      TextEditingController c,
      String label,
      String suffix,
      double min,
      double max,
    ) =>
        Padding(
          padding: const EdgeInsets.only(bottom: Tokens.space12),
          child: TextFormField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: label,
              suffixText: suffix,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            validator: (v) => _range(v, min, max, l),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(l.vehicleWizardDimsTitle),
        field(_height, l.vehicleWizardHeight, 'm', 1.5, 4.5),
        field(_length, l.vehicleWizardLength, 'm', 3, 25),
        field(_weight, l.vehicleWizardWeight, 't', 1, 44),
        if (truck) ...[
          Text(l.vehicleWizardAxles,
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: Tokens.space8),
          Wrap(
            spacing: Tokens.space8,
            children: [
              for (final a in const [2, 3, 4, 5, 6])
                ChoiceChip(
                  label: Text('$a'),
                  selected: _axles == a,
                  onSelected: (_) => setState(() => _axles = a),
                ),
            ],
          ),
          const SizedBox(height: Tokens.space16),
          Container(
            padding: const EdgeInsets.all(Tokens.space12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: scheme.primary),
                const SizedBox(width: Tokens.space8),
                Expanded(
                  child: Text(
                    l.vehicleWizardTruckNote,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _nameStep(AppLocalizations l) {
    const notches = <int>[25, 50, 75, 100];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(l.vehicleWizardNameTitle),
        TextFormField(
          controller: _name,
          textInputAction: TextInputAction.done,
          // The server refuses names over 64 characters, after the wizard
          // has closed; stop the typing instead.
          maxLength: 64,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
              null,
          onChanged: (_) => _nameTouched = true,
          decoration: InputDecoration(
            labelText: l.garageNameHint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: Tokens.space16),
        Text(
          _isElectric && !(_kind?.hasCatalogue == true && _useCatalogue)
              ? l.garageDefaultChargeLevelLabel
              : l.garageDefaultTankLabel,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: Tokens.space8),
        Wrap(
          spacing: Tokens.space8,
          children: [
            for (final n in notches)
              ChoiceChip(
                label: Text('$n %'),
                selected: _tankPercent == n,
                onSelected: (yes) {
                  if (yes) setState(() => _tankPercent = n);
                },
              ),
          ],
        ),
      ],
    );
  }
}
