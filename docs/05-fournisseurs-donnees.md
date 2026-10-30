# 05 — Fournisseurs de données : diagnostic sur sources réelles

Vérifications effectuées le **30/10/2026** directement sur les pages officielles des fournisseurs.
Chaque affirmation est sourcée. Les prix et couvertures changent : **revalider avant contrat**.

> **Mise à jour du 30/10/2026 — le budget données validé est de 0 €.** Le plan gratuit devient
> donc le mode **nominal** et non un essai. Budget de crédits, gouverneur de quota, dégradations
> et replanification : voir **[`09-decisions-validees.md`](09-decisions-validees.md) §2–3**.
> Conséquence : 3 compétitions, marchés `1X2` + `O/U 2,5`, aucun live, aucun historique acheté.

> **Méthode.** Aucun scraping n'a été effectué. Les constats proviennent des documentations et
> grilles tarifaires publiques. Les extraits de cotes réelles ne peuvent être obtenus qu'après
> souscription d'une clé (The Odds API, API-Football) ou accord écrit (Lonabet).

---

## 1. Synthèse décisionnelle

| Fournisseur | API | Cotes | Stats | Live | Licence commerciale | Coût | Décision |
|---|---|---|---|---|---|---|---|
| **The Odds API** | REST JSON | ~100 bookmakers, 1xBet, Pinnacle, Betano, Betclic, PMU | non | oui (in-play) | oui, payante | 0 $ (500 crédits) → 30 $/20K → 59 $/100K | **Retenu** : cotes |
| **API-Football** | REST JSON | pre-match (couverture partielle) | oui, riche | oui | oui, payante | dès 19 $/mois (à confirmer) | **Retenu** : fixtures + stats |
| **TheStatsAPI** | REST | oui | oui (xG, tirs…) | ? | oui | non publié | **Option** : alternative à API-Football |
| **Sportradar / Betradar** | REST + push | tous marchés | oui | oui | oui, contrat | entreprise (milliers €/mois) | **Phase 6+** |
| **Football-Data.co.uk** | CSV seulement | historique 27 saisons | oui | non | **interdit en produit commercial / IA** | gratuit (privé) | **Exclu production** |
| **BetMines** | aucune API publique | — | — | — | — | app grand public | **Écarté** |
| **Datafoot** | aucune API publique | — | — | — | — | — | **Écarté** |
| **Lonabet (LONAB)** | aucune API publique documentée | cotes locales | non | oui (site) | opérateur d'État | partenariat | **Manuel + partenariat** |

---

## 2. Détail par fournisseur

### 2.1 The Odds API — retenu pour les cotes

**Faits vérifiés** (`the-odds-api.com`, 30/10/2026) :

- Plans : **Free 500 crédits/mois** (pas d'historique), **20K crédits 30 $/mois**,
  **100K 59 $/mois**, 5M 119 $/mois, 15M 249 $/mois.
- 1 requête = 1 sport + 1 marché + 1 région. Le coût réel dépend donc du nombre de marchés
  interrogés, pas du nombre de matchs.
- Couverture football : Premier League, Bundesliga, Serie A, La Liga, Ligue 1, compétitions
  UEFA, Brésil, etc.
- Bookmakers EU disponibles : **1xBet**, **Pinnacle**, Betfair, Unibet, Betclic (FR), PMU (FR),
  Betsson, Marathonbet, William Hill…
- Historique disponible depuis 2020 (plans payants).
- Pinnacle : « odds are from public website which may incur a delay » — donc **pas une source
  de clôture fiable**, à utiliser avec prudence.
- Formats : décimal et américain ; JSON.

**Conséquences d'architecture**

1. Nos deux sources de cotes principales (1xBet, Pinnacle) sont **européennes**, pas burkinabè.
   → Ne jamais présenter ces cotes comme « disponibles » pour un utilisateur au Burkina Faso
   sans vérifier l'accès légal et réel à l'opérateur.
2. Le coût explose si l'on interroge 12 marchés × 6 régions toutes les 60 s.
   → Stratégie : 1 appel groupé `markets=h2h,totals,spreads` par compétition active, cache 60 s,
   priorisation des matchs à J-1 et J0, marchés secondaires en batch nocturne.
3. L'absence d'historique sur le plan gratuit impose de **constituer notre propre historique**
   dès la phase 3 (snapshots append-only), pas de backtest rétroactif sur cotes passées sans plan payant.

**Mapping à prévoir** : noms d'équipes (« Manchester United » vs « Man United »), fuseaux,
marchés (`h2h` → `1X2`, `totals` → `OU`, `spreads` → `AH`), lignes.

### 2.2 API-Football (API-Sports) — retenu pour fixtures et statistiques

**Faits vérifiés** (pages publiques + extrait tarifaire, 30/10/2026) :

- API REST documentée, endpoints `fixtures`, `leagues`, `teams`, `standings`, `statistics`,
  `odds` (pre-match), `injuries`, `lineups`.
- Tous les plans incluent « all competitions and endpoints » selon la page tarifaire.
- Plan gratuit : 100 requêtes/jour (usage de test uniquement).
- Plans payants à partir d'environ **19 $/mois** (à confirmer sur la page officielle, accès 403
  lors de la vérification).
- Couverture annoncée : plus de 1 000 compétitions ; qualité inégale hors grandes ligues.
- Limites de débit par plan ; quotas journaliers.

**Conséquences**

- Suffisant pour le calendrier, les classements, la forme, les compositions et les blessures
  des grandes ligues.
- **Ne pas** supposer que les championnats burkinabè, la CAN ou les divisions africaines ont
  des statistiques détaillées (xG, compositions). Le score de qualité de données doit le refléter.
- Les cotes API-Football ne remplacent pas The Odds API : couverture bookmakers plus faible.

### 2.3 Sportradar / Betradar — cible pour le live sérieux

- Données officielles, bas débit, marchés exhaustifs, settlements.
- L'accès aux données officielles de Premier League/EFL passe par Football DataCo et ses
  licenciés (Genius Sports), ce qui explique le coût et la complexité contractuelle.
- **Aucun tarif public** : devis obligatoire, engagement annuel probable.
- Décision : ne pas engager avant d'avoir prouvé la valeur du produit en pré-match.

### 2.4 Football-Data.co.uk — exclu de la production

**Fait déterminant** (page `data.php`, 30/10/2026) :

> « it's all FREE, however its use is intended for private individuals only, **NOT commercial
> or data training products using automated bots/scrapers/AI**. »

- 32 saisons de résultats, 27 saisons de cotes, statistiques depuis 2000/01, 22 divisions
  européennes + 16 divisions mondiales.
- Depuis le 23/07/2025, les cotes Pinnacle sont signalées comme peu fiables (API publique
  instable) et exclues des moyennes de marché par l'éditeur.

**Conséquences**

- **Interdit** comme source de production, d'entraînement commercial ou de redistribution.
- Utilisable uniquement pour une **étude privée** de faisabilité, avec accord écrit de l'éditeur.
- Toute mention « backtest réalisé sur football-data.co.uk » dans une communication commerciale
  serait contraire à leurs conditions.

### 2.5 TheStatsAPI — alternative crédible

- Partenaire officiel mis en avant par Football-Data, API commerciale avec résultats, stats
  détaillées (xG, tirs, corners, cartons) et cotes.
- Tarifs non publiés sur la page consultée → demander un devis.
- À comparer à API-Football en phase 3 sur : couverture africaine, xG, historique, latence, prix.

### 2.6 BetMines et Datafoot — écartés

- **BetMines** : application grand public de pronostics (abonnements), **aucune API publique
  documentée** trouvée. Utiliser ses pronostics comme source serait contraire à ses conditions
  et méthodologiquement contestable (boîte noire).
- **Datafoot** : pas de documentation d'API publique ni de grille tarifaire accessible.
- Décision : ne pas intégrer. Si un contrat existe, il fera l'objet d'un adaptateur dédié.

### 2.7 Lonabet (LONAB) — le point critique

- La LONAB est l'opérateur historique des paris au Burkina Faso ; son offre en ligne
  (« Lonabet », `lonabet.bf`) est promue officiellement.
- **Aucune API publique documentée** n'a été trouvée. Le site est une application web ;
  l'extraire par scraping serait contraire aux conditions d'utilisation et fragile.
- Or c'est **le bookmaker réellement accessible** à l'utilisateur burkinabè cible.

**Trois options, par ordre de préférence :**

| Option | Description | Avantage | Limite |
|---|---|---|---|
| A. Partenariat | Accord écrit LONAB / Lonabet pour un flux de cotes | Automatique, légal, actionnable | Négociation longue, incertaine |
| B. Saisie manuelle vérifiée | L'utilisateur saisit la cote et l'heure ; l'app calcule la Value | Immédiat, légal, aucune dépendance | Charge utilisateur, qualité variable, pas de `A` sans vérification |
| C. Cotes internationales | Afficher 1xBet/Pinnacle avec un badge « opérateur non disponible au BF » | Riche, gratuit à mettre en place | Value non actionnable, risque de tromperie |

**Décision Phase 1 : B par défaut, A en démarche parallèle, C en mode « référence de marché »
explicitement étiqueté, jamais présenté comme une cote accessible.**

Règle produit : une cote `manual` non confirmée ne peut jamais produire une priorité `A` ou `B`.
Elle peut produire `C` (à surveiller) avec la mention « cote non vérifiée ».

---

## 3. Diagnostic global (ce que les données réelles disent du projet)

1. **Le calendrier et les statistiques sont accessibles** pour les grandes ligues, à coût
   maîtrisé (< 60 €/mois). Le projet est faisable.
2. **Les cotes sont accessibles**, mais pas celles de l'opérateur local. C'est le risque n°1.
3. **Le live est cher** : seule une source entreprise (Sportradar) donne un live fiable et
   licencié. Le live « gratuit » est soit retardé, soit non licencié.
4. **L'historique de cotes n'est pas gratuit** : il faut le construire soi-même à partir de la
   phase 3, ce qui retarde tout backtest sérieux de 6 à 12 mois de collecte.
5. **Les données africaines sont pauvres** : xG, compositions et blessures seront souvent absents.
   Le produit doit assumer des analyses moins précises sur ces compétitions (score de qualité
   de données visible, priorité plafonnée).
6. **Aucun fournisseur ne garantit la rentabilité** : le moteur doit être jugé sur sa calibration
   et son CLV, pas sur une promesse.

**Conséquence sur le planning** : le backtest « 1 000 sélections » exigé au §14 du prompt ne peut
pas être honnêtement produit avant plusieurs mois de collecte réelle. La phase 4 livrera un
backtest sur données historiques licenciées (The Odds API historique ou TheStatsAPI) **et** un
protocole de validation prospective (paper trading) sur 1 000 sélections.

---

## 4. Protocole d'audit données (72 h, avant Phase 3)

À exécuter dès qu'une clé de test est disponible. Objectif : valider la couverture réelle, pas
les promesses commerciales.

| Étape | Action | Livrable |
|---|---|---|
| 1 | Souscrire le plan gratuit The Odds API (500 crédits) | Clé en variable d'env, jamais en Git |
| 2 | Compter les matchs de football disponibles sur 7 jours, par compétition | Tableau de couverture |
| 3 | Compter les bookmakers retournés pour `soccer_epl`, `soccer_france_ligue_one`, `soccer_uefa_champs_league` | Liste réelle |
| 4 | Vérifier les marchés réellement disponibles par bookmaker (`markets` endpoint) | Matrice marché × bookmaker |
| 5 | Mesurer la latence et l'intervalle de mise à jour sur 24 h | p50/p95, fraîcheur |
| 6 | Comparer 20 cotes 1xBet/Pinnacle à l'affichage public au même instant | Écart, retard |
| 7 | Vérifier la couverture API-Football sur 5 compétitions africaines | % de matchs avec stats |
| 8 | Estimer le coût mensuel réel (crédits consommés × fréquence) | Budget |

**Critère de passage en Phase 3 :** ≥ 90 % des matchs des compétitions cibles ont calendrier +
cotes, et le coût projeté reste < 150 €/mois.

---

## 5. Architecture des connecteurs

```
providers/
  base.py            RawFixture, RawOdd, RawStats, ProviderHealth, Protocol
  odds_api.py        The Odds API      (API key, quotas, régions)
  api_football.py    API-Football      (fixtures, stats, lineups)
  lonabet_manual.py  saisie utilisateur (validation, horodatage, anti-abus)
  partner_feed.py    emplacement réservé (contrat à venir)
  registry.py        activation par configuration, jamais par code conditionnel
```

Règles communes :

1. **Timeout** 10 s, 3 tentatives avec backoff, disjoncteur après 5 échecs (5 min).
2. **Validation** : type, plage, cohérence (cote > 1, probabilité implicite, ligne multiple de 0,25,
   équipes distinctes, date future pour un match programmé).
3. **Idempotence** : hash du payload + clé naturelle ; un doublon est ignoré, pas réinséré.
4. **Traçabilité** : `ingestion_runs` + `raw_payloads` (7 jours) + `provider_health`.
5. **Quotas** : compteur Redis, arrêt automatique à 80 %, alerte à 90 %, jamais de dépassement
   silencieux.
6. **Aucune clé dans les logs**, aucun payload brut contenant un secret.
7. **Devise et fuseau** : tout est converti en UTC + décimal dès l'entrée.

---

## 6. Matrice de couverture attendue (à confirmer par l'audit)

| Donnée | The Odds API | API-Football | Sportradar | Lonabet manuel |
|---|---|---|---|---|
| Calendrier | partiel (matchs à cotes) | ✅ | ✅ | — |
| Résultats | ✅ (scores) | ✅ | ✅ | — |
| Classements | ❌ | ✅ | ✅ | — |
| xG | ❌ | partiel | ✅ | — |
| Compositions | ❌ | ✅ (grandes ligues) | ✅ | — |
| Blessures | ❌ | ✅ (partiel) | ✅ | — |
| Cotes 1X2 | ✅ | partiel | ✅ | ✅ |
| Totaux / BTTS | ✅ | partiel | ✅ | ✅ |
| Handicaps | ✅ | limité | ✅ | ✅ |
| Corners / cartons | ✅ (certains books) | ❌ | ✅ | ✅ |
| Joueurs | limité | ❌ | ✅ | ✅ |
| Live | ✅ (retard possible) | ✅ | ✅ | ✅ |

« partiel » = dépend de la compétition et du plan ; à mesurer, jamais à supposer.
