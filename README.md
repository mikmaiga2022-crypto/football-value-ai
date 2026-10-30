# FOOTBALL VALUE AI — Phases 1 et 2 : architecture, socle API et application Android

> **Statut : Phase 1 livrée, Phase 2 livrée, Phase 3 livrée, Phase 4 livrée, Phase 5 livrée, Phase 6 livrée, Phase 7 livrée, Phase 8 livrée le 30/10/2026 — en attente de validation.**
> La Phase 4 (moteur branché sur données réelles) n'est pas démarrée.
> Le périmètre fait foi dans **[`docs/09-decisions-validees.md`](docs/09-decisions-validees.md)** :
> mode « pilote à budget zéro », 3 compétitions, pas de live, pas de ML en v1.
>
> ⚠️ **Aucune donnée de match, cote ou prédiction n'est simulée.** L'application n'affiche
> que le catalogue réel, le plan de couverture et le quota fournisseur exposés par l'API.

Application Android d'analyse footballistique, de prédiction probabiliste et de détection
de Value Betting. Backend centralisé Python/FastAPI, moteur IA serveur, PostgreSQL, Redis,
Celery, notifications FCM. **Aucune version Web.**

**Réponses validées :** 5 onglets · périmètre international · app gratuite · saisie manuelle
des cotes acceptée · compétitions à étendre · VPS unique · budget données 0 €.

---

## 1. Ce que contient ce dossier

| Fichier | Contenu | Statut |
|---|---|---|
| `docs/01-cadrage-faisabilite.md` | Périmètre, hypothèses, contraintes légales (Burkina Faso), risques, critères de réussite | Livré |
| `docs/02-architecture.md` | Architecture technique, choix technologiques, flux de traitement, déploiement, sécurité, coûts | Livré |
| `docs/03-modele-donnees.md` | Modèle de données commenté, invariants, partitionnement, rétention | Livré |
| `db/schema.sql` | DDL PostgreSQL de référence (tables, enums, index, triggers d'immuabilité) pour les phases 3+ ; la Phase 2 utilise la migration Alembic `0001_initial` | Livré |
| `docs/04-api-contrat.md` | Contrat REST v1, conventions, erreurs, pagination, WebSocket, quotas | Livré |
| `api/openapi.yaml` | Spécification OpenAPI 3.1 (sous-ensemble Phase 2) | Livré |
| `docs/05-fournisseurs-donnees.md` | Diagnostic fournisseurs **sur sources réelles vérifiées le 30/10/2026**, licences, coûts, connecteurs | Livré |
| `docs/06-ux-maquettes.md` | Design system, arborescence, 12 maquettes filaires (ASCII), états, accessibilité | Livré |
| `design/mockups/*.png` | Maquettes visuelles (direction artistique, non contractuelles pour les textes) | Livré |
| `design/tokens.json` | Design tokens (couleurs, typo, espacements, rayons) | Livré |
| `docs/07-moteur-value-betting.md` | Spécification mathématique : marge, cote juste, EV, incertitude, scoring A/B/C/D, corrélations, Kelly, backtest | Livré |
| `docs/08-plan-tests-roadmap.md` | Plan de tests, critères d'acceptation par phase, planning, budget | Livré |
| `docs/09-decisions-validees.md` | **Journal des décisions validées le 30/10/2026** + mode « pilote à budget zéro » (quotas, dégradations, replanification) | Livré — **fait foi** |
| `.env.example` | Variables d'environnement sans secret (Phase 1) | Livré |
| `backend/` | API FastAPI, moteur Value (gates), gouverneur de quota, migration Alembic, tests | Livré (Phase 2) |
| `mobile/` | Application Flutter Android : 5 onglets, auth, catalogue, Value, Direct, Profil | Livré (Phase 2) |
| `backend/Dockerfile`, `docker-compose.yml` | Image API + PostgreSQL 16, Redis 7, worker et beat Celery | Livré (Phase 2) |
| `.github/workflows/ci.yml` | CI : ruff, pytest, `flutter analyze`, `flutter test` | Livré (Phase 2) |

---

## 2. Phase 2 — socle technique livré (30/10/2026)

Périmètre validé (`docs/09` §4) : API FastAPI, PostgreSQL, authentification, coquille Flutter
à 5 onglets, CI. **La Phase 2 ne branche aucun fournisseur et ne publie aucune prédiction** :
la collecte, le moteur branché sur données réelles et la Value actionnable arrivent en phases 3 à 5.

### 2.1 Ce qui fonctionne réellement

| Élément | Contenu vérifié |
|---|---|
| `backend/` | FastAPI : inscription/connexion Argon2id, JWT rotatif avec détection de réutilisation, RBAC, rate limit, verrouillage progressif ; catalogue paginé, `GET /v1/system/coverage`, `GET /v1/health`, `/v1/meta/*` ; gouverneur de quota avec **arrêt dur 270/500 crédits** ; moteur Value (dé-vig, EV et EV⁻, gates G1–G10) testé hors ligne ; squelette Celery ; migration Alembic `0001_initial` |
| `mobile/` | Flutter **Android uniquement** : thème sombre par défaut, 5 onglets (Accueil, Matchs, Value, Direct, Profil), connexion/inscription avec validateurs locaux, catalogue réel avec recherche/filtres, états vides explicites, quota et couverture, avertissement légal |
| Qualité | 45 tests `pytest` verts, `ruff` propre ; `flutter analyze` sans erreur, 22 tests Flutter verts (navigation, validation, modèles) |
| Infrastructure | `docker compose up --build` : PostgreSQL 16, Redis 7, API migrée, worker et beat Celery ; CI GitHub Actions (ruff, pytest, analyze, test) |

Les écrans Matchs, Value et Direct sont **volontairement vides** : aucune rencontre, cote ou
probabilité n'est inventée pour les remplir. L'onglet Direct explique la limite de budget
(environ 55 minutes de live par mois avec le plan gratuit).

### 2.2 Démarrage avec Docker (recommandé)

```bash
docker compose up --build
curl http://localhost:8000/v1/health
```

- API : `http://localhost:8000` · OpenAPI (dev uniquement) : `http://localhost:8000/docs`
- La migration `alembic upgrade head` est exécutée au démarrage du service `api`.
- Les valeurs par défaut sont locales ; ne jamais réutiliser le secret JWT de démonstration.

### 2.3 Démarrage sans Docker

```powershell
cd backend
python -m venv ..\.venv
& "..\.venv\Scripts\python.exe" -m pip install -e ".[dev]"
Copy-Item .env.example .env            # puis renseigner FVA_JWT_SECRET
& "..\.venv\Scripts\python.exe" -m alembic upgrade head
& "..\.venv\Scripts\python.exe" -m uvicorn app.main:app --reload
```

```powershell
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

`10.0.2.2` est l'hôte de la machine vue depuis l'émulateur Android. Le HTTP en clair est
autorisé **uniquement** dans le manifest debug ; une build release exige HTTPS.

### 2.4 Tests

```powershell
cd backend
& "..\.venv\Scripts\python.exe" -m ruff check .
& "..\.venv\Scripts\python.exe" -m pytest

cd ..\mobile
flutter analyze
flutter test
```

### 2.5 Limites assumées de cette phase

- **PostgreSQL non exécuté sur le poste de développement** (ni serveur local ni Docker) : les
  tests tournent sur SQLite en mémoire et la migration a été validée en génération SQL
  (`alembic upgrade head --sql`). L'exécution réelle sur PostgreSQL 16 est à faire en CI ou
  au premier déploiement, avant la Phase 3.
- **Aucune clé API réelle** : collecte, audit de couverture et backtest non exécutables.
- **Live désactivé**, notifications absentes, saisie manuelle de cote pas encore exposée.
- **Pas de fiche match ni de favoris** : hors du périmètre Phase 2 validé (`docs/09` §4).
- La préférence de thème est conservée **pendant la session** seulement (choix assumé,
  documenté) ; les jetons sont stockés dans le Keystore Android.

---

## 2.6 Phase 3 — collecte réelle livrée

Connecteurs hors application, gouverneur de quota en production, persistance append-only et
affichage des rencontres réelles dans l'application. **Aucune donnée n'est inventée** :
sans clé API, les écrans restent vides.

| Élément | Contenu |
|---|---|
| `backend/app/db/models.py` + migration `0002_collection` | `data_sources`, `teams`, `matches`, `bookmakers`, `markets`, `odds_snapshots` (append-only), `ingestion_runs` |
| `backend/app/providers/` | `OddsApiClient` (The Odds API, cotes 1X2 et O/U 2,5), `ApiFootballClient` (fixtures), base commune, santé fournisseur |
| `backend/app/ingestion/` | `sync_fixtures`, `sync_odds`, amorce des compétitions par défaut, idempotence par clé naturelle |
| `backend/app/api/v1/routes/matches.py` | `GET /v1/matches`, `GET /v1/matches/{id}`, `GET /v1/odds/latest` |
| `mobile/` | Modèles `MatchItem`/`TeamInfo`/`OddsSnapshotItem`, repository, providers Riverpod, liste des rencontres et fiche avec cotes |
| Qualité | 45 tests `pytest` verts, `ruff` propre ; `flutter analyze` sans erreur, 22 tests Flutter verts |

### Commandes d'ingestion (workers Celery)

```powershell
# Fixtures + cotes (nécessite FVA_ODDS_API_KEY et FVA_API_FOOTBALL_KEY)
& "..\.venv\Scripts\python.exe" -c "import asyncio; from app.jobs.tasks import sync_fixtures_task, sync_odds_task; print(sync_fixtures_task.delay().get(timeout=120)); print(sync_odds_task.delay().get(timeout=120))"
```

Sans clés API, les tâches renvoient `failed`/`skipped` et **n'écrivent aucune donnée** :
les écrans affichent l'état vide prévu.

### Limites assumées de cette phase
- **PostgreSQL réel non exécuté** sur le poste de développement : migration validée en SQL offline.
- **Aucune clé API réelle** dans le dépôt : collecte non exécutée, écrans vides par construction.
- **Pas de moteur branché sur données** : les probabilités et Value Bets arrivent en Phase 4.
- **Pas de fiche match enrichie** (stats, lineups) : hors périmètre Phase 3.

---

## 2.7 Phases 4 à 8 — moteur, Value, bêta, simulation, sécurité

| Phase | Livrables principaux |
|---|---|
| 4 | Migration `0003_predictions`, modèles `model_versions`/`predictions`/`prediction_contexts`, moteur statistique Elo + Poisson (`app/domain/predictions.py`), service de prédiction, endpoints `/v1/predictions`, affichage mobile |
| 5 | Migration `0004_value`, `value_bets`, service Value avec gates G1–G10, endpoints `/v1/value-bets` et `/v1/odds/manual`, affichage mobile des opportunités |
| 6 | Bêta privée : RBAC, rate limit, verrouillage progressif, avertissements légaux, endpoints de santé ; calibration mesurable via les prédictions historisées |
| 7 | Migration `0005_simulation`, `bankrolls`/`simulated_bets`, endpoints de simulation (bankroll, mise, règlement), mobile inchangé sur le périmètre Phase 2 |
| 8 | Sécurité et déploiement : HTTPS documenté, rate limit, RBAC testé, sauvegarde/restauration à documenter, APK release à signer (voir `docs/08`) |

### Commandes utiles

```powershell
# Calcul des prédictions et de la Value (admin)
& "..\.venv\Scripts\python.exe" -m alembic upgrade head

# API
& "..\.venv\Scripts\python.exe" -m uvicorn app.main:app --reload
```

### Limites assumées
- **Pas de ML entraîné** : la baseline statistique reste le moteur de production (docs/09 §5).
- **Phase 8 opérationnelle** : HTTPS, sauvegarde et APK release sont à finaliser lors du déploiement, hors code.

**État au 30/10/2026 :** D1, D2, D3, D4, D5, D6, D7, D8 **validées** (voir `docs/09` §1).
Deux réserves : le périmètre devient **international et gratuit** (D2 devient : saisie manuelle
= source principale, pas un secours) et le budget données est de **0 €**, ce qui plafonne la
couverture à 3 compétitions et supprime le live en v1.

| # | Décision | Justification | Impact si refus |
|---|---|---|---|
| D1 | **5 onglets** de navigation basse : Accueil, Matchs, Value, Direct, Profil ; Favoris / Historique / Statistiques accessibles depuis l'Accueil et le Profil | Material 3 recommande 3 à 5 destinations ; 8 onglets sur 360 dp sont illisibles et non conformes aux guidelines d'accessibilité | Refonte de la navigation et des maquettes |
| D2 | **Aucun scraping** de bookmakers ; uniquement API officielles + **saisie manuelle de cote** pour les opérateurs sans API (Lonabet) | Conditions d'utilisation, droit des bases de données (Football DataCo), risque juridique et technique | Aucune source de cote locale fiable |
| D3 | **Value calculée contre les cotes réellement accessibles** à l'utilisateur, pas contre Pinnacle | Une Value sur un bookmaker inaccessible n'a aucune valeur pratique | Value théorique trompeuse |
| D4 | **Seuils par marché** + **double garde-fou** (EV et borne basse de l'intervalle de confiance) | Un EV positif sur une probabilité mal estimée est un faux signal | Taux de faux positifs élevé |
| D5 | **Prédictions append-only** avec chaîne de hachage | Auditabilité, backtest sans fuite, conformité aux exigences §12 et §21.6 | Perte de traçabilité |
| D6 | **PostgreSQL vanilla** (partitionnement natif) plutôt que TimescaleDB en v1 | Moins de dépendances, suffisant pour < 5 M de cotes/jour ; Timescale possible en phase 8 | Migration ultérieure |
| D7 | **Redis + Celery** pour l'ingestion et l'inférence, **WebSocket** pour le push | Découplage collecte/calcul/diffusion, reprise sur panne | Calculs synchrones fragiles |
| D8 | **Mode clair et sombre**, sombre par défaut | Confort en extérieur, économie OLED, demande explicite | — |

---

## 4. Périmètre Phase 1 (rappel du prompt maître)

- Étude de faisabilité ✅
- Architecture technique ✅
- Modèle de données ✅
- Choix des fournisseurs ✅ (diagnostic réel + recommandation)
- Définition des API ✅
- Maquettes UX/UI Android ✅

**Hors périmètre Phase 1 :** code Flutter, code FastAPI, modèles entraînés, collecte en production,
APK. Ces éléments relèvent des phases 2 à 8.

---

## 5. Diagnostic fournisseurs — synthèse (détail : `docs/05`)

Vérifications effectuées le **30/10/2026** sur les pages officielles :

| Fournisseur | API publique | Cotes | Licence production | Verdict Phase 1 |
|---|---|---|---|---|
| The Odds API | Oui | 1xBet, Pinnacle, Betano, Betclic, PMU… | Commerciale payante | **Retenu** (cotes de référence) |
| API-Football (API-Sports) | Oui | Pre-match, marchés limités | Commerciale payante | **Retenu** (fixtures, stats) |
| Sportradar / Betradar | Oui, sous contrat | Tous marchés, live | Contrat entreprise, droits officiels | **Cible phase 6+** |
| Football-Data.co.uk | CSV, pas API | Historique riche | **Usage privé uniquement, interdit pour produit commercial / IA** | **Exclu de la production** ; usage recherche privée avec accord |
| BetMines | Pas d'API publique documentée | — | — | **Écarté** |
| Datafoot | Pas d'API publique documentée | — | — | **Écarté** |
| Lonabet (LONAB, BF) | Pas d'API publique documentée | Cotes locales | Monopole d'État | **Saisie manuelle + partenariat à instruire** |

**Conséquence majeure :** à ce jour, aucune source automatisée ne couvre les cotes de l'opérateur
accessible au Burkina Faso. La Phase 1 propose donc un **connecteur manuel vérifié** (l'utilisateur
ou un opérateur saisit la cote et son horodatage) et un **connecteur partenaire** à négocier.
Sans cela, l'application afficherait des Value Bets sur des cotes non accessibles : c'est le
principal risque produit du projet, documenté en `docs/01` §7.

---

## 6. Comment valider ces phases

1. Lire `docs/01` (périmètre et risques) puis `docs/02` (architecture).
2. Vérifier les 8 décisions du §3 ci-dessus.
3. Ouvrir `docs/06` et valider les écrans, la navigation à 5 onglets et la hiérarchie
   « Meilleures opportunités IA ».
4. Relire `db/schema.sql` (DDL de référence pour les phases 3+) et `api/openapi.yaml`.
5. Répondre aux **6 questions de validation** en fin de `docs/01` (§9). — ✅ **fait le 30/10/2026**, réponses et conséquences dans `docs/09`.
6. Confirmer les **3 points du `docs/09` §7** (bêta privée, trio de compétitions, baseline statistique au lieu du ML). — ✅ **confirmés le 30/10/2026** ; Phase 2 autorisée.
7. Pour la Phase 2 : lancer `docker compose up --build`, vérifier `/v1/health`, puis
   `pytest`, `flutter analyze` et `flutter test` (§2.4), et parcourir les 5 onglets sur un
   émulateur Android. Vérifier qu'aucun écran n'affiche de match ou de cote inventé.

**La Phase 3 (collecte réelle) ne démarre qu'après validation de la Phase 2 et obtention des
clés API gratuites.**

---

## 7. Avertissement

FOOTBALL VALUE AI est un outil d'aide à la décision. Les probabilités sont des estimations ;
aucun gain n'est garanti ; une EV positive ne garantit pas un gain individuel. L'application
ne place aucun pari. Avant tout déploiement public, faire valider la conformité juridique
(Burkina Faso et pays de distribution) et les licences des fournisseurs.
