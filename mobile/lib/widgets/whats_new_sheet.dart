import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import 'feedback_sheet.dart';

/// Bottomsheet that renders the release notes returned by
/// `WhatsNewService.resolveChangelogFor`. Markdown-lite: parses
/// `## ` headings, `- ` bullets, `**bold**`, `---` separators. No
/// hyperlinks / images / tables — release notes stay short so a
/// richer parser isn't worth the pubspec bloat.
Future<void> showWhatsNewSheet(
  BuildContext context, {
  required String body,
  required VoidCallback onDismiss,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Tokens.radiusXl)),
    ),
    builder: (_) => _WhatsNewSheet(body: body),
  );
  onDismiss();
}

class _WhatsNewSheet extends StatelessWidget {
  const _WhatsNewSheet({required this.body});
  final String body;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.80),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.space20, Tokens.space12, Tokens.space20, Tokens.space16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: Tokens.space12),
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: scheme.primary),
                  const SizedBox(width: Tokens.space8),
                  Expanded(
                    child: Text(
                      l.whatsNewSheetTitle,
                      style: t.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Tokens.space12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _renderMarkdownLite(body, t, scheme),
                  ),
                ),
              ),
              const SizedBox(height: Tokens.space16),
              // Two-action row: the primary dismisses the sheet, the
              // secondary opens the feedback sheet so a user with
              // "hey, and could you also…" reactions has a direct
              // outlet the same tap after reading the changelog.
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await showFeedbackSheet(context);
                      },
                      icon: const Icon(Icons.lightbulb_outline, size: 18),
                      label: Text(l.whatsNewSheetSuggest),
                    ),
                  ),
                  const SizedBox(width: Tokens.space8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l.whatsNewSheetDismiss),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Very small markdown-lite renderer. Enough for the release notes
/// shape we ship (headings, bullets, bold, horizontal rules); adding
/// a full markdown package would be overkill for these files.
List<Widget> _renderMarkdownLite(
  String md,
  TextTheme t,
  ColorScheme scheme,
) {
  final out = <Widget>[];
  for (final rawLine in md.split('\n')) {
    final line = rawLine.trimRight();
    if (line.isEmpty) {
      out.add(const SizedBox(height: 6));
      continue;
    }
    if (line.startsWith('## ')) {
      if (out.isNotEmpty) out.add(const SizedBox(height: 12));
      out.add(Text(
        line.substring(3),
        style: t.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
      ));
      out.add(const SizedBox(height: 6));
      continue;
    }
    if (line == '---') {
      out.add(const SizedBox(height: 12));
      out.add(Divider(color: scheme.outlineVariant));
      out.add(const SizedBox(height: 12));
      continue;
    }
    if (line.startsWith('- ')) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Container(
                width: 4, height: 4,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Expanded(
              child: RichText(
                text: _bolded(line.substring(2), t, scheme),
              ),
            ),
          ],
        ),
      ));
      continue;
    }
    out.add(Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: RichText(text: _bolded(line, t, scheme)),
    ));
  }
  return out;
}

TextSpan _bolded(String line, TextTheme t, ColorScheme scheme) {
  final baseStyle = t.bodyMedium?.copyWith(color: scheme.onSurface);
  final spans = <TextSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*');
  var cursor = 0;
  for (final match in pattern.allMatches(line)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: line.substring(cursor, match.start)));
    }
    spans.add(TextSpan(
      text: match.group(1),
      style: baseStyle?.copyWith(fontWeight: FontWeight.w700),
    ));
    cursor = match.end;
  }
  if (cursor < line.length) {
    spans.add(TextSpan(text: line.substring(cursor)));
  }
  return TextSpan(style: baseStyle, children: spans);
}
