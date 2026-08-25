import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Ask the user to name a place they want to save (Home / Work / Custom).
///
/// Returns the chosen label, or null if the user cancelled. The suggested
/// display name is shown as context so they know what they're naming.
Future<String?> showSavePlaceDialog(
  BuildContext context, {
  required String suggested,
}) async {
  final l = AppLocalizations.of(context);
  final controller = TextEditingController();
  final presets = <String>[
    l.placePresetHome,
    l.placePresetWork,
    l.placePresetSchool,
    l.placePresetGym,
  ];

  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(l.placeSaveDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              suggested,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final preset in presets)
                  ActionChip(
                    label: Text(preset),
                    onPressed: () => Navigator.of(context).pop(preset),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.placeCustomLabel,
                hintText: l.placeCustomHint,
              ),
              onSubmitted: (v) {
                final trimmed = v.trim();
                if (trimmed.isNotEmpty) Navigator.of(context).pop(trimmed);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) Navigator.of(context).pop(trimmed);
            },
            child: Text(l.commonSave),
          ),
        ],
      );
    },
  );
}
