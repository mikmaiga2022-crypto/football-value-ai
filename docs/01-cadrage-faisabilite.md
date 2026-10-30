# 01 — Cadrage et étude de faisabilité

Version 1.0 — 30/10/2026 — Phase 1.

---

## 1. Objet

FOOTBALL VALUE AI est une application **Android native (Flutter)** qui affiche les matchs de
football, estime des probabilités par marché, les compare aux cotes des bookmakers et signale
les seules sélections dont l'espérance de valeur reste positive **après** prise en compte de
l'incertitude, de la qualité des données et de la calibration du modèle.

Le produit est un **outil d'analyse**. Il ne place aucun pari, ne détient aucun argent et ne
garantit aucun résultat.

---

## 2. Utilisateurs et rôles

| Rôle | Droits |
|---|---|
| `visitor` | Consultation différée (matchs, probabilités, aucun détail de cote) — optionnel, désactivable |
| `user` | Matchs, fiches, opportunités, favoris, notifications, simulation, historique personnel |
| `analyst` | + accès aux diagnostics modèles, backtests, exports, journal des données |
| `admin` | + utilisateurs, rôles, fournisseurs, seuils, modèles, sauvegardes, journaux |
| `service` | Compte technique pour les workers (jamais exposé à l'app) |

Un utilisateur peut cumuler plusieurs rôles. Le contrôle d'accès est appliqué **côté serveur**
(décorateur de permission sur chaque route) ; l'app ne fait que masquer l'interface.

---

## 3. Périmètre fonctionnel v1 (pilote)

### Inclus

1. Authentification e-mail + mot de passe, JWT court + refresh rotatif, biométrie locale optionnelle.
2. Calendrier des matchs (J-1 → J+7), fuseau horaire de l'appareil, statuts live.
3. Fiche match : informations, forme, confrontations, statistiques, compositions si disponibles.
4. Analyse IA : 1X2, double chance, DNB, totaux, BTTS, mi-temps, scores exacts, corners, cartons.
5. Classement des opportunités A/B/C/D/NO BET, tous marchés confondus, avec explication.
6. Comparaison des bookmakers et fraîcheur des cotes.
7. Favoris, notifications locales + FCM, historique, statistiques de performance.
8. Simulation de bankroll (Kelly fractionné plafonné, désactivable).
9. Administration dans l'app (rôles autorisés).
10. Mode clair / sombre, français, responsive 360 → 900 dp.

### Exclu volontairement de la v1

- Pari réel, paiement, portefeuille, retrait.
- Web, iOS, desktop (le projet Flutter ne générera **pas** la plateforme web).
- Marchés joueurs complets (nécessite des données sous licence, phase 6 au plus tôt).
- Combinaisons multi-matchs automatiques (spécifiées, activées après validation des corrélations).
- Chat, réseau social, pronostics communautaires.

---

## 4. Hypothèses techniques explicites

| # | Hypothèse | Valeur par défaut | Configurable |
|---|---|---|---|
| H1 | Fuseau serveur | UTC ; conversion côté app via `timezone` | Oui |
| H2 | Devise d'affichage | XOF (FCFA), montants simulés uniquement | Oui |
| H3 | Langue | Français ; i18n prête pour EN | Oui |
| H4 | Compétitions initiales | 8 ligues européennes + 4 compétitions africaines/CAN | Oui (table `competitions`) |
| H5 | Rétention cotes brutes | 24 mois (partition mensuelle) | Oui |
| H6 | Fréquence ingestion pré-match | 60 s si quota le permet, sinon 5 min | Oui |
| H7 | Fraîcheur maximale d'une cote pour une recommandation | 120 s pré-match, 30 s live | Oui |
| H8 | Seuil EV minimal | +3 % (varie par marché) | Oui |
| H9 | Bankroll simulée par défaut | **aucune** : l'utilisateur doit la définir | — |
| H10 | Mise par défaut | 0,5 % de la bankroll, plafond 1 % | Oui |

Toute hypothèse modifiée change le comportement produit : elle doit être revalidée.

---

## 5. Contraintes non fonctionnelles

| Domaine | Exigence | Mesure |
|---|---|---|
| Performance | Ouverture de l'accueil < 1,5 s (cache), liste 300 matchs fluide | 60 fps, pagination 20, images mises en cache |
| Disponibilité | 99,5 % API en heure de match | Health checks, redémarrage auto, file d'attente |
| Latence API | p95 < 400 ms (hors fournisseur) | Index, cache Redis 30 s |
| Fraîcheur | Cote affichée datée et vérifiée | `last_verified_at` obligatoire |
| Sécurité | OWASP MASVS L1, secrets hors app | Keystore Android, secrets serveur |
| Vie privée | Minimisation, pas de revente | Politique RGPD-like, export/suppression |
| Coût | < 150 USD/mois en pilote | The Odds API 20K + API-Football Pro + VPS |

---

## 6. Cadre légal — Burkina Faso (à faire valider par un juriste)

Éléments constatés lors de la recherche du 30/10/2026, **non constitutifs d'un avis juridique** :

- Les jeux d'argent sont encadrés par l'État ; la **LONAB** exploite les paris sportifs et
  propose une offre en ligne (« Lonabet », `lonabet.bf`).
- Les sources consultées indiquent que l'exploitation en ligne relève du monopole d'État ;
  l'organisation de jeux par un opérateur privé non agréé est interdite.
- La loi de finances 2025 a unifié la taxe sur les jeux de hasard (5 %), à confirmer.

**Conséquences produit :**

1. L'application **ne propose pas** de prise de pari, ne prend pas de dépôt, n'encaisse rien.
   Elle reste un outil d'information et de calcul.
2. Les **cotes affichées** doivent provenir d'opérateurs autorisés pour l'utilisateur cible,
   ou être saisies manuellement par lui. Afficher une cote 1xBet à un utilisateur burkinabè
   peut être trompeur ou illégal selon l'interprétation locale.
3. Avant tout store listing : validation du statut « outil d'analyse » vs « promotion de jeux »,
   mention 18+, avertissement de perte, absence de garantie.
4. Les **logos** de clubs et compétitions sont des marques : utilisation à titre informatif,
   sources licenciées uniquement, pas de revendication d'affiliation.
5. Les **données** (calendriers, stats, cotes) sont protégées (droit du producteur de base de
   données). Toute collecte doit être couverte par une licence ou une API officielle.

**Recommandation :** consulter un avocat burkinabè avant la phase 8, et ne pas distribuer
hors du Burkina Faso sans revue par pays.

---

## 7. Risques majeurs et parades

| # | Risque | Prob. | Impact | Parade |
|---|---|---|---|---|
| R1 | **Aucune API de cotes pour Lonabet** → Value non actionnable | Élevée | Critique | Saisie manuelle horodatée + connecteur partenaire ; afficher clairement la source |
| R2 | Coût des données live (Sportradar) élevé | Moyenne | Élevé | Démarrer pré-match, live en phase 6 avec budget validé |
| R3 | Modèle mal calibré → fausses Value | Moyenne | Critique | Double garde-fou EV + IC, calibration obligatoire, NO BET par défaut |
| R4 | Quotas API dépassés | Moyenne | Moyen | Cache, déduplication, ordonnanceur, alertes 80 % |
| R5 | Bannissement/limitation des comptes bookmakers | Faible | Moyen | Aucun compte automatisé, aucune mise réelle |
| R6 | Données manquantes (blessures, compos) | Élevée | Moyen | Score de qualité de données, affichage « donnée indisponible », jamais d'invention |
| R7 | Contentieux juridique (jeu, données, marques) | Faible | Critique | Validation juridique, licences, 18+, pas de dépôt |
| R8 | Dérive du modèle (concept drift) | Moyenne | Élevé | Monitoring CLV/Brier glissant, alerte, rollback versionné |
| R9 | Fuite de données utilisateurs | Faible | Critique | Chiffrement, moindre privilège, audit, sauvegardes chiffrées |
| R10 | Performance mobile sur entrée de gamme | Moyenne | Moyen | Listes virtualisées, images WebP, cache local, budget mémoire |

---

## 8. Indicateurs de réussite du pilote (honnêtes, mesurables)

Le pilote ne promet pas de rentabilité. Il doit démontrer :

1. **Couverture** : ≥ 90 % des matchs des compétitions activées ont une analyse.
2. **Fraîcheur** : ≥ 95 % des cotes affichées ont moins de 5 minutes (pré-match).
3. **Calibration** : ECE ≤ 0,05 sur le 1X2 en backtest walk-forward.
4. **Prudence** : part de NO BET ≥ 60 % des matchs (un moteur qui recommande partout est suspect).
5. **Traçabilité** : 100 % des recommandations ont une prédiction immuable associée.
6. **CLV** : mesure disponible, sans objectif de rentabilité annoncé avant 1 000 sélections.
7. **Stabilité** : aucune perte de donnée d'ingestion sur 7 jours consécutifs.
8. **Sécurité** : 0 secret dans l'APK (scan CI), 0 endpoint admin sans contrôle de rôle.

---

## 9. Questions de validation (bloquantes avant Phase 2)

1. **Navigation** : validez-vous 5 onglets (Accueil, Matchs, Value, Direct, Profil) avec
   Favoris/Historique/Statistiques en accès secondaire, ou souhaitez-vous les 8 onglets
   explicitement demandés (au prix de l'ergonomie sur petit écran) ?
2. **Périmètre géographique du pilote** : Burkina Faso uniquement, UEMOA, ou international ?
   Cela détermine les bookmakers à afficher et le cadre légal.
3. **Source de cotes** : acceptez-vous la saisie manuelle de cote (Lonabet) en v1, en attendant
   un accord de partenariat ? Sans cela, la Value Betting ne sera pas actionnable localement.
4. **Compétitions prioritaires** : la liste par défaut (Ligue 1, Premier League, La Liga, Serie A,
   Bundesliga, Ligue des champions, CAN, championnats burkinabè) convient-elle ?
5. **Hébergement** : VPS unique (≈ 20–40 €/mois) pour le pilote, ou infrastructure séparée
   (API / workers / base) dès le départ ?
6. **Budget données** : plafond mensuel pour The Odds API + API-Football + éventuel Sportradar ?

Réponses attendues avant toute génération de code (Phase 2).

### Réponses du 30/10/2026

| # | Réponse |
|---|---|
| 1 | 5 onglets validés |
| 2 | **International**, application **gratuite** |
| 3 | **Saisie manuelle des cotes acceptée** (devient la source principale) |
| 4 | Compétitions **étendues** (mais bridées à 3 par le budget — voir annexe) |
| 5 | **VPS unique** |
| 6 | **0 € / mois** de budget données |

Ces réponses créent une contrainte structurante (budget zéro) traitée dans
**[`09-decisions-validees.md`](09-decisions-validees.md)**, qui fait foi : quotas chiffrés,
mode dégradé, 3 compétitions, live et ML hors v1.
