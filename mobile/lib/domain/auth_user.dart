import 'package:flutter/foundation.dart';

/// Authenticated user, mirrored from the backend `UserOut` schema.
@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.provider,
  });

  final String id;
  final String email;
  final String displayName;
  final String provider;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'provider': provider,
      };

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String,
        provider: json['provider'] as String,
      );
}
