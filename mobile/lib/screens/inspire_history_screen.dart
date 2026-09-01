import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../storage/inspiration_storage.dart';

/// Full history of auto-saved Trip Inspiration itineraries.
/// Reachable from Settings → "Mis planes IA". Tapping a row
/// restores the itinerary in a new InspireScreen instance so
/// the user can convert it to a real plan, edit the prompt to
/// regenerate, or share.
class InspireHistoryScreen extends ConsumerStatefulWidget {
  const InspireHistoryScreen({super.key});

  @override
  ConsumerState<InspireHistoryScreen> createState() =>
      _InspireHistoryScreenState();
}

class _InspireHistoryScreenState
    extends ConsumerState<InspireHistoryScreen> {
  late List<SavedInspiration> _entries;

  @override
  void initState() {
    super.initState();
    _entries = ref.read(inspirationStorageProvider).list();
  }

  Future<void> _delete(SavedInspiration e) async {
    await ref.read(inspirationStorageProvider).remove(e.id);
    setState(() {
      _entries =
          ref.read(inspirationStorageProvider).list();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat.yMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).add_Hm();
    return Scaffold(
      appBar: AppBar(title: Text(l.inspireHistoryTitle)),
      body: _entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Tokens.space24),
                child: Text(
                  l.inspireHistoryEmpty,
                  style: t.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: Tokens.space8),
              itemCount: _entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = _entries[i];
                return ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: Text(
                    e.prompt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${e.itinerary.days.length}d · ${dateFmt.format(e.savedAt.toLocal())}',
                  ),
                  trailing: IconButton(
                    tooltip: l.inspireHistoryDelete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(e),
                  ),
                );
              },
            ),
    );
  }
}
