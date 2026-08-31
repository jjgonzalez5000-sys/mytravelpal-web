import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../domain/emergency_contact.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';

/// Manage up to 3 emergency contacts that receive an SMS with the
/// impact location when the Companion detects a crash. Simple
/// list + add/remove — no phone-book picker (would require an
/// extra plugin + permission for MVP).
class EmergencyContactsScreen extends ConsumerStatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  ConsumerState<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState
    extends ConsumerState<EmergencyContactsScreen> {
  late List<EmergencyContact> _contacts;

  @override
  void initState() {
    super.initState();
    _contacts = List.from(ref.read(appPrefsProvider).emergencyContacts);
  }

  Future<void> _save() async {
    await ref
        .read(appPrefsProvider)
        .setEmergencyContacts(_contacts);
  }

  Future<void> _add() async {
    if (_contacts.length >= 3) return;
    final added = await showDialog<EmergencyContact>(
      context: context,
      builder: (_) => const _AddContactDialog(),
    );
    if (added == null) return;
    setState(() => _contacts = [..._contacts, added]);
    await _save();
  }

  /// Ask the OS for READ_CONTACTS, load the address book, let the
  /// user pick one, then normalise the selected phone to E.164 and
  /// save. Handles: denied permission (falls back to snackbar +
  /// keeps manual entry available), contact with no number
  /// (message + return), contact with multiple numbers (ask which).
  Future<void> _pickFromContacts() async {
    if (_contacts.length >= 3) return;
    final l = AppLocalizations.of(context);
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.emergencyContactsPermDenied)),
      );
      return;
    }
    // withProperties gets phone numbers; withPhoto stays false to
    // keep the fetch small.
    final all = await FlutterContacts.getContacts(
      withProperties: true, withPhoto: false,
    );
    if (!mounted) return;
    final withPhone = all.where((c) => c.phones.isNotEmpty).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    if (withPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.emergencyContactsNoDevice)),
      );
      return;
    }
    final picked = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ContactPickerSheet(contacts: withPhone),
    );
    if (!mounted || picked == null) return;
    String? phone;
    if (picked.phones.length == 1) {
      phone = picked.phones.first.number;
    } else {
      phone = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => _PhonePickerSheet(contact: picked),
      );
    }
    if (!mounted || phone == null) return;
    final normalized = _toE164(phone);
    if (normalized == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.emergencyContactPhoneInvalid)),
      );
      return;
    }
    final entry = EmergencyContact(
      name: picked.displayName.trim().isEmpty
          ? l.emergencyContactName
          : picked.displayName.trim(),
      phoneE164: normalized,
    );
    setState(() => _contacts = [..._contacts, entry]);
    await _save();
  }

  /// Best-effort E.164 normalisation. Real phone-number parsing
  /// belongs in `libphonenumber`, but we don't want the extra
  /// binary for the beta. This handles the two dominant cases:
  ///   * already E.164 (starts with +, digits only) -> keep
  ///   * local starting with 0 in the user's default region ->
  ///     drop the 0 and prepend the region code guessed from
  ///     device locale (fallback +34 for Spanish testers).
  String? _toE164(String raw) {
    final trimmed = raw.replaceAll(RegExp(r'[\s()\-.]'), '');
    if (RegExp(r'^\+\d{6,15}$').hasMatch(trimmed)) return trimmed;
    if (RegExp(r'^0?\d{6,15}$').hasMatch(trimmed)) {
      final digits = trimmed.replaceFirst(RegExp(r'^0'), '');
      final region = _guessRegion();
      return '+$region$digits';
    }
    return null;
  }

  String _guessRegion() {
    final code = Localizations.localeOf(context).countryCode
        ?? Localizations.localeOf(context).languageCode.toUpperCase();
    return switch (code.toUpperCase()) {
      'ES' => '34',
      'FR' => '33',
      'DE' => '49',
      'IT' => '39',
      'PT' => '351',
      'GB' => '44',
      'US' => '1',
      _ => '34',
    };
  }

  Future<void> _remove(int i) async {
    setState(() => _contacts = [..._contacts]..removeAt(i));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.emergencyContactsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.space20),
        children: [
          Text(
            l.emergencyContactsBody,
            style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Tokens.space24),
          if (_contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Tokens.space24),
              child: Center(
                child: Text(l.emergencyContactsEmpty,
                    style: t.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            )
          else
            for (var i = 0; i < _contacts.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: Tokens.space8),
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(_contacts[i].name),
                  subtitle: Text(_contacts[i].phoneE164),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(i),
                  ),
                ),
              ),
          const SizedBox(height: Tokens.space16),
          if (_contacts.length < 3) ...[
            FilledButton.icon(
              onPressed: _pickFromContacts,
              icon: const Icon(Icons.contacts_outlined),
              label: Text(l.emergencyContactsPickFromDevice),
            ),
            const SizedBox(height: Tokens.space8),
            OutlinedButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(l.emergencyContactsAdd),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactPickerSheet extends StatefulWidget {
  const _ContactPickerSheet({required this.contacts});
  final List<Contact> contacts;
  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.contacts
        : widget.contacts.where((c) =>
            c.displayName.toLowerCase().contains(q)).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(Tokens.space16),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    labelText: l.emergencyContactsPickSearch,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    return ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(c.displayName),
                      subtitle: c.phones.isNotEmpty
                          ? Text(c.phones.first.number)
                          : null,
                      onTap: () => Navigator.of(context).pop(c),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhonePickerSheet extends StatelessWidget {
  const _PhonePickerSheet({required this.contact});
  final Contact contact;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(Tokens.space16),
            child: Text(contact.displayName,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final p in contact.phones)
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: Text(p.number),
              subtitle: Text(p.label.name),
              onTap: () => Navigator.of(context).pop(p.number),
            ),
        ],
      ),
    );
  }
}

class _AddContactDialog extends StatefulWidget {
  const _AddContactDialog();

  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController(text: '+34');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.emergencyContactAddTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtl,
              decoration: InputDecoration(labelText: l.emergencyContactName),
              validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? l.emergencyContactNameRequired
                      : null,
            ),
            const SizedBox(height: Tokens.space12),
            TextFormField(
              controller: _phoneCtl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l.emergencyContactPhone,
                helperText: '+34612345678',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return l.emergencyContactPhoneRequired;
                }
                if (!RegExp(r'^\+\d{6,15}$').hasMatch(v.trim())) {
                  return l.emergencyContactPhoneInvalid;
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.of(context).pop(EmergencyContact(
              name: _nameCtl.text.trim(),
              phoneE164: _phoneCtl.text.trim(),
            ));
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
