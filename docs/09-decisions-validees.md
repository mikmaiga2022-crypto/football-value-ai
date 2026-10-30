# 09 — Décisions validées et mode « pilote à budget zéro »

Statut : **annexe normative de la Phase 1**. Elle prime sur toute recommandation contraire
des documents 01 à 08, qui n'ont pas été réécrits (traçabilité des arbitrages).

Date des réponses : **30/10/2026**. Répondant : propriétaire du projet.

---

## 1. Journal des décisions

| # | Question (`docs/01` §9) | Réponse retenue | Effet immédiat |
|---|---|---|---|
| V1 | Navigation | **5 onglets** : Accueil, Matchs, Value, Direct, Profil. Favoris / Historique / Statistiques en accès secondaire | Maquettes `design/mockups/01→04` valides, aucune refonte. Les 3 écrans secondaires restent à produire en Phase 2 |
| V2 | Périmètre géographique | **International**, application **gratuite** | Distribution mondiale ; bookmakers filtrés par pays ; aucun revenu en v1 ; voir §2 (conséquences légales) |
| V3 | Cotes Lonabet | **Saisie manuelle** acceptée pour la v1 | Le connecteur manuel devient la **source de cotes principale**, pas un secours |
| V4 | Compétitions | **Étendues** au-delà de la liste par défaut | Liste cible en §3.2, mais **bridée par le quota gratuit** : la v1 n'en sert que 3 |
| V5 | Hébergement | **VPS unique** | Architecture `docs/02` conservée, cible 1 machine |
| V6 | Budget données | **0 € / mois** | Contrainte structurante C0 — §2 |

Deux réponses (V2 « international » et V6 « 0 € ») sont **en tension** avec le reste du dossier.
Cette annexe documente la tension, la chiffre, et fixe le mode de fonctionnement qui la rend
tenable — ou à défaut, identifie ce qui doit être abandonné.

---

## 2. Contrainte C0 : 0 € de données — analyse chiffrée

### 2.1 Le piège du « plan gratuit » The Odds API

Le plan gratuit est de **500 crédits/mois** (vérifié le 30/10/2026, `docs/05` §2.1).
Un crédit ≠ une requête : le coût d'un appel est
`nombre de régions × nombre de marchés`.

| Appel type | Coût | Appels possibles avec 500 crédits |
|---|---|---|
| `regions=eu`, `markets=h2h` | **1 crédit** | 500 |
| `regions=eu`, `markets=h2h,totals` | 2 crédits | 250 |
| `regions=eu,uk`, `markets=h2h,spreads,totals` | 6 crédits | 83 |
| Rafraîchissement live toutes les 60 s sur 3 régions × 3 marchés | 9 crédits/appel | **55 minutes** de live par mois |

Conclusion arithmétique : **le temps réel multi-marchés est hors d'atteinte à 0 €.** Toute
promesse de « cotes live actualisées en continu » serait mensongère dans ce mode.

### 2.2 Le piège du « plan gratuit » API-Football

Plan gratuit : **100 requêtes/jour**, et la documentation le présente comme un usage de **test**.
Trois conséquences :
1. Le quota est suffisant pour 3 compétitions (voir §3.3), pas pour les 10+ compétitions d'un
   périmètre international.
2. L'usage « test » n'autorise pas nécessairement une application publique : **à faire confirmer
   par écrit avant toute bêta ouverte** (risque R12).
3. Les championnats africains et la CAN ont une profondeur statistique inégale : le score de
   qualité de données (`docs/07` §6) doit les déclasser automatiquement, pas les inventer.

### 2.3 Coût réel incompressible du projet

| Poste | Mode 0 € | Mode minimal recommandé |
|---|---|---|
| Données cotes | 500 crédits/mois (The Odds API) | 30 $/mois (20K crédits) |
| Données fixtures/stats | 100 req/jour (API-Football, usage test) | ~19–29 $/mois |
| Hébergement | Oracle Cloud Always Free / équivalent (à valider) | VPS 20–40 €/mois |
| Total | **0 €** (avec quotas durs et dégradations) | **~50–70 €/mois** |

Le mode 0 € est possible **techniquement**. Il n'est acceptable **produit** que sous les
conditions du §3.

---

## 3. Mode « Pilote 0 € » — spécification normative

### 3.1 Cadre

| Paramètre | Valeur v1 |
|---|---|
| Public | Bêta **privée, sur invitation**, ≤ 100 comptes |
| Modèle économique | Aucun (gratuit, sans publicité, sans pari réel dans l'app) |
| Distribution | Internationale, mais **contenu bridé** par pays et par quota |
| Compétitions servies | **3** (voir §3.2) |
| Marchés | `1X2` et `Over/Under 2,5` uniquement |
| Fraîcheur des cotes | Batch 3×/jour + saisie manuelle horodatée |
| Live | **Désactivé** (onglet présent, état « indisponible en mode 0 € ») |
| Prédiction | Statistique (dé-vig + Poisson/Elo), **pas de ML entraîné** |
| Historique de cotes | Constitué par nos propres snapshots, à partir de J0 |

### 3.2 Compétitions (V4 « étendre » bridé par le quota)

Cible théorique enregistrée en base : Ligue 1, Premier League, La Liga, Serie A, Bundesliga,
Ligue des champions, CAN, Fasofoot, Premier Bet Ligue (BF).

**Servies en mode 0 € (3) :** Ligue 1, Premier League, CAN (ou Fasofoot si la CAN est hors
calendrier). Les autres restent `inactive` dans le catalogue : visibles en « bientôt », jamais
avec des données inventées.

Le passage à 8 compétitions est une **décision budgétaire**, pas une décision de code : elle
coûte ~30 $/mois de cotes.

### 3.3 Budget de crédits et gouverneur de quota

Budget cible **≤ 300 crédits/mois sur 500** (marge de 40 % pour les incidents) :

| Tâche | Coût unitaire | Fréquence | Crédits/mois |
|---|---|---|---|
| Batch J-2 (3 compétitions, `h2h`, `eu`) | 1 | 1/jour | 90 |
| Batch J0 matin | 1 | 1/jour | 90 |
| Rafraîchissement midi (2 compétitions prioritaires) | 1 | 1/jour | 60 |
| Rafraîchissement à la demande (fiche match, cache 15 min) | 1 | ≤ 30/mois | 30 |
| **Total plafonné** | | | **270** |

Règles du gouverneur (module `quota`, Phase 3) :
1. Compteur persistant par jour et par mois, alimenté par les en-têtes
   `x-requests-used` / `x-requests-remaining` renvoyés par The Odds API.
2. **Arrêt dur** à 300 crédits/mois : plus aucun appel automatique, l'app passe en mode
   « cotes manuelles uniquement » et l'affiche clairement.
3. Aucun appel déclenché par l'interface utilisateur sans cache valide (15 min par match).
4. Les appels sont **sérialisés** : un seul worker, jamais de rafale parallèle.
5. Journal d'audit de chaque crédit consommé (date, match, marché, région, coût, résultat).

### 3.4 Dégradations obligatoires (aucune donnée inventée)

| Situation | Comportement attendu |
|---|---|
| Quota cotes épuisé | Bandeau « Cotes automatiques suspendues jusqu'au 1er du mois » + saisie manuelle mise en avant. Aucune cote périmée affichée sans son âge. |
| Cote manuelle > 6 h | Badge « cote ancienne », Value recalculée, avertissement avant tout détail |
| Aucune cote sur un match | Fiche en état « Analyse indisponible », pas de probabilité affichée |
| API-Football en échec | Dernier calendrier connu + mention de la date de dernière synchro |
| Compétition non servie | Écran « Non couverte dans cette version » avec la raison (budget, licence) |
| Match commencé | Toute prédiction est **figée** et marquée « pré-match clos » ; plus aucune Value |

### 3.5 Ce que la v1 perd définitivement (à assumer par écrit)

- ❌ Cotes live et Value in-play
- ❌ Marchés secondaires (BTTS, double chance, handicaps asiatiques, buteurs)
- ❌ Plus de 3 compétitions
- ❌ Modèle ML entraîné (pas assez d'historique : voir §5)
- ❌ Backtest sur cotes passées (le plan gratuit n'offre pas d'historique)

Ces éléments ne sont pas « repoussés » : ils sont **conditionnés à un budget** (30 $/mois pour
les cotes, 19–29 $/mois pour les stats).

---

## 4. Impacts document par document

| Document | Impact | Action Phase 2 |
|---|---|---|
| `01-cadrage` | Périmètre devient « international, gratuit, 3 compétitions » | Annexe 09 fait foi ; §9 complété des réponses |
| `02-architecture` | Inchangé techniquement ; ajouter le module `quota` et le mode dégradé | Implémenter le gouverneur avant tout connecteur |
| `03-modele-donnees` | Ajouter la table `api_quota_ledger` et la colonne `coverage_state` sur `competitions` | Migration 001 |
| `04-api-contrat` | Ajouter `GET /v1/system/coverage` et le champ `degraded_reason` dans les réponses | Contrat v1.1 |
| `05-fournisseurs` | Le plan gratuit devient le **mode nominal**, pas un essai | §3 de ce document |
| `06-ux` | Onglet Direct = état vide assumé ; bandeaux de dégradation à maquetter | 3 écrans secondaires + états |
| `07-moteur` | Le dé-vig + Poisson/Elo devient le moteur **de production**, le ML un upgrade | Baseline statistique d'abord |
| `08-roadmap` | Phase 5 (ML) repoussée à M+8 ; Phase 3 réduite à 3 compétitions | Replanification |

### Nouveau découpage des phases

| Phase | Contenu | Durée | Prérequis |
|---|---|---|---|
| 2 | Socle : FastAPI, PostgreSQL, auth, Flutter shell 5 onglets, CI | 3 sem. | — |
| 3 | Données : 3 compétitions, gouverneur de quota, snapshots append-only | 3 sem. | Clés API gratuites |
| 4 | Moteur : dé-vig, Poisson/Elo, EV + IC, scoring A/B/C/D | 3 sem. | 300+ matchs historisés |
| 5 | Saisie manuelle de cote + validation croisée + Value actionnable | 2 sem. | Phase 4 |
| 6 | Bêta privée 100 comptes, mesure de calibration | 4 sem. | Phases 2–5 |
| 7 | ML (gradient boosting) — **si et seulement si** budget + 1 000 matchs | 4 sem. | Décision budget |
| 8 | Live / Sportradar / partenariat LONAB | — | Budget + contrat |

---

## 5. Pourquoi le ML n'est pas en v1 (chiffré)

- 3 compétitions ≈ 30 matchs/semaine ≈ **130 matchs/mois**.
- Un gradient boosting crédible demande ≥ 1 000 matchs étiquetés → **~8 mois** de collecte.
- Le plan gratuit n'offre **aucun historique de cotes** : impossible de backtester un modèle
  avant de l'avoir alimenté soi-même.
- La baseline dé-vig + Poisson/Elo est auditable, explicable, et suffisante pour prouver la
  chaîne « données → probabilité → Value → résultat » en bêta.

Annoncer un « IA » entraînée en v1 serait un mensonge produit. L'application dira
« modèle statistique (Poisson/Elo + marché) » tant que le ML n'est pas justifié.

---

## 6. Risques nouveaux

| # | Risque | Gravité | Mitigation |
|---|---|---|---|
| R11 | Quota gratuit épuisé en 10 jours par un usage mal cadré | Élevée | Gouverneur + arrêt dur + alertes à 60 % et 85 % |
| R12 | Plan gratuit API-Football réservé aux tests → bêta publique non conforme | **Critique** | Demander l'autorisation écrite ; sinon bêta strictement privée et non commerciale |
| R13 | Périmètre international + app gratuite = obligation de conformité multi-pays (jeu, données, publicité) | Élevée | Restreindre la distribution aux pays où aucun opérateur n'est promu ; mention légale par pays |
| R14 | 3 compétitions seulement = faible perceived value pour un utilisateur international | Moyenne | Assumer explicitement le mode « pilote » ; publier la feuille de route budget |
| R15 | Aucune cote locale accessible → utilisateurs internationaux voient des cotes qu'ils ne peuvent pas jouer | Élevée | Filtre bookmakers par pays + saisie manuelle comme voie principale |

---

## 7. Ce qui reste à confirmer avant d'écrire du code

1. **Bêta privée** (≤ 100 comptes, invitation, non commerciale) : acceptable ? C'est la seule
   façon de rester dans les clous avec des plans gratuits.
2. **3 compétitions** en v1 : Ligue 1, Premier League, CAN — ou un autre trio ?
3. **Baseline statistique** au lieu de « ML » en v1 : acceptable, avec le ML à M+8 ?

Si ces trois points sont confirmés, la Phase 1 est close et la Phase 2 peut démarrer.
