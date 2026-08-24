import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../design/components.dart';
import '../design/tokens.dart';
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
    final place = _place;
    final description = _descriptionCtrl.text.trim();
    if (place == null || description.isEmpty) {
      setState(() => _error = 'Pick a place and describe what you saw.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).submitAdverseEvent(
            type: _type,
            severity: _severity,
            lat: place.coordinate.lat,
            lon: place.coordinate.lon,
            description: description,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted — thank you!')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = 'API error ${e.statusCode}');
    } catch (e) {
      setState(() => _error = 'Could not submit: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiClientProvider);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Report an event')),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.space20),
        children: [
          Text(
            'Help other drivers know what you saw. Reports expire after '
            '24 h.',
            style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Tokens.space24),
          const SectionHeader(title: 'What happened', eyebrow: 'Type'),
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
          const SectionHeader(title: 'Severity'),
          SoftCard(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.space16, vertical: Tokens.space8,
            ),
            child: SegmentedButton<AdverseEventSeverity>(
              segments: const [
                ButtonSegment(
                  value: AdverseEventSeverity.info,
                  label: Text('Info'),
                ),
                ButtonSegment(
                  value: AdverseEventSeverity.warning,
                  label: Text('Warning'),
                ),
                ButtonSegment(
                  value: AdverseEventSeverity.critical,
                  label: Text('Critical'),
                ),
              ],
              selected: {_severity},
              onSelectionChanged: (s) => setState(() => _severity = s.first),
            ),
          ),
          const SizedBox(height: Tokens.space24),
          const SectionHeader(title: 'Where', eyebrow: 'Nearest city'),
          LocationSearchField(
            label: 'Location',
            geocode: api.geocode,
            onSelected: (r) => setState(() => _place = r),
            initial: _place,
          ),
          const SizedBox(height: Tokens.space24),
          const SectionHeader(title: 'Describe it', eyebrow: 'Short & useful'),
          SoftCard(
            padding: const EdgeInsets.all(Tokens.space12),
            child: TextField(
              controller: _descriptionCtrl,
              minLines: 2, maxLines: 5,
              maxLength: 280,
              decoration: const InputDecoration(
                hintText: 'e.g. Trees down on A6 southbound, 2 lanes closed',
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
            label: _submitting ? 'Submitting…' : 'Submit report',
            icon: _submitting ? null : Icons.send,
            loading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
