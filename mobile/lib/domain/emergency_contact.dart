import 'package:flutter/foundation.dart';

/// One person to notify on crash detection. Up to 3 persisted in
/// AppPrefs (JSON list). The name is display-only; the phone
/// number is what actually receives the SMS.
@immutable
class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.phoneE164,
  });

  /// Display name (e.g. "Ana — pareja").
  final String name;

  /// Phone number in E.164 format (+34612345678). The SMS
  /// dispatcher expects this so we skip local dialling rules.
  final String phoneE164;

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phoneE164,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> j) =>
      EmergencyContact(
        name: j['name'] as String,
        phoneE164: j['phone'] as String,
      );
}
