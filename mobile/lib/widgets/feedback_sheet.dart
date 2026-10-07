import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';

/// Bottomsheet where the user drops a free-form suggestion + optional
/// screenshots. Sends through `ApiClient.submitFeedback` — body text +
/// app version + locale + optional reply email + up to 3 base64 images.
/// User id is attached automatically via the auth JWT.
///
/// Success = "gracias" snackbar; failure = "no pudimos enviarlo,
/// vuelve a intentarlo" without dismissing the sheet so the driver
/// doesn't lose their text.
Future<void> showFeedbackSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(Tokens.radiusXl),
      ),
    ),
    builder: (_) => const _FeedbackSheet(),
  );
}

class _FeedbackSheet extends ConsumerStatefulWidget {
  const _FeedbackSheet();

  @override
  ConsumerState<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<_FeedbackSheet> {
  final _bodyController = TextEditingController();
  final _emailController = TextEditingController();
  bool _wantsReply = false;
  bool _sending = false;
  String? _error;
  final List<XFile> _attachments = [];
  static const _maxAttachments = 3;

  @override
  void dispose() {
    _bodyController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_attachments.length >= _maxAttachments) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (picked != null && mounted) {
      setState(() => _attachments.add(picked));
    }
  }

  Future<void> _send() async {
    final body = _bodyController.text.trim();
    if (body.length < 3) {
      setState(() => _error = AppLocalizations.of(context).feedbackErrorEmpty);
      return;
    }
    final email = _wantsReply ? _emailController.text.trim() : null;
    if (email != null && email.isNotEmpty && !email.contains('@')) {
      setState(() => _error = AppLocalizations.of(context).feedbackErrorEmail);
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      // Encode attachments as base64 strings.
      final List<String> attachmentB64 = [];
      for (final f in _attachments) {
        final bytes = await File(f.path).readAsBytes();
        attachmentB64.add(base64Encode(bytes));
      }

      final api = ref.read(apiClientWithPremiumProvider);
      final locale = Localizations.localeOf(context).languageCode;
      const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'unknown');
      await api.submitFeedback(
        bodyText: body,
        appVersion: appVersion,
        locale: locale,
        replyEmail: (email != null && email.isNotEmpty) ? email : null,
        attachments: attachmentB64,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).feedbackThanks)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = '${AppLocalizations.of(context).feedbackErrorSend} (${e.statusCode})';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = AppLocalizations.of(context).feedbackErrorSend;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          left: Tokens.space20,
          right: Tokens.space20,
          top: Tokens.space12,
          bottom: Tokens.space16 + bottomInset,
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
                Icon(Icons.lightbulb_outline, color: scheme.primary),
                const SizedBox(width: Tokens.space8),
                Expanded(
                  child: Text(
                    l.feedbackSheetTitle,
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space8),
            Text(
              l.feedbackSheetSubtitle,
              style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Tokens.space16),
            TextField(
              controller: _bodyController,
              maxLines: 5,
              minLines: 3,
              maxLength: 4000,
              enabled: !_sending,
              decoration: InputDecoration(
                hintText: l.feedbackBodyHint,
                border: const OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: Tokens.space12),
            // Screenshot attachments row
            Row(
              children: [
                Text(
                  'Pantallazos (${_attachments.length}/$_maxAttachments)',
                  style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: Tokens.space8),
                for (final f in _attachments)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(f.path),
                            width: 44, height: 44, fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: -4, top: -4,
                          child: GestureDetector(
                            onTap: () => setState(() => _attachments.remove(f)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: scheme.error,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close, size: 10, color: scheme.onError),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_attachments.length < _maxAttachments)
                  InkWell(
                    onTap: _sending ? null : _pickImage,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: scheme.outlineVariant,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Tokens.space8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _wantsReply,
              onChanged: _sending ? null : (v) => setState(() => _wantsReply = v ?? false),
              title: Text(l.feedbackWantReply),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            if (_wantsReply) ...[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_sending,
                decoration: InputDecoration(
                  hintText: l.feedbackEmailHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Tokens.space8),
            ],
            if (_error != null) ...[
              const SizedBox(height: Tokens.space8),
              Text(_error!, style: t.bodySmall?.copyWith(color: scheme.error)),
            ],
            const SizedBox(height: Tokens.space16),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(l.feedbackSendButton),
            ),
          ],
        ),
      ),
    );
  }
}
