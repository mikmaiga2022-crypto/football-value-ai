# 08 — Plan de tests, critères d'acceptation et feuille de route

Version 1.0 — Phase 1.

---

## 1. Stratégie de test

| Niveau | Outils | Portée | Fréquence |
|---|---|---|---|
| Unitaire backend | pytest, Hypothesis | formules, gates, règlements, mapping | chaque commit |
| Unitaire mobile | `flutter test` | formatage, états, navigation, cache | chaque commit |
| Intégration API | pytest + httpx + Testcontainers (Postgres, Redis) | routes, RBAC, transactions, idempotence | chaque PR |
| Contrat | `openapi-spec-validator`, `schemathesis` | conformité OpenAPI, codes d'erreur | chaque PR |
| Composants Flutter | `flutter_test`, golden tests | cartes, badges, états vides | chaque PR |
| E2E mobile | `integration_test` sur émulateur | parcours connexion → match → opportunité → simulation | nightly |
| Charge | k6 | 500 utilisateurs simultanés, 100 req/s | avant release |
| Sécurité | OWASP ZAP baseline, `pip-audit`, `flutter analyze` | OWASP Top 10, secrets, dépendances | hebdo |
| Résilience | chaos simple (coupure fournisseur, Redis, DB) | dégradation, reconnexion | avant release |
| Backtest | script reproductible, dataset gelé | calibration, absence de fuite | à chaque modèle |

**Règle** : aucun module n'est déclaré terminé sans ses tests verts et un rapport vérifiable.

---

## 2. Cas de test critiques (extrait obligatoire)

### 2.1 Mathématiques

| ID | Cas | Attendu |
|---|---|---|
| M1 | Marge 2,10/3,40/3,60 | `S = 1,048086`, marge `4,81 %` |
| M2 | No-vig proportionnel | `π = 0,454345 / 0,280624 / 0,265031`, somme `1 ± 1e-6` |
| M3 | No-vig puissance | `Σ π = 1 ± 1e-6`, toutes `π > 0` |
| M4 | No-vig Shin | `Σ π = 1 ± 1e-6`, monotone en `z` |
| M5 | Cote juste `p = 0,58` | `1,7241 ± 1e-4` |
| M6 | EV `p = 0,58`, `o = 1,95` | `0,1310 ± 1e-6` |
| M7 | Score T3 (`docs/07` §6.4) | `76,09 ± 0,1`, priorité `A` |
| M8 | `EV⁻ ≤ 0` | jamais `A` ni `B` |
| M9 | Marge > `max_margin` | aucune sélection |
| M10 | Probabilités 1X2 | somme `1 ± 1e-6` |
| M11 | Kelly `p=0,58`, `o=1,95` | `f* = 0,1379`, mise plafonnée à 1 % |
| M12 | `f* ≤ 0` | mise `0`, aucun enregistrement |

### 2.2 Règlement

| ID | Cas | Attendu |
|---|---|---|
| R1 | DNB, match nul | mise remboursée, P&L = 0 |
| R2 | AH −1, ligne entière, victoire 1-0 | push |
| R3 | AH −0,75, victoire 1-0 | demi-gain |
| R4 | AH +0,25, nul | demi-gain |
| R5 | O/U 2,5, score 2-1 | Over gagné, Under perdu |
| R6 | O/U ligne entière 3, score 3-0 | push |
| R7 | BTTS, 0-0 | Non gagné |
| R8 | Score exact 2-1, score final 2-1 | gagné |
| R9 | Match abandonné | règle du bookmaker, statut `void` par défaut |
| R10 | Combiné même match Over 2,5 + BTTS | probabilité jointe ≠ produit |

### 2.3 Données et ingestion

| ID | Cas | Attendu |
|---|---|---|
| D1 | Même payload rejoué | aucun doublon (`payload_hash`) |
| D2 | Cote `1,00` ou négative | rejet, log, pas d'insertion |
| D3 | Ligne `2,3` (non multiple de 0,25) | rejet |
| D4 | Match avec équipes identiques | rejet |
| D5 | Cote observée sans horodatage | rejet |
| D6 | Fournisseur en panne | `provider_health` à jour, cache servi, badge « périmée » |
| D7 | Quota à 80 % | alerte, pas d'arrêt brutal |
| D8 | Fuseau `Africa/Ouagadougou` | `kickoff_local` correct, `kickoff_utc` inchangé |
| D9 | Nom d'équipe variante | mapping par `external_refs`, pas par nom |
| D10 | Payload contenant une clé API | la clé n'apparaît jamais dans les logs |

### 2.4 API et sécurité

| ID | Cas | Attendu |
|---|---|---|
| A1 | `/opportunities` sans token | `401` |
| A2 | Token expiré | `401 TOKEN_EXPIRED`, refresh possible |
| A3 | Refresh rejoué après rotation | `401`, famille révoquée |
| A4 | `analyst` appelle `POST /admin/models/{id}/activate` | `403` |
| A5 | Utilisateur A lit la bankroll de B | `404` |
| A6 | `POST` simulation rejoué avec même `Idempotency-Key` | une seule mise |
| A7 | 121 requêtes/min | `429` + `Retry-After` |
| A8 | Cote périmée + simulation | `409 OPPORTUNITY_EXPIRED` |
| A9 | Aucune opportunité | `200`, `no_bet: true` |
| A10 | Réponse sans `request_id` | test de contrat en échec |

### 2.5 Mobile

| ID | Cas | Attendu |
|---|---|---|
| F1 | Premier lancement hors ligne | écran explicite, pas de crash |
| F2 | Rotation / changement de police 1,3 | pas de troncature critique |
| F3 | Thème clair/sombre | contrastes conformes |
| F4 | 300 matchs | défilement fluide, mémoire stable |
| F5 | Cote périmée | badge + action désactivée |
| F6 | Perte de connexion en cours de session | bandeau, cache, reconnexion auto |
| F7 | Notification priorité A | ouverture sur la bonne fiche |
| F8 | Deep link match | authentification puis navigation |
| F9 | TalkBack | description complète des cartes |
| F10 | App tuée puis relancée | état restauré, pas de perte de favori |

### 2.6 Backtest

| ID | Cas | Attendu |
|---|---|---|
| B1 | Feature postérieure au coup d'envoi | test échoue (garde-fou) |
| B2 | Résultat du match dans les features | test échoue |
| B3 | Split aléatoire | interdit par le code (assertion) |
| B4 | `n < 1 000` | rapport marqué « insuffisant », pas de ROI public |
| B5 | Rejeu du backtest | résultats identiques (même hash de dataset) |
| B6 | Comparaison marché | log loss modèle vs no-vig affiché |

---

## 3. CI/CD

```
commit
  ├─ lint (ruff, mypy, flutter analyze)
  ├─ tests unitaires (pytest -q, flutter test)
  ├─ tests d'intégration (Postgres + Redis éphémères)
  ├─ validation OpenAPI
  ├─ scan secrets (gitleaks) + dépendances (pip-audit)
  ├─ build image Docker + APK debug
  └─ (main) déploiement staging + tests E2E
release
  ├─ tests de charge k6
  ├─ ZAP baseline
  ├─ signature APK (keystore hors dépôt)
  └─ tag + notes de version
```

Aucune fusion si un test critique échoue. Aucun secret dans les logs CI.

**Livré en Phase 2 (`.github/workflows/ci.yml`) :** `ruff check`, `pytest`,
`flutter analyze`, `flutter test`. Les étapes PostgreSQL/Redis éphémères, validation OpenAPI,
`gitleaks`, `pip-audit` et build APK restent à ajouter avant la mise en production.

---

## 4. Critères d'acceptation par phase

### Phase 2 — Application Android de base

- [ ] Connexion, inscription, refresh, déconnexion fonctionnels.
- [ ] Accueil, liste des matchs, fiche match, favoris, paramètres, thème.
- [ ] Données servies par une API de **démonstration explicitement étiquetée** (pas de fausses
      cotes présentées comme réelles) ou par la vraie API si la phase 3 est prête.
- [ ] 0 crash sur les 10 parcours E2E.
- [ ] APK debug installable sur Android 10+.
- [ ] Tests unitaires et golden tests verts.

**État au 30/10/2026 — socle Phase 2 livré (`docs/09` §4) :**

- ✅ Connexion, inscription, refresh et déconnexion (API + Flutter), couverts par des tests.
- ✅ Accueil, catalogue des compétitions, Value, Direct, Profil, thème et navigation à 5 onglets.
- ✅ Aucune donnée simulée : seuls catalogue, couverture et quota réels sont affichés.
- ⏸ Fiche match et favoris : hors périmètre Phase 2 validé, reportés faute de données réelles.
- ⏳ Parcours E2E sur appareil et APK debug installable : à exécuter lors de la validation.
- ⏳ Golden tests : remplacés par 22 tests widgets/modèles (navigation, validation, parsing).

### Phase 3 — Collecte

- [ ] 2 fournisseurs branchés (The Odds API + API-Football), clés hors app.
- [ ] Ingestion idempotente, journalisée, avec quotas.
- [ ] Données réelles visibles dans l'app, avec source et horodatage.
- [ ] Aucun doublon sur 72 h de collecte.
- [ ] Rapport de couverture réel (matchs, marchés, bookmakers).

### Phase 4 — Moteur IA

- [ ] Modèles Poisson/Dixon-Coles + Elo + gradient boosting entraînés.
- [ ] Calibration ECE ≤ 0,05 sur 1X2 en walk-forward.
- [ ] Scores exacts, totaux, BTTS, MT produits.
- [ ] Backtest walk-forward reproductible, sans fuite, ≥ 1 000 sélections si les données le permettent.
- [ ] Rapport de performance par marché et par compétition.

### Phase 5 — Value Betting

- [ ] Marge, no-vig, cote juste, EV, EV⁻ conformes aux vecteurs T1–T3.
- [ ] Gates et priorités A/B/C/D/NO BET conformes.
- [ ] Comparaison bookmakers avec fraîcheur.
- [ ] Explications générées et lisibles.
- [ ] Aucune recommandation A/B sur cote non vérifiée (test automatisé).

### Phase 6 — Live

- [ ] Score/minute/statistiques live avec source.
- [ ] Recalcul des probabilités selon temps restant.
- [ ] Suspension automatique si données insuffisantes/périmées.
- [ ] Notifications live conformes aux préférences.

### Phase 7 — Simulation et statistiques

- [ ] Bankroll définie par l'utilisateur, Kelly plafonné, pas de Martingale.
- [ ] ROI, yield, drawdown, CLV, taux de réussite avec `n` et IC.
- [ ] Règlement exact (DNB, AH, O/U, CS, combinés).
- [ ] Export CSV/JSON de l'historique.

### Phase 8 — Sécurité et déploiement

- [ ] HTTPS, HSTS, rate limit, RBAC testé.
- [ ] Sauvegarde/restauration testées (RTO < 2 h, RPO < 24 h).
- [ ] ZAP sans vulnérabilité critique ou haute.
- [ ] APK release signé, `minSdk` documenté, aucune clé API dans l'APK.
- [ ] Documentation d'installation, d'exploitation, de maintenance, utilisateur.
- [ ] Validation juridique documentée.

---

## 5. Feuille de route indicative

Hypothèse : 1 développeur senior à temps plein, accès aux API dès la phase 3.

| Phase | Durée | Dépendances | Livrable |
|---|---|---|---|
| 1. Architecture & maquettes | 1,5 semaine | — | Ce dossier |
| 2. App Android de base | 4 semaines | Phase 1 validée | APK debug + API squelette |
| 3. Collecte | 3 semaines | Clés API, phase 2 | Données réelles |
| 4. Moteur IA | 6–8 semaines | 6–12 mois d'historique ou licence | Modèles + backtest |
| 5. Value Betting | 3 semaines | Phase 4 | Moteur d'opportunités |
| 6. Live | 3–4 semaines | Fournisseur live licencié | Module live |
| 7. Simulation & stats | 2–3 semaines | Phase 5 | Tableau de bord |
| 8. Sécurité & déploiement | 3 semaines | Tout | APK production |

**Chemin critique** : la disponibilité de l'historique de cotes. Sans licence historique
(The Odds API payant ou TheStatsAPI), la phase 4 ne peut pas produire de backtest crédible avant
6 à 12 mois de collecte propre. C'est le principal risque de calendrier.

**Parallélisation possible** : phases 2 et 3 partiellement, phases 6 et 7 après la 5.

---

## 6. Definition of Done (commune)

Une fonctionnalité est terminée lorsque :

1. Le code est revu et fusionné.
2. Les tests unitaires et d'intégration passent.
3. Le contrat OpenAPI est à jour.
4. Les cas d'erreur et les états vides sont traités.
5. Les données affichées sont traçables (source, horodatage).
6. La documentation utilisateur/technique est mise à jour.
7. Aucun secret, aucune donnée personnelle dans les logs.
8. La performance est mesurée (p95 API, fps mobile).

---

## 7. Budget pilote (rappel)

| Poste | Mensuel |
|---|---|
| VPS + sauvegardes | 25–45 € |
| The Odds API 20K | ≈ 28 € |
| API-Football | 18–45 € |
| Divers (domaine, monitoring) | 5–15 € |
| **Total** | **≈ 75–130 €/mois** |

Coût humain : 1 développeur senior × ~6 mois pour un pilote crédible (hors Sportradar).

---

## 8. Ce qui n'est pas promis

- Aucun ROI, aucun taux de réussite, aucune rentabilité n'est annoncé avant backtest et
  validation prospective.
- Aucune garantie de couverture sur les compétitions africaines.
- Aucun accès live fiable sans contrat fournisseur.
- Aucune Value actionnable sur Lonabet sans partenariat ou saisie manuelle.
