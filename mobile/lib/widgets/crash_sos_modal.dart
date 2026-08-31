import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/tokens.dart';
import '../domain/emergency_contact.dart';
import '../l10n/app_localizations.dart';
import '../services/crash_detector.dart';

/// Modal shown after `CrashDetector` fires. Semi-auto SOS:
/// - 15 s countdown that the driver can cancel with a huge
///   "Estoy bien" button. If it reaches zero without cancellation,
///   an SMS is auto-dispatched to every configured emergency
///   contact with the impact GPS URL.
/// - A separate "LLAMAR 112" button is always visible. Tapping
///   it opens the phone dialer pre-filled with 112 — the driver
///   confirms the actual call. This is the semi-auto compromise:
///   SMS is auto (low regulatory risk), call is manual (avoids
///   fines for false 112).
///
/// After the countdown the modal STAYS open (the driver may
/// still need to call 112). Dismissal is via the "cerrar" tile
/// footer, but only after countdown or after user pressed OK.
class CrashSosModal extends StatefulWidget {
  const CrashSosModal({
    super.key,
    required this.event,
    required this.contacts,
    this.countdownSeconds = 15,
  });

  final CrashEvent event;
  final List<EmergencyContact> contacts;
  final int countdownSeconds;

  static Future<void> show(
    BuildContext context, {
    required CrashEvent event,
    required List<EmergencyContact> contacts,
  }) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useSafeArea: false,
        builder: (_) => CrashSosModal(
          event: event,
          contacts: contacts,
        ),
      );

  @override
  State<CrashSosModal> createState() => _CrashSosModalState();
}

class _CrashSosModalState extends State<CrashSosModal> {
  late int _remaining;
  Timer? _timer;
  bool _cancelled = false;
  bool _smsSent = false;
  String? _dispatchNote;

  @override
  void initState() {
    super.initState();
    _remaining = widget.countdownSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _remaining -= 1);
      if (_remaining <= 0) {
        _timer?.cancel();
        _dispatchSms();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _dispatchSms() async {
    if (_smsSent) return;
    _smsSent = true;
    final l = AppLocalizations.of(context);
    if (widget.contacts.isEmpty) {
      setState(() => _dispatchNote = l.sosNoContacts);
      return;
    }
    final lat = widget.event.lat;
    final lon = widget.event.lon;
    final mapsUrl = (lat != null && lon != null)
        ? 'https://www.google.com/maps?q=$lat,$lon'
        : '(location unavailable)';
    final body = Uri.encodeComponent(
      '${l.sosSmsPrefix}\n$mapsUrl',
    );
    // Comma-joined numbers → Android opens the SMS composer with
    // all recipients. Not silent (Android restricts silent SMS)
    // but the driver already had 15 s to cancel.
    final numbers = widget.contacts.map((c) => c.phoneE164).join(',');
    final uri = Uri.parse('sms:$numbers?body=$body');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      setState(() => _dispatchNote =
          l.sosSmsDispatched(widget.contacts.length));
    } catch (_) {
      setState(() => _dispatchNote = l.sosSmsFailed);
    }
  }

  void _cancel() {
    setState(() {
      _cancelled = true;
      _timer?.cancel();
    });
  }

  Future<void> _call112() async {
    final uri = Uri.parse('tel:112');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _close() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Material(
      color: Colors.black.withValues(alpha: 0.9),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 72, color: scheme.error),
              const SizedBox(height: Tokens.space16),
              Text(
                l.sosTitle,
                textAlign: TextAlign.center,
                style: t.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: Tokens.space8),
              Text(
                l.sosBody(
                  widget.event.peakG.toStringAsFixed(1),
                  widget.event.speedDropKmh.toStringAsFixed(0),
                ),
                textAlign: TextAlign.center,
                style: t.bodyLarge?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: Tokens.space32),
              if (!_cancelled && _remaining > 0) ...[
                Text(
                  l.sosCountdown(_remaining),
                  textAlign: TextAlign.center,
                  style: t.displayLarge?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: Tokens.space16),
                FilledButton(
                  onPressed: _cancel,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(72),
                    textStyle: t.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  child: Text(l.sosImOk),
                ),
              ] else ...[
                if (_cancelled)
                  Text(
                    l.sosCancelled,
                    textAlign: TextAlign.center,
                    style: t.headlineSmall
                        ?.copyWith(color: Colors.white70),
                  ),
                if (_dispatchNote != null) ...[
                  const SizedBox(height: Tokens.space12),
                  Text(
                    _dispatchNote!,
                    textAlign: TextAlign.center,
                    style: t.bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ],
              const Spacer(),
              FilledButton.icon(
                onPressed: _call112,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(72),
                  textStyle: t.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                icon: const Icon(Icons.phone, size: 32),
                label: Text(l.sosCall112),
              ),
              if (_cancelled || _remaining <= 0) ...[
                const SizedBox(height: Tokens.space16),
                TextButton(
                  onPressed: _close,
                  child: Text(
                    l.sosClose,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
              const SizedBox(height: Tokens.space16),
            ],
          ),
        ),
      ),
    );
  }
}
