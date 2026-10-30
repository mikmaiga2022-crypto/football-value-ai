import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_value_ai/features/profile/profile_screen.dart';

import 'support/fixtures.dart';

/// Sélection courante de la barre de navigation principale.
int _selectedIndex(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('démarre sur Accueil avec exactement cinq onglets', (tester) async {
    await pumpApp(tester, buildTestApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in ['Accueil', 'Matchs', 'Value', 'Direct', 'Profil']) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
        reason: 'l’onglet $label doit exister',
      );
    }
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations.length,
      5,
    );
    expect(_selectedIndex(tester), 0);
  });

  testWidgets('Accueil affiche le vrai plan de couverture, sans donnée simulée',
      (tester) async {
    await pumpApp(tester, buildTestApp());

    expect(find.text('Bonjour, Alex'), findsOneWidget);
    expect(find.text('Serveur OK · API 1.0.0'), findsOneWidget);
    expect(find.text('Ligue 1'), findsOneWidget);
    expect(find.text('Premier League'), findsOneWidget);
    expect(find.text('CAN'), findsOneWidget);
    expect(find.text('Aucune opportunité publiée'), findsOneWidget);
    expect(find.text('Direct indisponible'), findsOneWidget);
  });

  testWidgets('parcourt les cinq onglets dans les deux sens', (tester) async {
    await pumpApp(tester, buildTestApp());

    await _tapTab(tester, 'Matchs');
    expect(_selectedIndex(tester), 1);
    expect(find.widgetWithText(AppBar, 'Matchs'), findsOneWidget);
    expect(find.text('La Liga'), findsOneWidget);
    expect(find.text('Ligue 1'), findsOneWidget);

    await _tapTab(tester, 'Value');
    expect(_selectedIndex(tester), 2);
    expect(find.widgetWithText(AppBar, 'Value Betting'), findsOneWidget);
    expect(find.text('Aucune opportunité à afficher'), findsOneWidget);

    await _tapTab(tester, 'Direct');
    expect(_selectedIndex(tester), 3);
    expect(find.widgetWithText(AppBar, 'Direct'), findsOneWidget);
    expect(find.text('Le direct est désactivé'), findsOneWidget);

    await _tapTab(tester, 'Profil');
    expect(_selectedIndex(tester), 4);
    expect(find.widgetWithText(AppBar, 'Profil'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Crédits cotes utilisés'), findsOneWidget);
    expect(find.text('30 / 270'), findsOneWidget);

    await _tapTab(tester, 'Accueil');
    expect(_selectedIndex(tester), 0);
    expect(find.text('Bonjour, Alex'), findsOneWidget);
  });

  testWidgets('l’action à vide de l’Accueil ouvre le catalogue', (tester) async {
    await pumpApp(tester, buildTestApp());

    final action = find.text('Voir le catalogue');
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(_selectedIndex(tester), 1);
    expect(find.widgetWithText(AppBar, 'Matchs'), findsOneWidget);
  });

  testWidgets('la déconnexion renvoie vers Connexion', (tester) async {
    await pumpApp(tester, buildTestApp());

    await _tapTab(tester, 'Profil');
    final logout = find.text('Se déconnecter');
    // Liste paresseuse : il faut faire défiler pour construire le bouton.
    await tester.scrollUntilVisible(
      logout,
      300,
      scrollable: find.descendant(
        of: find.byType(ProfileScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(logout);
    await tester.pumpAndSettle();

    // La boîte de dialogue confirme avant d’effacer la session.
    expect(find.text('Se déconnecter ?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
    await tester.pumpAndSettle();

    expect(_selectedIndex(tester), 4);
    expect(find.text('Se déconnecter ?'), findsNothing);
  });
}
