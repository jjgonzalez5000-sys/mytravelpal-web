import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../design/components.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';

class NarrativeScreen extends ConsumerStatefulWidget {
  const NarrativeScreen({
    super.key,
    required this.planRequest,
    required this.originName,
    required this.destinationName,
  });

  final TripPlanRequest planRequest;
  final String originName;
  final String destinationName;

  @override
  ConsumerState<NarrativeScreen> createState() => _NarrativeScreenState();
}

class _NarrativeScreenState extends ConsumerState<NarrativeScreen> {
  Future<NarrativeResponse>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Defer the initial load here (not initState) so
    // `Localizations.localeOf(context)` is safe — inherited widgets
    // aren't wired up in initState.
    _future ??= _load();
  }

  Future<NarrativeResponse> _load() {
    // Pass the current app locale so the LLM writes the narrative
    // in Spanish/French/German/etc. rather than defaulting to
    // English regardless of the user's Settings pick. Mirrors the
    // pattern used by geocode() / reverseGeocode().
    final locale = Localizations.localeOf(context).languageCode;
    return ref.read(apiClientWithPremiumProvider).tripNarrative(
          planRequest: widget.planRequest,
          originName: widget.originName,
          destinationName: widget.destinationName,
          locale: locale,
        );
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).narrativeTitle),
      ),
      body: FutureBuilder<NarrativeResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingState();
          }
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error!, onRetry: _retry);
          }
          return _NarrativeBody(
            data: snapshot.data!,
            origin: widget.originName,
            destination: widget.destinationName,
          );
        },
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(Tokens.radiusPill),
            ),
            child: Icon(Icons.auto_awesome,
                color: scheme.onPrimaryContainer, size: 28),
          )
              .animate(onPlay: (c) => c.repeat())
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.06, 1.06),
                duration: 800.ms,
                curve: Curves.easeInOut,
              )
              .then()
              .scale(
                begin: const Offset(1.06, 1.06),
                end: const Offset(1, 1),
                duration: 800.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: Tokens.space16),
          Text(AppLocalizations.of(context).narrativeBusy,
              style: t.bodyMedium),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.error_outline,
      title: l.narrativeErrorTitle,
      description: '$error',
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh, size: 18),
        label: Text(l.commonRetry),
      ),
    );
  }
}

class _NarrativeBody extends StatefulWidget {
  const _NarrativeBody({
    required this.data,
    required this.origin,
    required this.destination,
  });

  final NarrativeResponse data;
  final String origin;
  final String destination;

  @override
  State<_NarrativeBody> createState() => _NarrativeBodyState();
}

class _NarrativeBodyState extends State<_NarrativeBody> {
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;
  bool _ttsReady = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _tts.setStartHandler(() {
        if (mounted) setState(() => _speaking = true);
      });
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _speaking = false);
      });
      _tts.setCancelHandler(() {
        if (mounted) setState(() => _speaking = false);
      });
      _tts.setErrorHandler((_) {
        if (mounted) setState(() => _speaking = false);
      });
      if (mounted) setState(() => _ttsReady = true);
    } catch (e) {
      // Non-fatal; button just stays disabled.
      debugPrint('TTS init failed: $e');
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _toggleSpeak() async {
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
    } else {
      await _tts.speak(widget.data.narrative);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final dateFmt = DateFormat('d MMM y · HH:mm', l.localeName);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space24, Tokens.space16, Tokens.space24, Tokens.space32,
      ),
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 18, color: scheme.tertiary),
            const SizedBox(width: Tokens.space8),
            Text(
              l.narrativeTitle.toUpperCase(),
              style: t.labelSmall?.copyWith(
                color: scheme.tertiary,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            SoftBadge(
              label: l.narrativePremiumBadge,
              color: scheme.onPrimaryContainer,
              background: scheme.primaryContainer,
              borderColor: scheme.primary.withValues(alpha: 0.3),
            ),
          ],
        ).animate().fadeIn(duration: Tokens.motionBase),
        const SizedBox(height: Tokens.space12),
        Text(
          widget.origin,
          style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ).animate().fadeIn(delay: 60.ms, duration: Tokens.motionBase),
        Text('→ ${widget.destination}', style: t.displaySmall)
            .animate()
            .fadeIn(delay: 100.ms, duration: Tokens.motionBase)
            .moveY(begin: 6, end: 0, curve: Tokens.curveOut),
        const SizedBox(height: Tokens.space4),
        Row(
          children: [
            Text(
              l.narrativeGeneratedAt(
                dateFmt.format(widget.data.generatedAt.toLocal()),
              ),
              style: t.bodySmall,
            ),
            const Spacer(),
            if (_ttsReady)
              FilledButton.tonalIcon(
                onPressed: _toggleSpeak,
                icon: Icon(_speaking ? Icons.stop_rounded : Icons.play_arrow_rounded),
                label: Text(_speaking ? l.narrativeStop : l.narrativeReadAloud),
              ),
          ],
        ),
        const SizedBox(height: Tokens.space16),
        Divider(color: scheme.outlineVariant),
        const SizedBox(height: Tokens.space16),
        SelectableText(
          widget.data.narrative,
          style: t.bodyLarge?.copyWith(height: 1.6),
        )
            .animate()
            .fadeIn(delay: 160.ms, duration: Tokens.motionSlow),
      ],
    );
  }
}
