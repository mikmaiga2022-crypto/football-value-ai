/// Utilisateur tel que renvoyé par l'API. Aucune donnée sensible n'est conservée.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.permissions,
    this.displayName,
    this.locale = 'fr',
    this.timezone = 'Africa/Ouagadougou',
  });

  final String id;
  final String email;
  final String role;
  final List<String> permissions;
  final String? displayName;
  final String locale;
  final String timezone;

  String get shortName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return email.split('@').first;
  }

  bool can(String permission) =>
      permissions.contains('*') || permissions.contains(permission);

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String? ?? 'user',
      permissions: (json['permissions'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      displayName: json['display_name'] as String?,
      locale: json['locale'] as String? ?? 'fr',
      timezone: json['timezone'] as String? ?? 'Africa/Ouagadougou',
    );
  }
}

/// Réponse d'authentification : jetons + profil.
class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final AppUser user;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 900,
      user: AppUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
    );
  }
}
