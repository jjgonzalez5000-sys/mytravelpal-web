import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../widgets/skeleton.dart';

/// Renders the attribution catalogue served by `GET /v1/attributions`
/// grouped by section, plus a link into Flutter's built-in
/// `showLicensePage()` for the exhaustive package-license list.
///
/// The screen fulfils two obligations at once:
/// - **Legal**: ODbL, CC-BY and Etalab-2.0 all require the mention
///   text to be reachable from the running app. Rendering the strings
///   here (`attribution_text`) with a tap-through to the licence URL
///   discharges that duty.
/// - **Product**: gives credit where it's due so contributors see
///   their work acknowledged.
class AttributionsScreen extends ConsumerStatefulWidget {
  const AttributionsScreen({super.key});

  @override
  ConsumerState<AttributionsScreen> createState() =>
      _AttributionsScreenState();
}

class _AttributionsScreenState extends ConsumerState<AttributionsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() =>
      ref.read(apiClientProvider).attributions();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.attributionsTitle)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            // Skeleton list — 5 grouped tiles preserve the shape
            // of the eventual attribution cards.
            return const _AttributionsSkeleton();
          }
          if (snap.hasError || snap.data == null) {
            return _ErrorState(
              message: l.attributionsFailed,
              onRetry: () => setState(() => _future = _load()),
            );
          }
          return _AttributionsList(items: snap.data!);
        },
      ),
    );
  }
}

class _AttributionsList extends StatelessWidget {
  const _AttributionsList({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    // Preserve backend order but group by `group`. Insertion-ordered
    // map so sections appear in the same sequence as they arrive.
    final byGroup = <String, List<Map<String, dynamic>>>{};
    for (final it in items) {
      final g = (it['group'] as String?) ?? 'other';
      byGroup.putIfAbsent(g, () => []).add(it);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space16, vertical: Tokens.space16,
      ),
      children: [
        Text(l.attributionsIntro, style: t.bodyMedium),
        const SizedBox(height: Tokens.space24),
        for (final entry in byGroup.entries) ...[
          _SectionHeader(title: _groupLabel(l, entry.key)),
          for (final it in entry.value) _AttributionCard(item: it),
          const SizedBox(height: Tokens.space16),
        ],
        const SizedBox(height: Tokens.space8),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'MyTravelPal',
              applicationVersion: '0.1.0',
            ),
            icon: const Icon(Icons.article_outlined),
            label: Text(l.attributionsShowLicenses),
          ),
        ),
        const SizedBox(height: Tokens.space24),
      ],
    );
  }

  String _groupLabel(AppLocalizations l, String group) => switch (group) {
        'map' => l.attributionsSectionMap,
        'fuel' => l.attributionsSectionFuel,
        'hazards' => l.attributionsSectionHazards,
        'weather' => l.attributionsSectionWeather,
        'software' => l.attributionsSectionSoftware,
        _ => group,
      };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          0, Tokens.space16, 0, Tokens.space8,
        ),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}

class _AttributionCard extends StatelessWidget {
  const _AttributionCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final url = item['url'] as String?;
    final required = item['attribution_required'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: Tokens.space8),
      child: InkWell(
        onTap: url == null
            ? null
            : () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      (item['name'] as String?) ?? '',
                      style: t.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (required)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.gavel,
                        size: 14,
                        color: scheme.tertiary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                (item['description'] as String?) ?? '',
                style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                (item['attribution_text'] as String?) ?? '',
                style: t.bodySmall,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.balance,
                      size: 12, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    (item['license'] as String?) ?? '',
                    style: t.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  if (url != null) ...[
                    const Spacer(),
                    Icon(Icons.open_in_new,
                        size: 12, color: scheme.primary),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton placeholder for the attributions list — one section
/// header, then a stack of tiles that echo `_AttributionCard`'s
/// title + description + license row.
class _AttributionsSkeleton extends StatelessWidget {
  const _AttributionsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space16, vertical: Tokens.space16,
      ),
      children: [
        Skeleton(
          width: double.infinity, height: 14,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 6),
        Skeleton(
          width: 220, height: 14,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: Tokens.space24),
        Skeleton(
          width: 100, height: 12,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: Tokens.space12),
        for (var i = 0; i < 5; i++) ...[
          Container(
            padding: const EdgeInsets.all(Tokens.space16),
            margin: const EdgeInsets.only(bottom: Tokens.space8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(
                  width: 180, height: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Skeleton(
                  width: double.infinity, height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                Skeleton(
                  width: 240, height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 10),
                Skeleton(
                  width: 120, height: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: Tokens.space16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
