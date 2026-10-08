import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'login_screen.dart';

// ─── Palette per slide ───────────────────────────────────────────────────────
const _kSlideAccents = [
  Color(0xFF1A237E), // slide 0 — deep navy (cost)
  Color(0xFF1B4332), // slide 1 — dark green (tolls + fuel)
  Color(0xFF3E1F47), // slide 2 — deep violet (profile)
  Color(0xFF7B1F1F), // slide 3 — dark crimson (alerts)
  Color(0xFF0D2137), // slide 4 — midnight (AI copilot)
];
const _kSlideHighlights = [
  Color(0xFFFFC107), // amber
  Color(0xFF69F0AE), // mint green
  Color(0xFFCE93D8), // soft lilac
  Color(0xFFFF7043), // deep orange
  Color(0xFF40C4FF), // sky blue
];

// ─── Main screen ─────────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  Future<void> _finish() async {
    await ref.read(appPrefsProvider).markOnboardingShown();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  void _next(int count) {
    if (_page == count - 1) { _finish(); return; }
    _controller.nextPage(duration: 450.ms, curve: Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    const count = 5;
    final isLast = _page == count - 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen page view
          PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              _Slide0Cost(l: l),
              _Slide1TollsFuel(l: l),
              _Slide2Profile(l: l),
              _Slide3Alerts(l: l),
              _Slide4Companion(l: l),
            ],
          ),

          // Top-right skip
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, top: 8),
                child: isLast
                    ? const SizedBox.shrink()
                    : TextButton(
                        onPressed: _finish,
                        child: Text(
                          l.onboardSkip,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
              ),
            ),
          ),

          // Bottom controls
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Dots(count: count, active: _page,
                        highlight: _kSlideHighlights[_page]),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () => _next(count),
                        style: FilledButton.styleFrom(
                          backgroundColor: _kSlideHighlights[_page],
                          foregroundColor: Colors.black,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          isLast ? l.onboardGetStarted : l.onboardContinue,
                          style: t.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
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

// ─── Dots indicator ──────────────────────────────────────────────────────────

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active, required this.highlight});
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

// ─── Shared slide shell ───────────────────────────────────────────────────────

class _SlideShell extends StatelessWidget {
  const _SlideShell({
    required this.index,
    required this.visual,
    required this.eyebrow,
    required this.title,
    required this.body,
  });
  final int index;
  final Widget visual;
  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final accent = _kSlideAccents[index];
    final highlight = _kSlideHighlights[index];
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 1.4,
          colors: [
            accent.withValues(alpha: 0.85),
            Colors.black,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 56), // skip button space
            // Visual hero
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: visual,
              ),
            ),
            // Text block in glassmorphism card
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            eyebrow,
                            style: t.labelSmall?.copyWith(
                              color: highlight,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w700,
                            ),
                          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: t.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ).animate().fadeIn(delay: 160.ms, duration: 400.ms)
                              .moveY(begin: 6, end: 0),
                          const SizedBox(height: 12),
                          Text(
                            body,
                            style: t.bodyMedium?.copyWith(
                              color: Colors.white70,
                              height: 1.45,
                            ),
                          ).animate().fadeIn(delay: 220.ms, duration: 400.ms),
                        ],
                      ),
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

// ─── Slide 0: Cost counter ────────────────────────────────────────────────────

class _Slide0Cost extends StatelessWidget {
  const _Slide0Cost({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) => _SlideShell(
        index: 0,
        eyebrow: l.onboardEyebrowKiller,
        title: l.onboardTitleKiller,
        body: l.onboardBodyKiller,
        visual: const _CostReceiptWidget(),
      );
}

class _CostReceiptWidget extends StatelessWidget {
  const _CostReceiptWidget();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = [
      (Icons.local_gas_station_outlined, l.onboardCostFuel, 71),
      (Icons.toll_outlined,              l.onboardCostTolls, 74),
      (Icons.restaurant_outlined,        l.onboardCostMeals, 306),
      (Icons.hotel_outlined,             l.onboardCostHotel, 480),
    ];
    final savings = [
      (Icons.alt_route,              l.onboardSavingsToll,  -8),
      (Icons.local_gas_station,      l.onboardSavingsFuel,  -14),
      (Icons.hotel,                  l.onboardSavingsHotel, -42),
    ];
    const total = 931;
    const saved = 64;
    final highlight = _kSlideHighlights[0];
    final green = const Color(0xFF4ADE80);

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.trip_origin, size: 10, color: highlight),
                    const SizedBox(width: 6),
                    Text(
                      'A  →  B',
                      style: TextStyle(
                        color: highlight,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.location_on, size: 10, color: highlight),
                  ],
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < rows.length; i++) ...[
                  _ReceiptRow(
                    icon: rows[i].$1,
                    label: rows[i].$2,
                    amount: rows[i].$3,
                    delay: (i * 180).ms,
                    highlight: highlight,
                  ),
                  if (i < rows.length - 1) const SizedBox(height: 8),
                ],
                const SizedBox(height: 10),
                Divider(color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(l.onboardCostTotal, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1)),
                    const Spacer(),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: total.toDouble()),
                      duration: 1400.ms,
                      curve: Curves.easeOut,
                      builder: (_, v, __) => ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(colors: [highlight, Colors.white]).createShader(bounds),
                        child: Text('€${v.toInt()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 26)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Savings section
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: green.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.savings_outlined, size: 13, color: green),
                          const SizedBox(width: 6),
                          Text(l.onboardSavingsTitle, style: TextStyle(color: green, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < savings.length; i++) ...[
                        Row(
                          children: [
                            Icon(savings[i].$1, size: 13, color: green.withValues(alpha: 0.7)),
                            const SizedBox(width: 6),
                            Text(savings[i].$2, style: TextStyle(color: Colors.white70, fontSize: 11)),
                            const Spacer(),
                            Text('€${savings[i].$3}', style: TextStyle(color: green, fontWeight: FontWeight.w600, fontSize: 12)),
                          ],
                        ).animate(delay: (800 + i * 200).ms).fadeIn(duration: 300.ms).moveX(begin: 8, end: 0),
                        if (i < savings.length - 1) const SizedBox(height: 5),
                      ],
                      const SizedBox(height: 8),
                      Divider(color: green.withValues(alpha: 0.2), height: 1),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(l.onboardSavingsTotal, style: TextStyle(color: green, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5)),
                          const Spacer(),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: saved.toDouble()),
                            duration: 1000.ms,
                            curve: Curves.easeOut,
                            builder: (_, v, __) => Text(
                              '-€${v.toInt()}',
                              style: TextStyle(color: green, fontWeight: FontWeight.w800, fontSize: 18),
                            ),
                          ),
                        ],
                      ).animate(delay: 1400.ms).fadeIn(duration: 400.ms),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.icon,
    required this.label,
    required this.amount,
    required this.delay,
    required this.highlight,
  });
  final IconData icon;
  final String label;
  final int amount;
  final Duration delay;
  final Color highlight;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Text(
            '€$amount',
            style: TextStyle(
              color: highlight.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ).animate(delay: delay).fadeIn(duration: 350.ms).moveX(begin: 12, end: 0);
}

// ─── Slide 1: Tolls + Fuel ────────────────────────────────────────────────────

class _Slide1TollsFuel extends StatelessWidget {
  const _Slide1TollsFuel({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) => _SlideShell(
        index: 1,
        eyebrow: l.onboardEyebrowFuel,
        title: l.onboardTitleFuel,
        body: l.onboardBodyFuel,
        visual: const _TollsFuelWidget(),
      );
}

class _TollsFuelWidget extends StatelessWidget {
  const _TollsFuelWidget();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = _kSlideHighlights[1];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Toll comparison card
        Row(
          children: [
            Expanded(
              child: _InfoCard(
                icon: Icons.alt_route,
                label: l.onboardTollSkip,
                value: '+12 min',
                subValue: l.onboardTollSavingsAmt,
                color: h,
                delay: 100.ms,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoCard(
                icon: Icons.toll_outlined,
                label: l.onboardTollPay,
                value: '€8',
                subValue: l.onboardTollPeakTime,
                color: Colors.red.shade300,
                delay: 250.ms,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Fuel station comparison
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: h.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.local_gas_station, color: h, size: 18),
                  const SizedBox(width: 8),
                  Text(l.onboardFuelStationsTitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 10),
              for (final s in [
                (l.onboardFuelStation1, '1.52 €/L', true),
                (l.onboardFuelStation2, '1.79 €/L', false),
                (l.onboardFuelStation3, '1.84 €/L', false),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: s.$3 ? h : Colors.red.shade300,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(s.$1,
                            style: TextStyle(
                              color: s.$3 ? Colors.white : Colors.white54,
                              fontSize: 12,
                              fontWeight: s.$3 ? FontWeight.w600 : FontWeight.normal,
                            )),
                      ),
                      Text(s.$2,
                          style: TextStyle(
                            color: s.$3 ? h : Colors.white38,
                            fontSize: 12,
                            fontWeight: s.$3 ? FontWeight.w700 : FontWeight.normal,
                          )),
                    ],
                  ).animate(delay: (s.$3 ? 400 : 550).ms).fadeIn(duration: 300.ms),
                ),
            ],
          ),
        ).animate(delay: 350.ms).fadeIn(duration: 400.ms).moveY(begin: 8, end: 0),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subValue,
    required this.color,
    required this.delay,
  });
  final IconData icon;
  final String label;
  final String value;
  final String subValue;
  final Color color;
  final Duration delay;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 0.5,
                )),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                )),
            Text(subValue,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ).animate(delay: delay).fadeIn(duration: 350.ms).moveY(begin: 8, end: 0);
}

// ─── Slide 2: Profile-driven hotel + restaurant ───────────────────────────────

class _Slide2Profile extends StatelessWidget {
  const _Slide2Profile({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) => _SlideShell(
        index: 2,
        eyebrow: l.onboardEyebrowHonest,
        title: l.onboardTitleHonest,
        body: l.onboardBodyHonest,
        visual: const _ProfileWidget(),
      );
}

class _ProfileWidget extends StatelessWidget {
  const _ProfileWidget();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = _kSlideHighlights[2];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Profile chips
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final (icon, text, delay) in [
              (Icons.people_outlined, l.onboardProfileGroup, 0.ms),
              (Icons.pets, l.onboardProfilePet, 100.ms),
              (Icons.local_parking_outlined, l.onboardProfileParking, 200.ms),
              (Icons.star_border, l.onboardProfileStars, 300.ms),
              (Icons.euro, l.onboardProfileBudget, 400.ms),
            ])
              _ProfileChip(icon: icon, text: text, color: h, delay: delay),
          ],
        ),
        const SizedBox(height: 16),
        // Filtered results
        for (final (name, details, extra, delay, isHotel) in [
          (l.onboardHotelName, l.onboardHotelMeta, l.onboardHotelAttrs, 500.ms, true),
          (l.onboardRestaurantName, l.onboardRestaurantMeta, l.onboardRestaurantAttrs, 650.ms, false),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: h.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(isHotel ? Icons.hotel_outlined : Icons.restaurant_outlined,
                      color: h, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            )),
                        Text(details,
                            style: TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                  Text(extra,
                      style: TextStyle(color: h, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
            ).animate(delay: delay).fadeIn(duration: 350.ms).moveX(begin: 10, end: 0),
          ),
      ],
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.icon,
    required this.text,
    required this.color,
    required this.delay,
  });
  final IconData icon;
  final String text;
  final Color color;
  final Duration delay;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Tokens.radiusPill),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ).animate(delay: delay).fadeIn(duration: 300.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
}

// ─── Slide 3: Adverse events / alerts ────────────────────────────────────────

class _Slide3Alerts extends StatelessWidget {
  const _Slide3Alerts({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) => _SlideShell(
        index: 3,
        eyebrow: l.onboardEyebrowAlerts,
        title: l.onboardTitleAlerts,
        body: l.onboardBodyAlerts,
        visual: const _AlertsWidget(),
      );
}

class _AlertsWidget extends StatelessWidget {
  const _AlertsWidget();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = _kSlideHighlights[3];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // "Route map" with alert pins
        Container(
          height: 130,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Stack(
            children: [
              // Route line
              Center(
                child: CustomPaint(
                  size: const Size(double.infinity, 2),
                  painter: _RouteLine(),
                ),
              ),
              // Alert pin pulsing
              Positioned(
                left: 120, top: 30,
                child: _AlertPin(color: h, icon: Icons.local_fire_department, delay: 200.ms),
              ),
              Positioned(
                right: 80, top: 60,
                child: _AlertPin(color: Colors.orange.shade300, icon: Icons.thunderstorm_outlined, delay: 500.ms),
              ),
              // Route dots
              for (final (x, y, d) in [(20.0, 65.0, 0.ms), (80.0, 65.0, 100.ms), (240.0, 65.0, 300.ms), (320.0, 65.0, 450.ms)])
                Positioned(
                  left: x, top: y - 6,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white30, shape: BoxShape.circle,
                    ),
                  ).animate(delay: d).fadeIn(duration: 300.ms),
                ),
            ],
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
        const SizedBox(height: 16),
        // Alert cards
        for (final (icon, text, severity, delay) in [
          (Icons.local_fire_department, l.onboardAlertFire, l.onboardAlertSevere, 400.ms),
          (Icons.thunderstorm_outlined, l.onboardAlertStorm, l.onboardAlertWarning, 600.ms),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: h.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: h.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: h, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: h.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(severity,
                        style: TextStyle(
                          color: h,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        )),
                  ),
                ],
              ),
            ).animate(delay: delay).fadeIn(duration: 350.ms).moveX(begin: -8, end: 0),
          ),
      ],
    );
  }
}

class _AlertPin extends StatelessWidget {
  const _AlertPin({required this.color, required this.icon, required this.delay});
  final Color color;
  final IconData icon;
  final Duration delay;

  @override
  Widget build(BuildContext context) => Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)],
        ),
        child: Icon(icon, size: 18, color: color),
      ).animate(delay: delay, onPlay: (c) => c.repeat())
          .scale(begin: const Offset(1, 1), end: const Offset(1.12, 1.12), duration: 900.ms, curve: Curves.easeInOut)
          .then()
          .scale(begin: const Offset(1.12, 1.12), end: const Offset(1, 1), duration: 900.ms, curve: Curves.easeInOut);
}

class _RouteLine extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white30
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(20, size.height / 2),
      Offset(size.width - 20, size.height / 2),
      paint,
    );
  }
  @override
  bool shouldRepaint(_) => false;
}

// ─── Slide 4: AI Companion ────────────────────────────────────────────────────

class _Slide4Companion extends StatelessWidget {
  const _Slide4Companion({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) => _SlideShell(
        index: 4,
        eyebrow: l.onboardEyebrowDriving,
        title: l.onboardTitleDriving,
        body: l.onboardBodyDriving,
        visual: const _CompanionWidget(),
      );
}

class _CompanionWidget extends StatelessWidget {
  const _CompanionWidget();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = _kSlideHighlights[4];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Chat exchange
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(left: 48, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: h.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: h.withValues(alpha: 0.3)),
            ),
            child: Text(
              l.onboardCompanionQuestion,
              style: TextStyle(color: h, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 350.ms),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(right: 48, bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.local_gas_station, color: h, size: 14),
                  const SizedBox(width: 6),
                  Text(l.onboardCompanionFuelStation, style: TextStyle(color: h, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                Text(l.onboardCompanionFuelAdvice, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ).animate(delay: 500.ms).fadeIn(duration: 400.ms),
        // Live dashboard strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: h.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _DashStat(label: 'ETA', value: '17:43', color: h),
              _DashStat(label: l.onboardCompanionNextStop, value: '42 km', color: h),
              _DashStat(label: l.onboardCompanionTank, value: '68%', color: h),
            ],
          ),
        ).animate(delay: 800.ms).fadeIn(duration: 350.ms),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.android, size: 14, color: h),
            const SizedBox(width: 6),
            Text('Android Auto', style: TextStyle(color: h.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ).animate(delay: 1000.ms).fadeIn(duration: 300.ms),
      ],
    );
  }
}

class _DashStat extends StatelessWidget {
  const _DashStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          Text(label, style: TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      );
}
