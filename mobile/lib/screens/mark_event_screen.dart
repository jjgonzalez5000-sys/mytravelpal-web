import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../design/components.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../widgets/location_search_field.dart';

/// Form for a user to submit an adverse event (fire/strike/roadwork/…)
/// they've spotted. Posts to `POST /v1/adverse-events`.
class MarkEventScreen extends ConsumerStatefulWidget {
  const MarkEventScreen({super.key});

  @override
  ConsumerState<MarkEventScreen> createState() => _MarkEventScreenState();
}

class _MarkEventScreenState extends ConsumerState<MarkEventScreen> {
  final _descriptionCtrl = TextEditingController();
  AdverseEventType _type = AdverseEventType.roadwork;
  AdverseEventSeverity _severity = AdverseEventSeverity.warning;
  GeocodeResult? _place;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final l = AppLocalizations.of(context);
    final place = _place;
    final description = _descriptionCtrl.text.trim();
    if (place == null || description.isEmpty) {
      setState(() => _error = l.eventPickPlace);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(apiClientWithPremiumProvider).submitAdverseEvent(
            type: _type,
            severity: _severity,
            lat: place.coordinate.lat,
            lon: place.coordinate.lon,
            description: description,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.eventThankYou)),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = 'API error ${e.statusCode}');
    } catch (e) {
      setState(() => _error = l.eventCouldNotSubmit('$e'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiClientWithPremiumProvider);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.eventReport)),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.space20),
        children: [
          Text(
            l.eventIntro,
            style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Tokens.space24),
          SectionHeader(
              title: l.eventWhatHappened, eyebrow: l.eventWhatHappenedEyebrow),
          SoftCard(
            padding: const EdgeInsets.all(Tokens.space16),
            child: Wrap(
              spacing: Tokens.space8,
              runSpacing: Tokens.space8,
              children: [
                for (final tp in AdverseEventType.values)
                  ChoiceChip(
                    selected: tp == _type,
                    avatar: Icon(tp.icon, size: 16),
                    label: Text(tp.displayName),
                    onSelected: (s) {
                      if (s) setState(() => _type = tp);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space24),
          SectionHeader(title: l.eventSeverity),
          SoftCard(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.space16, vertical: Tokens.space8,
            ),
            child: SegmentedButton<AdverseEventSeverity>(
              segments: [
                ButtonSegment(
                  value: AdverseEventSeverity.info,
                  label: Text(l.eventSeverityInfo),
                ),
                ButtonSegment(
                  value: AdverseEventSeverity.warning,
                  label: Text(l.eventSeverityWarning),
                ),
                ButtonSegment(
                  value: AdverseEventSeverity.critical,
                  label: Text(l.eventSeverityCritical),
                ),
              ],
              selected: {_severity},
              onSelectionChanged: (s) => setState(() => _severity = s.first),
            ),
          ),
          const SizedBox(height: Tokens.space24),
          SectionHeader(
              title: l.eventWhere, eyebrow: l.eventWhereEyebrow),
          LocationSearchField(
            label: l.eventLocation,
            geocode: api.geocode,
            onSelected: (r) => setState(() => _place = r),
            initial: _place,
          ),
          const SizedBox(height: Tokens.space24),
          SectionHeader(
              title: l.eventDescribeTitle, eyebrow: l.eventDescribeEyebrow),
          SoftCard(
            padding: const EdgeInsets.all(Tokens.space12),
            child: TextField(
              controller: _descriptionCtrl,
              minLines: 2, maxLines: 5,
              maxLength: 280,
              decoration: InputDecoration(
                hintText: l.eventDescribeHint,
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: Tokens.space24),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.space12),
              child: Text(_error!,
                  style: TextStyle(color: scheme.error)),
            ),
          PrimaryCta(
            label: _submitting ? l.eventSubmitting : l.eventSubmitReport,
            icon: _submitting ? null : Icons.send,
            loading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
