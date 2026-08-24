import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/components.dart';
import '../design/tokens.dart';
import '../providers.dart';
import 'plan_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = <_OnboardingSlide>[
    _OnboardingSlide(
      icon: Icons.schedule,
      eyebrow: 'THE MISSING FEATURE',
      title: 'Leave at the right time',
      body:
          'We look at historic traffic around your desired departure and '
          'show you the sweet spot — sometimes leaving 30 minutes earlier '
          'saves you 90.',
    ),
    _OnboardingSlide(
      icon: Icons.route_outlined,
      eyebrow: 'HONEST PLANNING',
      title: 'Every cost, up front',
      body:
          'Toll totals, cheapest fuel and EV charging along the route, '
          'suggested stops, and hotels or restaurants at the exact detour '
          'you can afford.',
    ),
    _OnboardingSlide(
      icon: Icons.warning_amber_outlined,
      eyebrow: 'STAY AWARE',
      title: 'Alerts that matter',
      body:
          'Fires, strikes, adverse weather, roadworks — you decide when we '
          'surface them, and only when they actually touch your route.',
    ),
  ];

  Future<void> _finish() async {
    await ref.read(appPrefsProvider).markOnboardingShown();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const PlanScreen()),
    );
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: Tokens.motionBase,
      curve: Tokens.curveOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  right: Tokens.space16, top: Tokens.space8,
                ),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(isLast ? '' : 'Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Tokens.space24),
              child: Column(
                children: [
                  _Dots(count: _slides.length, active: _page),
                  const SizedBox(height: Tokens.space24),
                  PrimaryCta(
                    label: isLast ? 'Get started' : 'Continue',
                    icon: isLast ? Icons.arrow_forward : null,
                    onPressed: _next,
                  ),
                  const SizedBox(height: Tokens.space8),
                  Text(
                    'Free to start · Premium unlocks the AI trip briefing',
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.space32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(Tokens.radiusXl),
            ),
            child: Icon(slide.icon, size: 44, color: scheme.onPrimaryContainer),
          )
              .animate(key: ValueKey(slide.title))
              .fadeIn(duration: Tokens.motionBase)
              .moveY(begin: 8, end: 0, curve: Tokens.curveOut),
          const SizedBox(height: Tokens.space32),
          Text(
            slide.eyebrow,
            style: t.labelSmall?.copyWith(
              color: scheme.tertiary, letterSpacing: 1.2,
            ),
          )
              .animate(key: ValueKey('${slide.title}-eyebrow'))
              .fadeIn(delay: 60.ms, duration: Tokens.motionBase),
          const SizedBox(height: Tokens.space8),
          Text(slide.title, style: t.displayMedium)
              .animate(key: ValueKey('${slide.title}-title'))
              .fadeIn(delay: 120.ms, duration: Tokens.motionBase)
              .moveY(begin: 8, end: 0, curve: Tokens.curveOut),
          const SizedBox(height: Tokens.space16),
          Text(
            slide.body,
            style: t.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          )
              .animate(key: ValueKey('${slide.title}-body'))
              .fadeIn(delay: 200.ms, duration: Tokens.motionBase),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});
  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Tokens.motionBase,
            curve: Tokens.curveOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 6,
            width: i == active ? 24 : 6,
            decoration: BoxDecoration(
              color: i == active ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(Tokens.radiusPill),
            ),
          ),
      ],
    );
  }
}
