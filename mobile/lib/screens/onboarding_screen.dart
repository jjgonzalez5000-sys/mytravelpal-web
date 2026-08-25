import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/components.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'login_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  List<_OnboardingSlide> _slides(AppLocalizations l) => [
        _OnboardingSlide(
          icon: Icons.schedule,
          eyebrow: l.onboardEyebrowKiller,
          title: l.onboardTitleKiller,
          body: l.onboardBodyKiller,
        ),
        _OnboardingSlide(
          icon: Icons.route_outlined,
          eyebrow: l.onboardEyebrowHonest,
          title: l.onboardTitleHonest,
          body: l.onboardBodyHonest,
        ),
        _OnboardingSlide(
          icon: Icons.warning_amber_outlined,
          eyebrow: l.onboardEyebrowAlerts,
          title: l.onboardTitleAlerts,
          body: l.onboardBodyAlerts,
        ),
      ];

  Future<void> _finish() async {
    await ref.read(appPrefsProvider).markOnboardingShown();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  void _next(int slideCount) {
    if (_page == slideCount - 1) {
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
    final l = AppLocalizations.of(context);
    final slides = _slides(l);
    final isLast = _page == slides.length - 1;

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
                  child: Text(isLast ? '' : l.onboardSkip),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: slides.length,
                itemBuilder: (context, i) => _SlideView(slide: slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Tokens.space24),
              child: Column(
                children: [
                  _Dots(count: slides.length, active: _page),
                  const SizedBox(height: Tokens.space24),
                  PrimaryCta(
                    label: isLast ? l.onboardGetStarted : l.onboardContinue,
                    icon: isLast ? Icons.arrow_forward : null,
                    onPressed: () => _next(slides.length),
                  ),
                  const SizedBox(height: Tokens.space8),
                  Text(l.onboardFooter, style: t.bodySmall),
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
