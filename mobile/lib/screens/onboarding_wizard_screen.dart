import 'dart:async' show unawaited;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart' show PriceBand;
import 'app_shell.dart';
import '../design/tokens.dart';
import '../domain/trip_profile.dart';
import '../domain/vehicle_model.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../storage/app_prefs.dart';
import '../widgets/hotel_preferences.dart';
import '../widgets/restaurant_preferences.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
const _kAccents = [
  Color(0xFF0D2137), // 0 welcome
  Color(0xFF1B2E1A), // 1 who
  Color(0xFF1C1236), // 2 vehicle
  Color(0xFF1E1208), // 3 model
  Color(0xFF1A1008), // 4 toll
  Color(0xFF1E1208), // 5 rhythm  (same amber family)
  Color(0xFF0A2020), // 6 done
];
const _kHighlights = [
  Color(0xFF40C4FF), // 0 sky blue
  Color(0xFF69F0AE), // 1 mint
  Color(0xFFCE93D8), // 2 lilac
  Color(0xFFFFB300), // 3 amber (model)
  Color(0xFFFFC107), // 4 amber (toll)
  Color(0xFFFFCA28), // 5 amber (rhythm)
  Color(0xFF80CBC4), // 6 teal (done)
];

// ─── Main screen ─────────────────────────────────────────────────────────────

class OnboardingWizardScreen extends ConsumerStatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  ConsumerState<OnboardingWizardScreen> createState() =>
      _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState
    extends ConsumerState<OnboardingWizardScreen> {
  final _ctrl = PageController();
  int _page = 0;
  static const _total = 7;

  // collected values
  bool _hasKids = false;
  bool _hasPets = false;
  bool _isCamper = false;
  VehicleType _vehicleType = VehicleType.car;
  FuelType _fuelType = FuelType.petrol;
  String? _vehicleModelId; // null = generic/manual
  // Manual consumption + tank (used when no catalogue model selected)
  double _consumptionL100km = 7.0;
  double _tankL = 50.0;
  bool _avoidTolls = true;
  double _wakeHour = 8.0;
  double _breakHours = 3.0;
  double _bedtimeHour = 22.0;
  PriceBand _hotelBudget = PriceBand.mid;
  PriceBand _mealBudget = PriceBand.mid;

  void _next() {
    if (_page < _total - 1) {
      _ctrl.nextPage(
          duration: 420.ms, curve: Curves.easeInOutCubic);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page > 0) {
      _ctrl.previousPage(
          duration: 300.ms, curve: Curves.easeOutCubic);
    }
  }

  Future<void> _finish() async {
    if (!mounted) return;
    final prefs = ref.read(appPrefsProvider);
    final existing = prefs.tripProfile ?? const TripProfile();
    // Save profile data synchronously so splash sees it on re-route.
    await prefs.setTripProfile(
      existing.copyWith(
        hasKids: _hasKids,
        hasPets: _hasPets,
        wakeHour: _wakeHour.round(),
        bedtimeHour: _bedtimeHour.round(),
        dailyDrivingCapHours: (_bedtimeHour - _wakeHour - 1).round().clamp(3, 14),
        vehicle: existing.vehicle.copyWith(
          type: _vehicleType,
          fuelType: _fuelType,
          fuelTankL: _vehicleModelId == null ? _tankL : existing.vehicle.fuelTankL,
          consumptionLPer100km: _vehicleModelId == null
              ? _consumptionL100km
              : existing.vehicle.consumptionLPer100km,
        ),
        vehicleModelId: _vehicleModelId,
      ),
    );
    unawaited(prefs.setTollAlternativeDefault(_avoidTolls));
    unawaited(prefs.setHotelPrefs(
        prefs.hotelPrefs.copyWith(priceBands: {_hotelBudget}, enabled: true)));
    unawaited(prefs.setRestaurantPrefs(
        prefs.restaurantPrefs.copyWith(
            priceBands: {_mealBudget}, enabled: true)));
    // CRITICAL: mark wizard shown BEFORE navigating so splash routes to AppShell.
    await prefs.setOnboardingShown();
    ref.read(tripProfileProvider.notifier)
      ..api = ref.read(apiClientWithPremiumProvider)
      ..pushSettingsChange();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  Future<void> _skip() async {
    if (!mounted) return;
    await ref.read(appPrefsProvider).setOnboardingShown();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _total - 1;
    final hl = _kHighlights[_page];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen pages
          PageView(
            controller: _ctrl,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (p) => setState(() => _page = p),
            children: [
              _WizardShell(
                index: 0,
                visual: const _WelcomeVisual(),
                content: _WelcomeContent(onNext: _next),
              ),
              _WizardShell(
                index: 1,
                visual: _WhoVisual(
                    hasKids: _hasKids, hasPets: _hasPets, isCamper: _isCamper),
                content: _WhoContent(
                  hasKids: _hasKids,
                  hasPets: _hasPets,
                  isCamper: _isCamper,
                  onChanged: (k, p, c) => setState(() {
                    _hasKids = k;
                    _hasPets = p;
                    _isCamper = c;
                  }),
                ),
              ),
              // Page 2: vehicle type + fuel
              _WizardShell(
                index: 2,
                visual: _VehicleVisual(type: _vehicleType, fuel: _fuelType),
                content: _VehicleContent(
                  vehicleType: _vehicleType,
                  fuelType: _fuelType,
                  isCamper: _isCamper,
                  onChanged: (vt, ft) => setState(() {
                    _vehicleType = vt;
                    _fuelType = ft;
                    _vehicleModelId = null; // reset model when type changes
                  }),
                ),
              ),
              // Page 3: vehicle model picker
              _WizardShell(
                index: 3,
                visualFlex: 3,
                contentFlex: 7,
                visual: _ModelVisual(
                    vehicleType: _vehicleType, modelId: _vehicleModelId),
                content: _ModelContent(
                  vehicleType: _vehicleType,
                  fuelType: _fuelType,
                  selectedModelId: _vehicleModelId,
                  consumptionL100km: _consumptionL100km,
                  tankL: _tankL,
                  onChanged: (id) => setState(() => _vehicleModelId = id),
                  onManualChanged: (c, t) => setState(() {
                    _consumptionL100km = c;
                    _tankL = t;
                  }),
                ),
              ),
              // Page 4: toll preference
              _WizardShell(
                index: 4,
                visual: _TollVisual(avoidTolls: _avoidTolls),
                content: _TollContent(
                  avoidTolls: _avoidTolls,
                  onChanged: (v) => setState(() => _avoidTolls = v),
                ),
              ),
              // Page 5: rhythm + budget (content-heavy: small visual, big card)
              _WizardShell(
                index: 5,
                visualFlex: 2,
                contentFlex: 8,
                visual: _RhythmVisual(
                    wake: _wakeHour, brk: _breakHours, bed: _bedtimeHour),
                content: _RhythmContent(
                  wakeHour: _wakeHour,
                  breakHours: _breakHours,
                  bedtimeHour: _bedtimeHour,
                  hotelBudget: _hotelBudget,
                  mealBudget: _mealBudget,
                  onChanged: (w, b, bed, h, m) => setState(() {
                    _wakeHour = w;
                    _breakHours = b;
                    _bedtimeHour = bed;
                    _hotelBudget = h;
                    _mealBudget = m;
                  }),
                ),
              ),
              // Page 6: done
              _WizardShell(
                index: 6,
                visual: const _DoneVisual(),
                content: _DoneContent(
                  onFinish: _finish,
                  onStartDriving: () async {
                    await _finish();
                    // Parent (AppShell) will handle navigation after pop.
                    // We signal via a result value.
                  },
                ),
              ),
            ],
          ),

          // Skip button top-right
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, top: 8),
                child: isLast
                    ? const SizedBox.shrink()
                    : TextButton(
                        onPressed: _skip,
                        child: Text(
                          AppLocalizations.of(context).wizardSkip,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
              ),
            ),
          ),

          // Bottom: dots + nav buttons
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Dots(count: _total, active: _page, highlight: hl),
                    const SizedBox(height: 20),
                    if (_page == 0)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _next,
                          style: FilledButton.styleFrom(
                            backgroundColor: hl,
                            foregroundColor: Colors.black,
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            AppLocalizations.of(context).wizardStart,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _back,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(
                                    color: Colors.white24),
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                  AppLocalizations.of(context).wizardBack),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: FilledButton(
                                onPressed: _next,
                                style: FilledButton.styleFrom(
                                  backgroundColor: hl,
                                  foregroundColor: Colors.black,
                                  shape: const StadiumBorder(),
                                ),
                                child: Text(
                                  isLast
                                      ? AppLocalizations.of(context)
                                          .wizardPlanFirstTrip
                                      : AppLocalizations.of(context)
                                          .wizardNext,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dots ─────────────────────────────────────────────────────────────────────

class _Dots extends StatelessWidget {
  const _Dots(
      {required this.count, required this.active, required this.highlight});
  final int count;
  final int active;
  final Color highlight;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: 300.ms,
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: i == active ? 28 : 6,
              decoration: BoxDecoration(
                color: i == active ? highlight : Colors.white30,
                borderRadius: BorderRadius.circular(Tokens.radiusPill),
              ),
            ),
        ],
      );
}

// ─── Shell: gradient background + glassmorphism card ──────────────────────────

class _WizardShell extends StatelessWidget {
  const _WizardShell({
    required this.index,
    required this.visual,
    required this.content,
    this.visualFlex = 5,
    this.contentFlex = 5,
  });
  final int index;
  final Widget visual;
  final Widget content;
  final int visualFlex;
  final int contentFlex;

  @override
  Widget build(BuildContext context) {
    final accent = _kAccents[index];
    final hl = _kHighlights[index];
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 1.5,
          colors: [accent.withValues(alpha: 0.9), Colors.black],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 52), // skip button space
            Expanded(
              flex: visualFlex,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: visual,
              ),
            ),
            Expanded(
              flex: contentFlex,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: hl.withValues(alpha: 0.2),
                        ),
                      ),
                      child: content,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page 0: Welcome ─────────────────────────────────────────────────────────

class _WelcomeVisual extends StatelessWidget {
  const _WelcomeVisual();

  @override
  Widget build(BuildContext context) {
    final hl = _kHighlights[0];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (b) => LinearGradient(
              colors: [hl, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(b),
            child: const Icon(Icons.route, size: 90, color: Colors.white),
          )
              .animate()
              .scale(begin: const Offset(0.6, 0.6), duration: 600.ms,
                  curve: Curves.elasticOut)
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (icon, delay) in [
                (Icons.local_gas_station_outlined, 0.ms),
                (Icons.toll_outlined, 150.ms),
                (Icons.restaurant_outlined, 300.ms),
                (Icons.hotel_outlined, 450.ms),
                (Icons.warning_amber_outlined, 600.ms),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(icon, size: 22, color: hl.withValues(alpha: 0.7))
                      .animate(delay: delay)
                      .fadeIn(duration: 300.ms)
                      .moveY(begin: 10, end: 0),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final hl = _kHighlights[0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('MyTravelPal',
                style: t.labelSmall?.copyWith(
                    color: hl,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w700))
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms),
        const SizedBox(height: 6),
        Text(l.wizardWelcomeTitle,
                style: t.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.15))
            .animate()
            .fadeIn(delay: 300.ms, duration: 400.ms)
            .moveY(begin: 6, end: 0),
        const SizedBox(height: 10),
        Text(l.wizardWelcomeBody,
                style: t.bodyMedium
                    ?.copyWith(color: Colors.white70, height: 1.45))
            .animate()
            .fadeIn(delay: 420.ms, duration: 400.ms),
        const SizedBox(height: 12),
        Text(l.wizardTakesSeconds,
                style: t.labelSmall
                    ?.copyWith(color: Colors.white38, letterSpacing: 0.5))
            .animate()
            .fadeIn(delay: 550.ms, duration: 300.ms),
      ],
    );
  }
}

// ─── Page 1: Who ─────────────────────────────────────────────────────────────

class _WhoVisual extends StatelessWidget {
  const _WhoVisual(
      {required this.hasKids, required this.hasPets, required this.isCamper});
  final bool hasKids;
  final bool hasPets;
  final bool isCamper;

  @override
  Widget build(BuildContext context) {
    final hl = _kHighlights[1];
    final active = <(IconData, String)>[
      if (hasKids) (Icons.child_care, 'Niños'),
      if (hasPets) (Icons.pets, 'Mascotas'),
      if (isCamper) (Icons.rv_hookup, 'Autocaravana'),
    ];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Family icon large
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: hl.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border:
                  Border.all(color: hl.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Icon(Icons.people_outlined, size: 52, color: hl),
          ).animate().scale(
              begin: const Offset(0.7, 0.7),
              duration: 500.ms,
              curve: Curves.elasticOut),
          if (active.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final (i, (icon, label))
                    in active.indexed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: hl.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(Tokens.radiusPill),
                      border: Border.all(
                          color: hl.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 14, color: hl),
                        const SizedBox(width: 6),
                        Text(label,
                            style: TextStyle(
                                color: hl,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ).animate(delay: (i * 100).ms)
                      .fadeIn(duration: 300.ms)
                      .scale(
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1, 1)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WhoContent extends StatelessWidget {
  const _WhoContent({
    required this.hasKids,
    required this.hasPets,
    required this.isCamper,
    required this.onChanged,
  });
  final bool hasKids;
  final bool hasPets;
  final bool isCamper;
  final void Function(bool kids, bool pets, bool camper) onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final hl = _kHighlights[1];

    final opts = [
      (Icons.child_care, l.wizardWhoKids, hasKids,
          () => onChanged(!hasKids, hasPets, isCamper)),
      (Icons.pets, l.wizardWhoPets, hasPets,
          () => onChanged(hasKids, !hasPets, isCamper)),
      (Icons.rv_hookup, l.wizardWhoCamper, isCamper,
          () => onChanged(hasKids, hasPets, !isCamper)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.wizardWhoTitle,
                style: t.titleLarge?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w800))
            .animate()
            .fadeIn(delay: 100.ms, duration: 350.ms),
        const SizedBox(height: 4),
        Text(l.wizardWhoSubtitle,
                style:
                    t.bodySmall?.copyWith(color: Colors.white54, height: 1.4))
            .animate()
            .fadeIn(delay: 180.ms, duration: 350.ms),
        const SizedBox(height: 12),
        for (final (i, (icon, label, selected, onTap)) in opts.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: 200.ms,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: selected
                      ? hl.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? hl.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.1),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon,
                        size: 20,
                        color: selected ? hl : Colors.white38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(label,
                          style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : Colors.white60,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize: 14)),
                    ),
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                      color: selected ? hl : Colors.white24,
                    ),
                  ],
                ),
              ),
            ).animate(delay: (200 + i * 80).ms)
                .fadeIn(duration: 300.ms)
                .moveY(begin: 6, end: 0),
          ),
      ],
    );
  }
}

// ─── Page 2: Vehicle ─────────────────────────────────────────────────────────

class _VehicleVisual extends StatelessWidget {
  const _VehicleVisual({required this.type, required this.fuel});
  final VehicleType type;
  final FuelType fuel;

  @override
  Widget build(BuildContext context) {
    final hl = _kHighlights[2];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: hl.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border:
                  Border.all(color: hl.withValues(alpha: 0.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: hl.withValues(alpha: 0.2),
                    blurRadius: 24,
                    spreadRadius: 4),
              ],
            ),
            child: Icon(type.icon, size: 54, color: hl),
          ).animate(key: ValueKey(type))
              .scale(
                  begin: const Offset(0.7, 0.7),
                  duration: 450.ms,
                  curve: Curves.elasticOut)
              .fadeIn(duration: 250.ms),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: hl.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Tokens.radiusPill),
              border: Border.all(color: hl.withValues(alpha: 0.35)),
            ),
            child: Text(
              _fuelEmoji(fuel),
              style: TextStyle(
                  color: hl, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ).animate(key: ValueKey(fuel))
              .fadeIn(duration: 250.ms)
              .scale(
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1, 1)),
        ],
      ),
    );
  }

  String _fuelEmoji(FuelType f) => switch (f) {
        FuelType.petrol => '⛽ Gasolina',
        FuelType.diesel => '🛢 Diésel',
        FuelType.hybrid => '⚡ Híbrido',
        FuelType.electric => '🔋 Eléctrico',
        _ => f.label,
      };
}

class _VehicleContent extends StatelessWidget {
  const _VehicleContent({
    required this.vehicleType,
    required this.fuelType,
    required this.isCamper,
    required this.onChanged,
  });
  final VehicleType vehicleType;
  final FuelType fuelType;
  final bool isCamper;
  final void Function(VehicleType, FuelType) onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final hl = _kHighlights[2];

    final types = isCamper
        ? VehicleType.values
        : VehicleType.values
            .where((v) => v != VehicleType.camper)
            .toList();

    final fuels = [
      FuelType.petrol,
      FuelType.diesel,
      FuelType.hybrid,
      FuelType.electric,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.wizardVehicleTitle,
                style: t.titleLarge?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w800))
            .animate()
            .fadeIn(delay: 100.ms, duration: 350.ms),
        const SizedBox(height: 4),
        Text(l.wizardVehicleSubtitle,
                style: t.bodySmall?.copyWith(color: Colors.white54))
            .animate()
            .fadeIn(delay: 180.ms, duration: 350.ms),
        const SizedBox(height: 10),
        Text(l.wizardVehicleType,
            style: TextStyle(
                color: hl,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final vt in types)
              _WizardChip(
                icon: vt.icon,
                label: _vehicleLabel(l, vt),
                selected: vehicleType == vt,
                highlight: hl,
                onTap: () => onChanged(vt, fuelType),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(l.wizardFuelType,
            style: TextStyle(
                color: hl,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final ft in fuels)
              _WizardChip(
                label: _fuelLabel(l, ft),
                selected: fuelType == ft,
                highlight: hl,
                onTap: () => onChanged(vehicleType, ft),
              ),
          ],
        ),
      ],
    );
  }

  String _vehicleLabel(AppLocalizations l, VehicleType v) => switch (v) {
        VehicleType.car => l.vehicleTypeCar,
        VehicleType.motorbike => l.vehicleTypeMotorbike,
        VehicleType.van => l.vehicleTypeVan,
        VehicleType.camper => l.vehicleTypeCamper,
      };
  String _fuelLabel(AppLocalizations l, FuelType f) => switch (f) {
        FuelType.petrol => l.fuelTypePetrol,
        FuelType.diesel => l.fuelTypeDiesel,
        FuelType.hybrid => l.fuelTypeHybrid,
        FuelType.electric => l.fuelTypeElectric,
        _ => f.label,
      };
}

// ─── Page 3: Rhythm ──────────────────────────────────────────────────────────

class _RhythmVisual extends StatelessWidget {
  const _RhythmVisual(
      {required this.wake, required this.brk, required this.bed});
  final double wake;
  final double brk;
  final double bed;

  @override
  Widget build(BuildContext context) {
    final hl = _kHighlights[3];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Day timeline
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: hl.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _TimeChip(icon: Icons.wb_sunny_outlined,
                        label: '${wake.floor().toString().padLeft(2, '0')}:${wake % 1 >= 0.5 ? "30" : "00"}', color: hl),
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [hl, hl.withValues(alpha: 0.3)]),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                    _TimeChip(icon: Icons.bedtime_outlined,
                        label: '${bed.floor().toString().padLeft(2, '0')}:${bed % 1 >= 0.5 ? "30" : "00"}', color: hl),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.coffee_outlined, size: 14,
                        color: hl.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Text('Pausa cada ${brk % 1.0 >= 0.5 ? "${brk.floor()}h 30m" : "${brk.floor()}h"}',
                        style: TextStyle(
                            color: hl.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
          const SizedBox(height: 16),
          // Budget preview
          Row(
            children: [
              Expanded(
                child: _BudgetPreview(
                    icon: Icons.hotel_outlined,
                    label: 'Hotel', color: hl, delay: 300.ms),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BudgetPreview(
                    icon: Icons.restaurant_outlined,
                    label: 'Comida', color: hl, delay: 450.ms),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _BudgetPreview extends StatelessWidget {
  const _BudgetPreview(
      {required this.icon,
      required this.label,
      required this.color,
      required this.delay});
  final IconData icon;
  final String label;
  final Color color;
  final Duration delay;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      ).animate(delay: delay)
          .fadeIn(duration: 300.ms)
          .moveY(begin: 6, end: 0);
}

class _RhythmContent extends StatelessWidget {
  const _RhythmContent({
    required this.wakeHour,
    required this.breakHours,
    required this.bedtimeHour,
    required this.hotelBudget,
    required this.mealBudget,
    required this.onChanged,
  });
  final double wakeHour;
  final double breakHours;
  final double bedtimeHour;
  final PriceBand hotelBudget;
  final PriceBand mealBudget;
  final void Function(double wake, double brk, double bed, PriceBand hotel,
      PriceBand meal) onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final hl = _kHighlights[3];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.wizardRhythmTitle,
                  style: t.titleLarge?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800))
              .animate()
              .fadeIn(delay: 100.ms, duration: 350.ms),
          const SizedBox(height: 4),
          Text(l.wizardRhythmSubtitle,
                  style: t.bodySmall?.copyWith(color: Colors.white54))
              .animate()
              .fadeIn(delay: 180.ms, duration: 350.ms),
          const SizedBox(height: 10),
          _WizardSlider(
            label: l.wizardWakeHour(_fmtH(wakeHour)),
            icon: Icons.wb_sunny_outlined,
            value: wakeHour,
            min: 5, max: 12, divisions: 14,
            highlight: hl,
            onChanged: (v) => onChanged(
                _snapHalf(v), breakHours, bedtimeHour, hotelBudget, mealBudget),
          ),
          _WizardSlider(
            label: l.wizardBreakEvery(
                '${breakHours.floor()}h${breakHours % 1.0 >= 0.5 ? " 30m" : ""}'),
            icon: Icons.coffee_outlined,
            value: breakHours,
            min: 1, max: 5, divisions: 8,
            highlight: hl,
            onChanged: (v) => onChanged(
                wakeHour, _snapHalf(v), bedtimeHour, hotelBudget, mealBudget),
          ),
          _WizardSlider(
            label: l.wizardBedtime(_fmtH(bedtimeHour)),
            icon: Icons.bedtime_outlined,
            value: bedtimeHour,
            min: 18, max: 24, divisions: 12,
            highlight: hl,
            onChanged: (v) => onChanged(
                wakeHour, breakHours, _snapHalf(v), hotelBudget, mealBudget),
          ),
          const SizedBox(height: 6),
          // "Not written in stone" reassurance
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: hl.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: hl.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 13,
                    color: hl.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(l.wizardRhythmNote,
                      style: TextStyle(
                          color: Colors.white54, fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(l.wizardHotelBudget,
              style: TextStyle(
                  color: hl,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 5),
          _BudgetChips(
            selected: hotelBudget,
            highlight: hl,
            onSelected: (b) => onChanged(
                wakeHour, breakHours, bedtimeHour, b, mealBudget),
            l: l,
          ),
          const SizedBox(height: 8),
          Text(l.wizardMealBudget,
              style: TextStyle(
                  color: hl,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 5),
          _BudgetChips(
            selected: mealBudget,
            highlight: hl,
            onSelected: (b) => onChanged(
                wakeHour, breakHours, bedtimeHour, hotelBudget, b),
            l: l,
          ),
        ],
      ),
    );
  }

  /// Snap a slider value to the nearest 0.5.
  double _snapHalf(double v) => (v * 2).round() / 2.0;

  /// Format hours as HH:MM, supporting .5 = :30.
  String _fmtH(double h) {
    final whole = h.floor();
    final mins = h % 1.0 >= 0.5 ? '30' : '00';
    return '${whole.toString().padLeft(2, '0')}:$mins';
  }

  /// Format break interval as "2h" or "2h 30m".
  String _fmtBreak(double h) {
    final whole = h.floor();
    if (h % 1.0 >= 0.5) return '${whole}h 30m';
    return '${whole}h';
  }
}

class _WizardSlider extends StatelessWidget {
  const _WizardSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.highlight,
    required this.onChanged,
  });
  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color highlight;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: highlight.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: highlight,
              thumbColor: highlight,
              inactiveTrackColor: Colors.white12,
              overlayColor: highlight.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      );
}

class _BudgetChips extends StatelessWidget {
  const _BudgetChips({
    required this.selected,
    required this.highlight,
    required this.onSelected,
    required this.l,
  });
  final PriceBand selected;
  final Color highlight;
  final ValueChanged<PriceBand> onSelected;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final bands = [PriceBand.budget, PriceBand.mid, PriceBand.lux];
    return Row(
      children: [
        for (final b in bands)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onSelected(b),
                child: AnimatedContainer(
                  duration: 180.ms,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected == b
                        ? highlight.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected == b
                          ? highlight.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.1),
                      width: selected == b ? 1.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _label(b),
                      style: TextStyle(
                        color: selected == b ? highlight : Colors.white54,
                        fontSize: 11,
                        fontWeight: selected == b
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _label(PriceBand b) => switch (b) {
        PriceBand.budget => l.priceBandBudget,
        PriceBand.mid => l.priceBandMid,
        PriceBand.lux => l.priceBandLux,
        _ => b.symbol,
      };
}

// ─── Page 4: Done ────────────────────────────────────────────────────────────

class _DoneVisual extends StatelessWidget {
  const _DoneVisual();

  @override
  Widget build(BuildContext context) {
    final hl = _kHighlights[4];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: hl.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: hl.withValues(alpha: 0.4), width: 2),
              boxShadow: [
                BoxShadow(
                    color: hl.withValues(alpha: 0.25),
                    blurRadius: 30,
                    spreadRadius: 5),
              ],
            ),
            child: Icon(Icons.check_rounded, size: 54, color: hl),
          )
              .animate()
              .scale(
                  begin: const Offset(0.5, 0.5),
                  duration: 600.ms,
                  curve: Curves.elasticOut)
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 20),
          // Feature summary dots
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final (i, (icon, label)) in [
                (Icons.people_outlined, 'Perfil'),
                (Icons.directions_car_outlined, 'Vehículo'),
                (Icons.schedule, 'Ritmo'),
                (Icons.hotel_outlined, 'Presupuesto'),
              ].indexed)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: hl.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(Tokens.radiusPill),
                    border: Border.all(color: hl.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 12, color: hl),
                      const SizedBox(width: 5),
                      Text(label,
                          style: TextStyle(
                              color: hl,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
                    .animate(delay: (300 + i * 120).ms)
                    .fadeIn(duration: 300.ms)
                    .scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1, 1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoneContent extends StatelessWidget {
  const _DoneContent({required this.onFinish, this.onStartDriving});
  final VoidCallback onFinish;
  final VoidCallback? onStartDriving;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final hl = _kHighlights[4];

    final teaserItems = [
      (Icons.directions_car_outlined, l.wizardTeaserVehicleModel),
      (Icons.alt_route, l.wizardTeaserRoute),
      (Icons.contact_emergency_outlined, l.wizardTeaserEmergency),
      (Icons.notifications_active_outlined, l.wizardTeaserAlertSound),
      (Icons.star_border, l.wizardTeaserStars),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.wizardDoneTitle,
                  style: t.titleLarge?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800))
              .animate()
              .fadeIn(delay: 100.ms, duration: 350.ms),
          const SizedBox(height: 4),
          Text(l.wizardDoneSubtitle,
                  style: t.bodySmall?.copyWith(color: Colors.white70))
              .animate()
              .fadeIn(delay: 180.ms, duration: 350.ms),
          const SizedBox(height: 12),
          // Companion card
          InkWell(
            onTap: onStartDriving,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: hl.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: hl.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: hl.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.assistant_navigation,
                        size: 22, color: hl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.companionModeLabel,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        Text(l.companionModeDesc,
                            style: TextStyle(
                                color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: hl.withValues(alpha: 0.6), size: 20),
                ],
              ),
            ),
          ).animate(delay: 320.ms).fadeIn(duration: 350.ms)
              .moveY(begin: 6, end: 0),
          const SizedBox(height: 12),
          Text(l.wizardTeaserTitle,
                  style: TextStyle(
                      color: hl,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1))
              .animate()
              .fadeIn(delay: 450.ms, duration: 300.ms),
          const SizedBox(height: 6),
          for (final (i, (icon, text)) in teaserItems.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Icon(icon, size: 13, color: Colors.white30),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(text,
                        style: TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ),
                ],
              ).animate(delay: (500 + i * 60).ms)
                  .fadeIn(duration: 250.ms)
                  .moveX(begin: 5, end: 0),
            ),
        ],
      ),
    );
  }
}

// ─── Page 3: Model picker ─────────────────────────────────────────────────────

class _ModelVisual extends StatelessWidget {
  const _ModelVisual({required this.vehicleType, required this.modelId});
  final VehicleType vehicleType;
  final String? modelId;

  @override
  Widget build(BuildContext context) {
    final hl = _kHighlights[2];
    return Consumer(
      builder: (context, ref, _) {
        final catalogueAsync = ref.watch(vehicleCatalogueProvider);
        return catalogueAsync.when(
          loading: () => Center(
              child: CircularProgressIndicator(color: hl)),
          error: (_, __) => Icon(vehicleType.icon, size: 80, color: hl),
          data: (catalogue) {
            final prefix = _prefix(vehicleType);
            final filtered = catalogue
                .where((m) => m.id.startsWith(prefix))
                .toList();
            final selected = modelId != null
                ? filtered.where((m) => m.id == modelId).firstOrNull
                : null;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: hl.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: hl.withValues(alpha: 0.35), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: hl.withValues(alpha: 0.2),
                            blurRadius: 24, spreadRadius: 4),
                      ],
                    ),
                    child: Icon(vehicleType.icon, size: 52, color: hl),
                  ).animate().scale(
                      begin: const Offset(0.7, 0.7),
                      duration: 450.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 16),
                  if (selected != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: hl.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(Tokens.radiusPill),
                        border: Border.all(color: hl.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        children: [
                          Text('${selected.make} ${selected.model}',
                              style: TextStyle(
                                  color: hl,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          Text(
                            '${selected.tankLiters.toStringAsFixed(0)} L · '
                            '${selected.consumptionL100km.toStringAsFixed(1)} L/100km',
                            style: TextStyle(
                                color: hl.withValues(alpha: 0.7),
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 280.ms)
                        .scale(begin: const Offset(0.85, 0.85),
                            end: const Offset(1, 1)),
                  ] else ...[
                    Text(
                      '${filtered.length} modelos disponibles',
                      style: TextStyle(
                          color: hl.withValues(alpha: 0.6), fontSize: 12),
                    ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _prefix(VehicleType t) => switch (t) {
        VehicleType.motorbike => 'moto_',
        VehicleType.camper => 'caravan_',
        VehicleType.van => 'caravan_',
        _ => '',
      };
}

class _ModelContent extends ConsumerStatefulWidget {
  const _ModelContent({
    required this.vehicleType,
    required this.fuelType,
    required this.selectedModelId,
    required this.consumptionL100km,
    required this.tankL,
    required this.onChanged,
    required this.onManualChanged,
  });
  final VehicleType vehicleType;
  final FuelType fuelType;
  final String? selectedModelId;
  final double consumptionL100km;
  final double tankL;
  final ValueChanged<String?> onChanged;
  final void Function(double consumption, double tank) onManualChanged;

  @override
  ConsumerState<_ModelContent> createState() => _ModelContentState();
}

class _ModelContentState extends ConsumerState<_ModelContent> {
  final _queryCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  String _prefix(VehicleType t) => switch (t) {
        VehicleType.motorbike => 'moto_',
        VehicleType.camper => 'caravan_',
        VehicleType.van => 'caravan_',
        _ => '',
      };

  List<VehicleModel> _filter(List<VehicleModel> all) {
    final prefix = _prefix(widget.vehicleType);
    var list = prefix.isEmpty
        ? all.where((m) =>
            !m.id.startsWith('moto_') && !m.id.startsWith('caravan_')).toList()
        : all.where((m) => m.id.startsWith(prefix)).toList();
    // Filter by matching fuel type
    list = list.where((m) => m.fuelType == widget.fuelType).toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((m) =>
              m.make.toLowerCase().contains(q) ||
              m.model.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final hl = _kHighlights[2];
    final catalogue = ref.watch(vehicleCatalogueProvider).valueOrNull ?? [];
    final filtered = _filter(catalogue);

    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    return ListView(
      padding: EdgeInsets.only(bottom: keyboardInset),
      children: [
        Text(l.wizardModelTitle,
                style: t.titleLarge?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w800))
            .animate().fadeIn(delay: 100.ms, duration: 350.ms),
        const SizedBox(height: 4),
        Text(l.wizardModelSubtitle,
                style: t.bodySmall?.copyWith(color: Colors.white54))
            .animate().fadeIn(delay: 180.ms, duration: 350.ms),
        const SizedBox(height: 8),
        // Manual sliders always visible at top when generic selected
        if (widget.selectedModelId == null) ...[
          _WizardSlider(
            label: '${l.wizardModelConsumption}: '
                '${widget.consumptionL100km.toStringAsFixed(1)} L/100km',
            icon: Icons.local_gas_station_outlined,
            value: widget.consumptionL100km,
            min: 3.0, max: 25.0, divisions: 22,
            highlight: hl,
            onChanged: (v) => widget.onManualChanged(v, widget.tankL),
          ),
          _WizardSlider(
            label: '${l.wizardModelTank}: '
                '${widget.tankL.toStringAsFixed(0)} L',
            icon: Icons.propane_tank_outlined,
            value: widget.tankL,
            min: 10.0, max: 150.0, divisions: 28,
            highlight: hl,
            onChanged: (v) => widget.onManualChanged(
                widget.consumptionL100km, v),
          ),
          const SizedBox(height: 4),
        ],
        // Search field with clear button
        TextField(
          controller: _queryCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: l.wizardModelSearch,
            hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
            prefixIcon: Icon(Icons.search, color: hl, size: 18),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16,
                        color: Colors.white38),
                    onPressed: () {
                      _queryCtrl.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            contentPadding: const EdgeInsets.symmetric(
                vertical: 10, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: hl.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15)),
            ),
          ),
          onChanged: (v) =>
              setState(() => _query = v.toLowerCase().trim()),
        ),
        const SizedBox(height: 6),
        // "Generic" option
        _ModelTile(
          icon: Icons.tune,
          make: l.wizardModelGeneric,
          model: l.wizardModelGenericSub,
          selected: widget.selectedModelId == null,
          highlight: hl,
          onTap: () => widget.onChanged(null),
        ),
        for (final m in filtered.take(8))
          _ModelTile(
            icon: widget.vehicleType.icon,
            make: m.make,
            model: '${m.model} · '
                '${m.tankLiters.toStringAsFixed(0)} L · '
                '${m.consumptionL100km.toStringAsFixed(1)} L/100km',
            selected: widget.selectedModelId == m.id,
            highlight: hl,
            onTap: () => widget.onChanged(m.id),
          ),
        if (filtered.length > 8)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+${filtered.length - 8} — busca por nombre',
              style: TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.icon,
    required this.make,
    required this.model,
    required this.selected,
    required this.highlight,
    required this.onTap,
  });
  final IconData icon;
  final String make;
  final String model;
  final bool selected;
  final Color highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: 150.ms,
          margin: const EdgeInsets.only(bottom: 5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? highlight.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? highlight.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.08),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16,
                  color: selected ? highlight : Colors.white38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(make,
                        style: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500)),
                    Text(model,
                        style: TextStyle(
                            color: Colors.white38, fontSize: 10),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, size: 16, color: highlight),
            ],
          ),
        ),
      );
}

// ─── Page 4: Toll preference ──────────────────────────────────────────────────

class _TollVisual extends StatelessWidget {
  const _TollVisual({required this.avoidTolls});
  final bool avoidTolls;

  @override
  Widget build(BuildContext context) {
    final hl = _kHighlights[3];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: hl.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: hl.withValues(alpha: 0.35), width: 1.5),
              boxShadow: [
                BoxShadow(color: hl.withValues(alpha: 0.2),
                    blurRadius: 24, spreadRadius: 4),
              ],
            ),
            child: Icon(
              avoidTolls ? Icons.alt_route : Icons.toll_outlined,
              size: 52, color: hl,
            ),
          ).animate(key: ValueKey(avoidTolls))
              .scale(begin: const Offset(0.7, 0.7), duration: 400.ms,
                  curve: Curves.elasticOut),
          const SizedBox(height: 20),
          // Mini comparison
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Builder(builder: (ctx) {
                final lc = AppLocalizations.of(ctx);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TollCompCard(
                      icon: Icons.alt_route,
                      label: lc.wizardTollFreeDetour,
                      value: '+12 min',
                      savings: 'Ahorro €8',
                      selected: avoidTolls,
                      highlight: hl,
                    ),
                    const SizedBox(width: 12),
                    _TollCompCard(
                      icon: Icons.toll_outlined,
                      label: lc.wizardTollMotorway,
                      value: '€8',
                      savings: lc.wizardTollFaster,
                      selected: !avoidTolls,
                      highlight: Colors.white54,
                    ),
                  ],
                );
              }),
            ],
          ).animate(delay: 200.ms).fadeIn(duration: 350.ms),
        ],
      ),
    );
  }
}

class _TollCompCard extends StatelessWidget {
  const _TollCompCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.savings,
    required this.selected,
    required this.highlight,
  });
  final IconData icon;
  final String label;
  final String value;
  final String savings;
  final bool selected;
  final Color highlight;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? highlight.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? highlight.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? highlight : Colors.white38, size: 18),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: Colors.white54, fontSize: 10, letterSpacing: 0.3)),
            Text(value,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            Text(savings,
                style: TextStyle(
                    color: selected ? highlight : Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _TollContent extends StatelessWidget {
  const _TollContent({required this.avoidTolls, required this.onChanged});
  final bool avoidTolls;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final hl = _kHighlights[3];

    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.wizardTollTitle,
                style: t.titleLarge?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w800))
            .animate().fadeIn(delay: 100.ms, duration: 350.ms),
        const SizedBox(height: 4),
        Text(l.wizardTollSubtitle,
                style: t.bodySmall?.copyWith(color: Colors.white54))
            .animate().fadeIn(delay: 180.ms, duration: 350.ms),
        const SizedBox(height: 16),
        // How it works explanation
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hl.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.auto_awesome, size: 14, color: hl),
                const SizedBox(width: 6),
                Text(l.wizardTollHowTitle,
                    style: TextStyle(
                        color: hl,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0)),
              ]),
              const SizedBox(height: 8),
              Text(l.wizardTollHowBody,
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12, height: 1.4)),
            ],
          ),
        ).animate(delay: 200.ms).fadeIn(duration: 350.ms),
        const SizedBox(height: 12),
        // Preference toggle
        Text(l.wizardTollPreference,
            style: TextStyle(
                color: hl,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1)),
        const SizedBox(height: 8),
        for (final (idx, (icon, title, sub)) in [
          (Icons.alt_route, l.wizardTollAvoid, l.wizardTollAvoidSub),
          (Icons.toll_outlined, l.wizardTollPay, l.wizardTollPaySub),
        ].indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onChanged(idx == 0),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: 180.ms,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (idx == 0 ? avoidTolls : !avoidTolls)
                      ? hl.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (idx == 0 ? avoidTolls : !avoidTolls)
                        ? hl.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.1),
                    width: (idx == 0 ? avoidTolls : !avoidTolls) ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon,
                        color: (idx == 0 ? avoidTolls : !avoidTolls)
                            ? hl : Colors.white38, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: TextStyle(
                                  color: (idx == 0 ? avoidTolls : !avoidTolls)
                                      ? Colors.white : Colors.white60,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          Text(sub,
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    Icon(
                      (idx == 0 ? avoidTolls : !avoidTolls)
                          ? Icons.check_circle : Icons.circle_outlined,
                      color: (idx == 0 ? avoidTolls : !avoidTolls)
                          ? hl : Colors.white24,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ).animate(delay: (350 + idx * 80).ms)
                .fadeIn(duration: 280.ms),
          ),
        const SizedBox(height: 4),
        Text(l.wizardTollNote,
            style: t.labelSmall?.copyWith(color: Colors.white30))
            .animate().fadeIn(delay: 550.ms, duration: 300.ms),
      ],
      ), // closes Column
    ); // closes SingleChildScrollView
  }
}

// ─── Shared chip ─────────────────────────────────────────────────────────────

class _WizardChip extends StatelessWidget {
  const _WizardChip({
    required this.label,
    required this.selected,
    required this.highlight,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final Color highlight;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: 180.ms,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? highlight.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(Tokens.radiusPill),
            border: Border.all(
              color: selected
                  ? highlight.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.12),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14,
                    color: selected ? highlight : Colors.white38),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(
                    color: selected ? highlight : Colors.white54,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  )),
            ],
          ),
        ),
      );
}

