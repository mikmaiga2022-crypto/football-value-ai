# 04 — Contrat d'API REST v1

Version 1.0 — Phase 1. Spécification lisible ; le fichier machine est `api/openapi.yaml`.

---

## 1. Conventions

| Sujet | Règle |
|---|---|
| Base URL | `https://api.footballvalue.ai/v1` (production), `https://staging.…/v1` |
| Transport | HTTPS uniquement, TLS ≥ 1.2, HSTS |
| Format | JSON UTF-8, `snake_case`, dates ISO 8601 UTC (`2026-10-31T17:30:00Z`) |
| Identifiants | chaînes opaques, jamais d'entier incrémental exposé pour les ressources utilisateur |
| Montants | chaîne décimale (`"1500.00"`), devise explicite |
| Probabilités | nombre `0 < p < 1`, 6 décimales max |
| Versionnage | préfixe `/v1` ; changement cassant ⇒ `/v2` ; en-tête `X-API-Version` renvoyé |
| Horloge | chaque réponse contient `meta.server_time` ; l'app calcule la dérive |
| Langue | `Accept-Language: fr` (défaut), `en` |
| Compression | `Accept-Encoding: gzip` recommandé |

**Aucune clé fournisseur ne transite par l'API ni par l'app.** Le mobile ne connaît que
`API_BASE_URL` (non secret).

---

## 2. Authentification

```
POST /v1/auth/register   {email, password, display_name?, timezone?, locale?}
POST /v1/auth/login      {email, password, device: {label, platform, app_version}}
   → {access_token (15 min), refresh_token (30 j, rotatif), user, permissions[]}
POST /v1/auth/refresh    {refresh_token} → nouveau couple, ancien révoqué
POST /v1/auth/logout     {refresh_token} → révocation
GET  /v1/me
PATCH /v1/me             {display_name?, timezone?, locale?, notification_prefs?}
```

- Mot de passe : ≥ 10 caractères, vérifié contre une liste de mots de passe compromis.
- Argon2id côté serveur ; le mot de passe ne quitte jamais l'appareil en clair (TLS).
- Verrouillage progressif après 5 échecs (1 min, 5 min, 15 min).
- Le refresh token est stocké dans le Keystore Android ; rotation à chaque usage ;
  réutilisation d'un token révoqué ⇒ révocation de toute la famille (détection de vol).
- Biométrie : déverrouillage local du token, pas un facteur serveur.

**Autorisation** : chaque route déclare une permission (`matches.read`, `value.read`,
`admin.models`…). Un `403` explicite est renvoyé, jamais un `404` masqué pour les routes admin
(sauf ressources d'autres utilisateurs : `404`).

---

## 3. Ressources et routes

### 3.1 Matchs

| Méthode | Route | Permission | Description |
|---|---|---|---|
| GET | `/matches` | `matches.read` | Liste paginée, filtres |
| GET | `/matches/{id}` | `matches.read` | Fiche complète agrégée |
| GET | `/matches/{id}/predictions` | `predictions.read` | Probabilités par marché |
| GET | `/matches/{id}/odds` | `value.read` | Cotes par marché et bookmaker |
| GET | `/matches/{id}/opportunities` | `value.read` | Classement des meilleures sélections |
| GET | `/matches/{id}/stats` | `matches.read` | Statistiques détaillées des deux équipes |
| GET | `/matches/{id}/lineups` | `matches.read` | Compositions probables/officielles |

Paramètres de `/matches` :

| Param | Type | Défaut | Note |
|---|---|---|---|
| `from`, `to` | date ISO | aujourd'hui → J+7 | max 31 jours |
| `status` | `scheduled,live,finished` | tous | multi-valeurs |
| `competition` | code | — | multi-valeurs |
| `q` | texte | — | équipe, compétition, pays (≥ 2 caractères) |
| `analyzed` | bool | — | seulement matchs avec prédiction |
| `has_value` | bool | — | seulement matchs avec opportunité active |
| `timezone` | IANA | profil utilisateur | conversion d'affichage |
| `cursor`, `limit` | — | 20, max 50 | pagination par curseur |

Réponse (extrait) :

```json
{
  "data": [
    {
      "id": "m_01J9Z3K4",
      "competition": {"code": "EPL", "name": "Premier League", "country": "GB", "logo_url": "..."},
      "season": "2026/2027",
      "round": "J12",
      "kickoff_utc": "2026-10-31T17:30:00Z",
      "kickoff_local": "2026-10-31T17:30:00",
      "timezone": "Africa/Ouagadougou",
      "status": "scheduled",
      "home": {"id": "t_ars", "name": "Arsenal", "logo_url": "..."},
      "away": {"id": "t_che", "name": "Chelsea", "logo_url": "..."},
      "analysis": {"state": "ready", "model_version": "ens-2.3.0", "predicted_at": "2026-10-30T09:12:00Z"},
      "data_quality": {"score": 0.86, "flags": ["lineups_probable"]},
      "value_summary": {"best_priority": "A", "count": 3, "top_ev": "0.1310"}
    }
  ],
  "page": {"next_cursor": "eyJvIjoyMH0", "has_more": true},
  "meta": {"server_time": "2026-10-30T10:00:00Z", "api_version": "1.4.0", "freshness": {"oldest_odds_seconds": 42}}
}
```

### 3.2 Fiche match

`GET /matches/{id}` renvoie un agrégat destiné à l'écran, avec des blocs **nullable** explicites :
`standings`, `form`, `head_to_head`, `injuries`, `lineups`, `venue`, `weather` (optionnel).
Un bloc absent est `null` + `unavailable_reasons[]` — jamais un objet vide ambigu.

### 3.3 Prédictions

```json
{
  "match_id": "m_01J9Z3K4",
  "model": {"code": "ensemble", "version": "ens-2.3.0", "trained_at": "2026-10-01T00:00:00Z"},
  "predicted_at": "2026-10-30T09:12:00Z",
  "data_quality": {"score": 0.86, "missing": []},
  "markets": [
    {
      "market": "1X2", "line": 0,
      "selections": [
        {"code": "HOME", "probability": 0.4512, "ci": [0.4210, 0.4810], "fair_odds": 2.2163},
        {"code": "DRAW", "probability": 0.2680, "ci": [0.2430, 0.2930], "fair_odds": 3.7313},
        {"code": "AWAY", "probability": 0.2808, "ci": [0.2550, 0.3070], "fair_odds": 3.5612}
      ]
    }
  ],
  "expected_goals": {"home": 1.52, "away": 1.18, "total": 2.70},
  "top_scorelines": [
    {"score": "1-1", "probability": 0.1180},
    {"score": "2-1", "probability": 0.1010},
    {"score": "1-0", "probability": 0.0930}
  ],
  "uncertainty": {"level": "medium", "drivers": ["lineups_probable", "no_xg_away"]},
  "disclaimer": "Probabilités estimées — aucun gain garanti."
}
```

> Les valeurs ci-dessus sont un **exemple de forme**, pas une prédiction réelle.

### 3.4 Opportunités

| Méthode | Route | Description |
|---|---|---|
| GET | `/opportunities` | Flux global, filtres `priority`, `market`, `date`, `min_ev`, `competition` |
| GET | `/opportunities/{id}` | Détail + explication + historique de la cote |
| POST | `/opportunities/{id}/simulate` | Crée une mise simulée (idempotent) |

```json
{
  "id": "vb_01J9Z4A2",
  "match_id": "m_01J9Z3K4",
  "market": "OU", "line": 2.5, "selection": "OVER",
  "label": "Over 2,5 buts",
  "bookmaker": {"code": "onexbet", "name": "1xBet", "access": "api"},
  "odds": "1.95",
  "odds_meta": {
    "observed_at": "2026-10-30T09:58:12Z",
    "age_seconds": 108,
    "is_verified": true,
    "is_available": true,
    "source": "the_odds_api"
  },
  "probability_ai": 0.5800,
  "probability_ci": [0.5450, 0.6140],
  "probability_novig": 0.4872,
  "fair_odds": "1.7241",
  "ev": "0.1310",
  "ev_lower": "0.0570",
  "edge": "0.0928",
  "score": 82.4,
  "priority": "A",
  "uncertainty": 0.035,
  "reasons": [
    "Modèle calibré sur ce marché (ECE 0.028)",
    "Écart de 9,3 points face au marché sans marge",
    "Cote vérifiée il y a moins de 2 minutes"
  ],
  "risks": [
    "Compositions non officielles",
    "Cote en baisse depuis l'ouverture"
  ],
  "model_version": "ens-2.3.0",
  "created_at": "2026-10-30T09:59:00Z",
  "status": "active"
}
```

Champs **obligatoires** : `odds_meta.observed_at`, `is_verified`, `probability_ci`, `ev_lower`,
`model_version`, `status`. Une opportunité sans ces champs est un bug serveur.

Absence d'opportunité : `200` avec `{"data": [], "no_bet": true, "reason": "Aucune sélection ne franchit les seuils de fiabilité."}`
— ce n'est pas une erreur.

### 3.5 Favoris

```
GET    /favorites?type=match|team|competition
POST   /favorites            {entity_type, entity_id}
DELETE /favorites/{type}/{id}
```

### 3.6 Historique et statistiques

| Route | Contenu |
|---|---|
| `GET /history?cursor&from&to&market&priority` | Recommandations passées + résultat + EV réalisée |
| `GET /stats/summary` | ROI, yield, drawdown, taux de réussite, CLV, échantillon |
| `GET /stats/markets` | Performance par marché (Brier, log loss, ROI, n) |
| `GET /stats/calibration?market=1X2` | Courbe de calibration (bins) |
| `GET /stats/competitions` | Performance par compétition |

Chaque statistique renvoie `n` (échantillon), `ci95` et `period`. Une statistique sans `n` est
invalide. Aucun taux n'est affiché si `n < 100` : l'UI affiche « échantillon insuffisant ».

### 3.7 Simulation

```
GET  /simulation/bankrolls
POST /simulation/bankrolls          {name, currency, initial_amount, kelly_fraction?, ...}
PATCH /simulation/bankrolls/{id}
GET  /simulation/bets?bankroll_id&cursor
POST /simulation/bets               {value_bet_id | slip_id, stake}   (Idempotency-Key requis)
POST /simulation/bets/{id}/settle   {result}
GET  /simulation/performance?bankroll_id
```

Refus métier : mise > plafond (`422`, code `STAKE_LIMIT_EXCEEDED`), bankroll absente
(`409 BANKROLL_REQUIRED`), opportunité expirée (`409 OPPORTUNITY_EXPIRED`).

### 3.8 Notifications et appareils

```
GET   /notifications?cursor&unread_only
POST  /notifications/{id}/read
GET   /notifications/preferences
PATCH /notifications/preferences   [{type, enabled, min_priority, quiet_start, quiet_end}]
POST  /devices                     {fcm_token, platform, app_version}
DELETE /devices/{id}
```

### 3.9 Administration (rôles `admin`, partiellement `analyst`)

| Route | Rôle | Description |
|---|---|---|
| `GET/PATCH /admin/users` | admin | Liste, suspension, rôles |
| `GET /admin/providers` | admin | État, quotas, activation |
| `PATCH /admin/providers/{code}` | admin | Activer/désactiver (jamais la clé en clair) |
| `GET /admin/ingestion-runs` | analyst+ | Journal de collecte |
| `GET /admin/models` | analyst+ | Versions, métriques |
| `POST /admin/models/{id}/activate` | admin | Promotion après validation |
| `POST /admin/models/{id}/rollback` | admin | Retour version précédente |
| `GET/PATCH /admin/thresholds` | admin | Seuils par marché (versionnés) |
| `GET /admin/audit` | admin | Journal d'audit |
| `GET /admin/health` | analyst+ | Santé serveur, files, DB |
| `POST /admin/backups` | admin | Déclenche une sauvegarde |

Toute action admin écrit dans `audit_logs` (acteur, cible, avant/après).

### 3.10 Méta

```
GET /meta/health        → statut public (sans détail interne)
GET /meta/config        → version minimale d'app, textes légaux, fonctionnalités activées
GET /meta/disclaimer    → avertissement courant (daté, versionné)
```

---

## 4. Erreurs

Enveloppe unique :

```json
{
  "error": {
    "code": "OPPORTUNITY_EXPIRED",
    "message": "Cette opportunité n'est plus active.",
    "details": {"expired_at": "2026-10-30T10:02:00Z"},
    "request_id": "req_01J9Z5..."
  }
}
```

| HTTP | Codes |
|---|---|
| 400 | `VALIDATION_ERROR`, `INVALID_CURSOR` |
| 401 | `UNAUTHENTICATED`, `TOKEN_EXPIRED` |
| 403 | `FORBIDDEN`, `ROLE_REQUIRED` |
| 404 | `NOT_FOUND` |
| 409 | `CONFLICT`, `OPPORTUNITY_EXPIRED`, `BANKROLL_REQUIRED` |
| 422 | `STAKE_LIMIT_EXCEEDED`, `NO_BET` |
| 429 | `RATE_LIMITED` (+ `Retry-After`) |
| 503 | `PROVIDER_UNAVAILABLE`, `DATA_STALE` |

`DATA_STALE` est renvoyé quand la dernière cote vérifiée dépasse la fenêtre de fraîcheur : l'app
affiche un bandeau et **désactive** le bouton de simulation.

---

## 5. Pagination, cache, idempotence

- **Curseur** opaque base64url (`{offset}` ou `{kickoff_utc,id}`), jamais d'offset numérique exposé
  pour les flux temps réel (instabilité).
- `Cache-Control: private, max-age=30` sur les listes ; `ETag` sur les fiches ; `304` supporté.
- `Idempotency-Key` obligatoire sur tous les `POST` de simulation et d'administration ;
  conservée 24 h, réponse rejouée à l'identique.
- `If-None-Match` recommandé côté app pour économiser la data.

---

## 6. Limites de débit

| Portée | Limite |
|---|---|
| Anonyme (login/register) | 10 req/min/IP |
| Utilisateur authentifié | 120 req/min |
| Rafale | 20 req/10 s |
| WebSocket | 1 connexion par appareil, 5 messages/s client max |
| Admin | 60 req/min |
| Export | 1 req/5 min |

Réponse `429` avec `Retry-After` et `X-RateLimit-Remaining`. L'app applique un backoff et
n'affiche pas d'erreur bloquante.

---

## 7. WebSocket

```
wss://api.footballvalue.ai/v1/ws?token=<access_token_court>
```

Client → serveur : `{"action":"subscribe","channels":["match:m_01J9Z3K4","value:EPL"]}`
Serveur → client :

```json
{"type":"value.changed","channel":"match:m_01J9Z3K4","revision":1842,
 "ts":"2026-10-30T10:01:03Z",
 "payload":{"match_id":"m_01J9Z3K4","changes":[{"id":"vb_01J9Z4A2","priority":"B","ev":"0.0610","status":"active"}]}}
```

Règles :

1. Le client renvoie `{"action":"ack","revision":1842}` ; sans ack, le serveur agrège à nouveau.
2. Si `revision` saute, le client recharge via REST (`GET /matches/{id}/opportunities`).
3. Le serveur ne pousse jamais de token, d'e-mail ou de donnée d'un autre utilisateur.
4. Coupure : reconnexion avec backoff (1, 2, 4, 8 s max), puis polling 30 s.

---

## 8. Exigences de contrat vérifiées par tests

| # | Test |
|---|---|
| C1 | Toute cote possède `observed_at` et `age_seconds`, cohérents avec `server_time` |
| C2 | Aucune opportunité `A/B` sans `ev_lower > 0` et `is_verified = true` |
| C3 | Un `POST` rejoué avec la même `Idempotency-Key` ne crée pas de doublon |
| C4 | Un utilisateur ne peut pas lire la bankroll d'un autre (`404`) |
| C5 | Un `analyst` ne peut pas activer un modèle (`403`) |
| C6 | Une liste vide d'opportunités renvoie `200` + `no_bet: true` |
| C7 | Le schéma OpenAPI est validé en CI (`openapi-spec-validator`) |
| C8 | Toute réponse contient `request_id` et `server_time` |
