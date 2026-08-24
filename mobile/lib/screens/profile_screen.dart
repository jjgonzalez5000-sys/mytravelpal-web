import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/components.dart';
import '../design/tokens.dart';
import '../domain/trip_profile.dart';
import '../providers.dart';

/// Single-form profile editor. Users set this once; the plan screen
/// then shows a compact chip and applies the profile silently to every
/// plan request. Structured as clearly-titled sections so it doesn't
/// look overwhelming — travellers first (least intimidating), vehicle,
/// then meal times last (most granular).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TripProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = ref.read(tripProfileProvider) ?? const TripProfile();
  }

  Future<void> _save() async {
    await ref.read(tripProfileProvider.notifier).set(_profile);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final v = _profile.vehicle;
    final isEv = v.fuelType == FuelType.electric;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip profile'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
          const SizedBox(width: Tokens.space8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.space20),
        children: [
          Text(
            'Set this once. Every plan uses it to rank hotels and '
            'restaurants, estimate fuel cost, and suggest meal stops.',
            style: t.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Tokens.space24),

          const SectionHeader(
            title: 'Who is travelling',
            eyebrow: 'People',
          ),
          SoftCard(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.space16, vertical: Tokens.space4,
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Travellers'),
                  trailing: _Stepper(
                    value: _profile.travellers,
                    min: 1, max: 9,
                    onChanged: (n) => setState(
                      () => _profile = _profile.copyWith(travellers: n),
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Travelling with kids'),
                  subtitle: const Text(
                    'Prefers kid-friendly restaurants and hotels.',
                  ),
                  value: _profile.hasKids,
                  onChanged: (v) => setState(
                    () => _profile = _profile.copyWith(hasKids: v),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Travelling with pets'),
                  subtitle: const Text(
                    'Prefers pet-friendly places, prioritises parking.',
                  ),
                  value: _profile.hasPets,
                  onChanged: (v) => setState(
                    () => _profile = _profile.copyWith(hasPets: v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space24),

          const SectionHeader(
            title: 'Vehicle',
            eyebrow: 'For cost + parking hints',
          ),
          SoftCard(
            padding: const EdgeInsets.all(Tokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabeledChoice<VehicleType>(
                  label: 'Type',
                  value: v.type,
                  options: VehicleType.values,
                  optionLabel: (t) => t.label,
                  optionIcon: (t) => t.icon,
                  onChanged: (t) => setState(
                    () => _profile = _profile.copyWith(
                      vehicle: v.copyWith(type: t),
                    ),
                  ),
                ),
                const SizedBox(height: Tokens.space16),
                _LabeledChoice<FuelType>(
                  label: 'Fuel',
                  value: v.fuelType,
                  options: FuelType.values,
                  optionLabel: (f) => f.label,
                  onChanged: (f) => setState(
                    () => _profile = _profile.copyWith(
                      vehicle: v.copyWith(fuelType: f),
                    ),
                  ),
                ),
                const SizedBox(height: Tokens.space16),
                if (isEv) ...[
                  _LabeledSlider(
                    label: 'Consumption',
                    suffix: 'kWh / 100 km',
                    value: v.consumptionKwhPer100km,
                    min: 8, max: 40, divisions: 32,
                    onChanged: (x) => setState(
                      () => _profile = _profile.copyWith(
                        vehicle: v.copyWith(consumptionKwhPer100km: x),
                      ),
                    ),
                  ),
                  const SizedBox(height: Tokens.space16),
                  _LabeledSlider(
                    label: 'EV range on one charge',
                    suffix: 'km',
                    value: v.evRangeKm,
                    min: 100, max: 800, divisions: 70,
                    onChanged: (x) => setState(
                      () => _profile = _profile.copyWith(
                        vehicle: v.copyWith(evRangeKm: x),
                      ),
                    ),
                  ),
                ] else ...[
                  _LabeledSlider(
                    label: 'Consumption',
                    suffix: 'L / 100 km',
                    value: v.consumptionLPer100km,
                    min: 2, max: 20, divisions: 36,
                    onChanged: (x) => setState(
                      () => _profile = _profile.copyWith(
                        vehicle: v.copyWith(consumptionLPer100km: x),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Tokens.space24),

          const SectionHeader(
            title: 'Meal times',
            eyebrow: 'To match restaurant stops',
          ),
          SoftCard(
            padding: const EdgeInsets.all(Tokens.space16),
            child: Column(
              children: [
                _HourPicker(
                  label: 'Breakfast',
                  value: _profile.meals.breakfastHour,
                  min: 4, max: 12,
                  onChanged: (h) => setState(
                    () => _profile = _profile.copyWith(
                      meals: _profile.meals.copyWith(breakfastHour: h),
                    ),
                  ),
                ),
                _HourPicker(
                  label: 'Lunch',
                  value: _profile.meals.lunchHour,
                  min: 11, max: 16,
                  onChanged: (h) => setState(
                    () => _profile = _profile.copyWith(
                      meals: _profile.meals.copyWith(lunchHour: h),
                    ),
                  ),
                ),
                _HourPicker(
                  label: 'Dinner',
                  value: _profile.meals.dinnerHour,
                  min: 17, max: 23,
                  onChanged: (h) => setState(
                    () => _profile = _profile.copyWith(
                      meals: _profile.meals.copyWith(dinnerHour: h),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space32),
          if (ref.watch(tripProfileProvider) != null)
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear profile'),
              onPressed: () async {
                await ref.read(tripProfileProvider.notifier).clear();
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 24,
          child: Text('$value', textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _LabeledChoice<T> extends StatelessWidget {
  const _LabeledChoice({
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    this.optionIcon,
  });
  final String label;
  final T value;
  final List<T> options;
  final String Function(T) optionLabel;
  final IconData Function(T)? optionIcon;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.labelMedium),
        const SizedBox(height: Tokens.space8),
        Wrap(
          spacing: Tokens.space8,
          runSpacing: Tokens.space8,
          children: [
            for (final o in options)
              ChoiceChip(
                selected: o == value,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (optionIcon != null) ...[
                      Icon(optionIcon!(o), size: 14),
                      const SizedBox(width: 4),
                    ],
                    Text(optionLabel(o)),
                  ],
                ),
                onSelected: (s) {
                  if (s) onChanged(o);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.suffix,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
  final String label;
  final String suffix;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: t.labelMedium)),
            Text('${value.toStringAsFixed(1)} $suffix',
                style: t.labelMedium),
          ],
        ),
        Slider(
          value: value,
          min: min, max: max, divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _HourPicker extends StatelessWidget {
  const _HourPicker({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: _Stepper(
        value: value, min: min, max: max, onChanged: onChanged,
      ),
    );
  }
}
