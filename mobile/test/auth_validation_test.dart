import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_value_ai/features/auth/login_screen.dart';
import 'package:football_value_ai/features/auth/register_screen.dart';

import 'support/fixtures.dart';

/// Session locale qui enregistre l'appel sans toucher au réseau ni au Keystore.
class _RecordingSession extends LoggedOutTestSession {
  String? loginEmail;
  String? registerEmail;
  String? registerDisplayName;

  @override
  Future<bool> login({required String email, required String password}) async {
    loginEmail = email;
    return true;
  }

  @override
  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    registerEmail = email;
    registerDisplayName = displayName;
    return true;
  }
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, value);
  await tester.pump();
}

void main() {
  group('Connexion', () {
    testWidgets('un formulaire vide affiche les deux erreurs locales',
        (tester) async {
      final session = _RecordingSession();
      await pumpApp(
        tester,
        buildIsolatedScreen(
          child: const LoginScreen(),
          session: () => session,
        ),
      );

      await _tapVisible(tester, find.byKey(const ValueKey('login-submit')));

      expect(find.text('Saisissez votre adresse e-mail.'), findsOneWidget);
      expect(find.text('Saisissez votre mot de passe.'), findsOneWidget);
      expect(session.loginEmail, isNull);
    });

    testWidgets('une adresse invalide est refusée avant tout appel réseau',
        (tester) async {
      final session = _RecordingSession();
      await pumpApp(
        tester,
        buildIsolatedScreen(
          child: const LoginScreen(),
          session: () => session,
        ),
      );

      await _fill(tester, 'login-email', 'alex@');
      await _fill(tester, 'login-password', 'motdepasse');
      await _tapVisible(tester, find.byKey(const ValueKey('login-submit')));

      expect(find.text('Adresse e-mail invalide.'), findsOneWidget);
      expect(session.loginEmail, isNull);
    });

    testWidgets('des identifiants valides déclenchent la connexion',
        (tester) async {
      final session = _RecordingSession();
      await pumpApp(
        tester,
        buildIsolatedScreen(
          child: const LoginScreen(),
          session: () => session,
        ),
      );

      await _fill(tester, 'login-email', 'alex@exemple.com');
      await _fill(tester, 'login-password', 'motdepasse');
      await _tapVisible(tester, find.byKey(const ValueKey('login-submit')));

      expect(session.loginEmail, 'alex@exemple.com');
    });
  });

  group('Inscription', () {
    testWidgets('un formulaire vide liste les champs et l’avertissement légal',
        (tester) async {
      final session = _RecordingSession();
      await pumpApp(
        tester,
        buildIsolatedScreen(
          child: const RegisterScreen(),
          session: () => session,
        ),
      );

      await _tapVisible(tester, find.byKey(const ValueKey('register-submit')));

      expect(find.text('Saisissez votre adresse e-mail.'), findsOneWidget);
      expect(find.text('Choisissez un mot de passe.'), findsOneWidget);
      expect(find.text('Confirmez le mot de passe.'), findsOneWidget);
      expect(
        find.text('Vous devez accepter l’avertissement pour continuer.'),
        findsOneWidget,
      );
      expect(session.registerEmail, isNull);
    });

    testWidgets('un mot de passe trop court et une confirmation différente sont refusés',
        (tester) async {
      final session = _RecordingSession();
      await pumpApp(
        tester,
        buildIsolatedScreen(
          child: const RegisterScreen(),
          session: () => session,
        ),
      );

      await _fill(tester, 'register-email', 'alex@exemple.com');
      await _fill(tester, 'register-password', 'court');
      await _fill(tester, 'register-confirm', 'autre');
      await _tapVisible(tester, find.byKey(const ValueKey('register-submit')));

      expect(find.text('Au moins 10 caractères.'), findsOneWidget);
      expect(find.text('Les mots de passe ne correspondent pas.'), findsOneWidget);
      expect(session.registerEmail, isNull);
    });

    testWidgets('avec l’avertissement accepté, l’inscription est transmise',
        (tester) async {
      final session = _RecordingSession();
      await pumpApp(
        tester,
        buildIsolatedScreen(
          child: const RegisterScreen(),
          session: () => session,
        ),
      );

      await _fill(tester, 'register-name', 'Alex');
      await _fill(tester, 'register-email', 'alex@exemple.com');
      await _fill(tester, 'register-password', 'motdepasse1');
      await _fill(tester, 'register-confirm', 'motdepasse1');
      await _tapVisible(tester, find.byKey(const ValueKey('register-terms')));
      expect(
        find.text('Vous devez accepter l’avertissement pour continuer.'),
        findsNothing,
      );
      await _tapVisible(tester, find.byKey(const ValueKey('register-submit')));

      expect(session.registerEmail, 'alex@exemple.com');
      expect(session.registerDisplayName, 'Alex');
    });
  });
}
