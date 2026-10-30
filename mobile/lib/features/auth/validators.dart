/// Validations locales, miroir des contraintes serveur (docs/04 §2).
/// Le serveur reste l'autorité : ces règles évitent un aller-retour inutile.
library;

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Saisissez votre adresse e-mail.';
  final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  return valid ? null : 'Adresse e-mail invalide.';
}

String? validateLoginPassword(String? value) {
  if (value == null || value.isEmpty) return 'Saisissez votre mot de passe.';
  return null;
}

String? validateNewPassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Choisissez un mot de passe.';
  if (password.length < 10) return 'Au moins 10 caractères.';
  return null;
}

String? validateDisplayName(String? value) {
  final name = value?.trim() ?? '';
  if (name.length > 40) return '40 caractères maximum.';
  return null;
}
