# 07 — Spécification du moteur de Value Betting

Version 1.0 — Phase 1. Les formules ci-dessous sont **normatives** : elles seront implémentées
telles quelles et couvertes par les tests de `docs/08`.

---

## 1. Notations

| Symbole | Sens |
|---|---|
| `o_i` | cote décimale de l'issue *i* |
| `q_i = 1/o_i` | probabilité implicite brute |
| `S = Σ q_i` | somme des probabilités implicites du marché |
| `m = S − 1` | marge (overround) du bookmaker |
| `π_i` | probabilité implicite **sans marge** |
| `p_i` | probabilité estimée par l'IA |
| `[p⁻, p⁺]` | intervalle de confiance à 95 % de `p_i` |
| `EV_i` | espérance de valeur |
| `c_i = 1/p_i` | cote juste |

Toutes les probabilités sont dans `]0, 1[`. Toute cote est `> 1.00`.

---

## 2. Marge et probabilités sans marge

### 2.1 Marge

```
m = Σ (1 / o_i) − 1
```

Exemple : `1X2` à 2,10 / 3,40 / 3,60 → `q = 0,476190 / 0,294118 / 0,277778`,
`S = 1,048086`, **marge = 4,81 %**.

Une marge supérieure à `max_margin` du marché disqualifie la sélection (gate G4).

### 2.2 Méthodes de retrait de marge

Quatre méthodes sont implémentées et comparées. Le choix par marché est **data-driven**, pas
idéologique : on retient la méthode qui minimise le log loss des probabilités de marché sur
l'historique de clôture.

| Méthode | Formule | Propriété |
|---|---|---|
| **Proportionnelle** | `π_i = q_i / S` | Simple, préserve les rapports ; surévalue les favoris |
| **Additive** | `π_i = q_i − m/n` | Corrige uniformément ; peut rendre une probabilité ≤ 0 sur gros outsiders |
| **Puissance** | `π_i = q_i^k`, `k` tel que `Σ q_i^k = 1` | Meilleure sur les marchés déséquilibrés |
| **Shin** | `π_i = (√(z² + 4(1−z) q_i²/S) − z) / (2(1−z))`, `z` tel que `Σ π_i = 1` | Modélise la sélection adverse ; référence académique |
| **Odds-ratio** | itératif : `π_i ∝ q_i · (π_i / q_i)^λ` | Compromis, utile sur les marchés à forte marge |

`k` et `z` sont résolus numériquement (bissection, tolérance `1e-10`, 200 itérations max).

**Défaut v1** : proportionnelle (traçable, stable), Shin activé pour `1X2` et `AH` après validation
en backtest. La méthode utilisée est **stockée** dans `value_bets.explanation.margin_method`.

### 2.3 Contrôles

- `S < 1` (arbitrage ou donnée erronée) → la cote est rejetée à l'ingestion, pas « corrigée ».
- `m > 0.15` → donnée suspecte (marché peu liquide ou erreur), sélection écartée.
- Une seule cote manquante dans un marché à issues exhaustives (`1X2`, `BTTS`) → pas de calcul
  sans marge ; on peut seulement comparer à la cote juste, sans revendiquer d'edge.

---

## 3. Cote juste, edge, espérance de valeur

```
cote juste       c_i = 1 / p_i
edge             e_i = p_i − π_i
EV               EV_i = p_i · o_i − 1
EV en %          EV_i × 100
```

Relation utile : `EV_i > 0  ⇔  o_i > 1/p_i  ⇔  o_i > c_i`.

**Exemple normatif (vecteur de test T1)**

| Donnée | Valeur |
|---|---|
| `o` | 1,95 |
| `p` | 0,58 |
| `cote juste` | 1,7241 |
| `EV` | 0,58 × 1,95 − 1 = **0,1310** (+13,10 %) |
| Marché 2 issues à 1,95 / 1,95 | `S = 1,025641`, marge 2,56 %, `π = 0,5000` |
| `edge` | 0,58 − 0,50 = **0,0800** |

**Exemple T2 (marge 3 issues)**

| `o` | `q` | `π` (proportionnelle) |
|---|---|---|
| 2,10 | 0,476190 | 0,454345 |
| 3,40 | 0,294118 | 0,280624 |
| 3,60 | 0,277778 | 0,265031 |

Somme `π = 1,000000` (à 1e-6 près).

---

## 4. Incertitude

### 4.1 Intervalle de confiance de la probabilité

Trois sources, combinées :

1. **Incertitude du modèle** : bootstrap sur les paramètres (1 000 rééchantillonnages,
   `p⁻ = quantile 2,5 %`, `p⁺ = quantile 97,5 %`).
2. **Incertitude des données** : pénalité liée aux données manquantes (voir §5).
3. **Incertitude de marché** : dispersion des cotes sans marge entre bookmakers (si ≥ 3 books).

On retient l'intervalle le plus large des trois. `uncertainty = p⁺ − p⁻`.

### 4.2 Intervalle de l'EV

`EV` est monotone croissante en `p` :

```
EV⁻ = p⁻ · o − 1
EV⁺ = p⁺ · o − 1
```

La **borne basse `EV⁻` est le critère principal**, pas l'EV central. Une sélection dont
`EV⁻ ≤ 0` ne peut jamais être `A` ou `B`.

> Justification : avec `p = 0,58 ± 0,035` et `o = 1,95`, l'EV central vaut +13,1 % mais la borne
> basse vaut `0,545 × 1,95 − 1 = +6,3 %`. Si l'intervalle était `±0,08`, la borne basse serait
> négative et la recommandation serait refusée.

---

## 5. Score de qualité des données (`data_quality_score`)

Moyenne pondérée de composantes dans `[0,1]` :

| Composante | Poids | Calcul |
|---|---|---|
| Historique équipes (nb de matchs) | 0,25 | `min(1, n_matchs / 20)` pour chaque équipe, moyenne |
| Statistiques avancées (xG) | 0,15 | 1 si xG des deux équipes, 0,5 si une seule, 0 sinon |
| Composition | 0,15 | 1 officielle, 0,6 probable, 0 sinon |
| Blessures/suspensions | 0,10 | 1 si liste complète et fraîche (< 48 h), 0 sinon |
| Couverture des cotes | 0,20 | `min(1, nb_bookmakers / 3)` |
| Fraîcheur | 0,15 | 1 si < 60 s, décroît linéairement jusqu'à 0 à `max_age_seconds` |

`DQ < 0,60` → aucune recommandation supérieure à `C`. `DQ < 0,45` → `NO BET`.

Les composantes et leurs poids sont **versionnés** (`system_settings.data_quality.v1`).

---

## 6. Score de priorité et gates

### 6.1 Gates éliminatoires (dans l'ordre)

| Gate | Condition d'échec | Effet |
|---|---|---|
| G1 — fraîcheur | `age > max_age_seconds` du marché | sélection retirée |
| G2 — vérification | `is_verified = false` | priorité plafonnée à `C` |
| G3 — disponibilité | `is_available = false` | sélection retirée |
| G4 — marge | `m > max_margin` | sélection retirée |
| G5 — données | `DQ < 0,45` | `NO BET` |
| G6 — cote | `o < min_odds` ou `o > max_odds` | sélection retirée |
| G7 — EV | `EV < min_ev` | `NO BET` pour cette sélection |
| G8 — incertitude | `EV⁻ < min_ev_lower` | priorité plafonnée à `D` (donc `NO BET` si le seuil A/B l'exige) |
| G9 — calibration | `ECE_market > 0,08` | priorité plafonnée à `C` |
| G10 — liquidité | bookmaker `manual` et non confirmé | priorité plafonnée à `C` |

### 6.2 Score continu (0–100)

Pour une sélection passant G1–G7 :

```
S = 100 × (
      0,28 × EV_n
    + 0,18 × Edge_n
    + 0,20 × Conf_n
    + 0,14 × Calib_n
    + 0,12 × DQ_n
    + 0,08 × Hist_n
    ) − P
```

| Terme | Normalisation |
|---|---|
| `EV_n` | `clamp(EV / 0,15, 0, 1)` |
| `Edge_n` | `clamp(edge / 0,10, 0, 1)` |
| `Conf_n` | `1 − clamp((p⁺ − p⁻) / 0,20, 0, 1)` |
| `Calib_n` | `1 − clamp(ECE_market / 0,10, 0, 1)` |
| `DQ_n` | `DQ` |
| `Hist_n` | `clamp((ROI_marché_shrunk + 0,05) / 0,15, 0, 1)` avec `ROI_shrunk = ROI × n/(n+200)` |

Pénalités `P` :

| Situation | Points |
|---|---|
| Cote non vérifiée | −25 (et plafond C) |
| Cote > 60 % de la fenêtre de fraîcheur | −10 |
| Composition inconnue | −5 |
| Bookmaker non accessible dans le pays de l'utilisateur | −15 (et badge d'avertissement) |
| Marché à faible échantillon (`n < 50`) | −10 |

### 6.3 Niveaux

| Priorité | Condition | Affichage |
|---|---|---|
| **A** | `S ≥ 75` **et** `EV ≥ min_ev` **et** `EV⁻ ≥ min_ev_lower` **et** `DQ ≥ 0,75` **et** cote vérifiée | Vert, notification autorisée |
| **B** | `S ≥ 62` et gates OK | Bleu |
| **C** | `S ≥ 48` ou plafond `C` | Orange, « à surveiller » |
| **D** | `S ≥ 30` | Gris, non recommandé |
| **NO BET** | `S < 30` ou `EV < min_ev` ou échec G5/G7 | Aucune sélection |

**Règle produit** : préférer `NO BET`. Un match peut n'avoir aucune sélection : c'est le cas normal.

### 6.4 Vecteur de test T3

`p = 0,58`, `p⁻ = 0,545`, `p⁺ = 0,614`, `o = 1,95`, `π = 0,50`, `DQ = 0,86`,
`ECE = 0,028`, `ROI_shrunk = 0,02`, cote vérifiée il y a 42 s.

```
EV = 0,1310 → EV_n = 0,873
edge = 0,0800 → Edge_n = 0,800
Conf_n = 1 − (0,069/0,20) = 0,655
Calib_n = 1 − 0,28 = 0,720
DQ_n = 0,860
Hist_n = clamp((0,02 + 0,05)/0,15) = 0,467
S = 100 × (0,28×0,873 + 0,18×0,800 + 0,20×0,655 + 0,14×0,720 + 0,12×0,860 + 0,08×0,467)
  = 100 × (0,2445 + 0,1440 + 0,1310 + 0,1008 + 0,1032 + 0,0374)
  = 76,09 → A
```

`EV⁻ = 0,545 × 1,95 − 1 = 0,0628 > 0,005` et `DQ = 0,86 ≥ 0,75` → **A** confirmé.

Ce vecteur est un test obligatoire : toute implémentation doit retrouver `S ≈ 76,1` (±0,1).

---

## 7. Couverture des marchés par les modèles

| Marché | Modèle | Sortie | Contrainte |
|---|---|---|---|
| 1X2, DC, DNB | Matrice de scores (Poisson bivarié / Dixon-Coles) | `P(H)`, `P(D)`, `P(A)` | somme = 1 |
| Totaux (0,5 → 5,5) | Somme des scores | `P(total > ligne)` | lignes réelles du bookmaker |
| BTTS | Matrice de scores | `P(H>0 ∧ A>0)` | — |
| Score exact | Matrice de scores | top 10 + `OTHER` | normalisation |
| Mi-temps | Modèle de buts 1re MT (taux réduit calibré) | 1X2 MT, O/U MT | données MT requises |
| Handicap asiatique | Matrice + règlement de ligne | `P(win)`, `P(push)`, `P(half)` | quart de ligne géré |
| Corners | Binomiale négative par équipe | total et handicaps | données corners ≥ 20 matchs |
| Cartons | Poisson/NB par équipe + arbitre | total et handicaps | données cartons + arbitre |
| Joueurs (buts) | Poisson (taux/90 × minutes probables) | anytime, first | titularisation requise |
| Combinés | Copule / matrice jointe | probabilité conjointe | voir §8 |

**Un marché sans modèle validé n'est pas affiché comme analysé.** Il peut être affiché en
« cotes seules », sans probabilité IA ni EV.

---

## 8. Corrélations et combinés

### 8.1 Interdit

Multiplier naïvement `P(Over 2,5) × P(BTTS)` sur le **même match** : ces événements sont
fortement corrélés (tous deux dépendent du nombre de buts). Une telle combinaison gonfle ou
écrase artificiellement la probabilité et fabrique de fausses Value.

### 8.2 Méthode pour un même match

1. Construire la matrice jointe `P(h, a)` (scores).
2. Évaluer chaque sélection comme un sous-ensemble de cellules.
3. `P(A ∧ B) = Σ P(h,a) · 1[A] · 1[B]` — probabilité exacte, sans hypothèse d'indépendance.
4. La cote combinée du bookmaker `o_AB` est comparée à `1/P(A ∧ B)`.
5. Vérifier que le bookmaker **accepte** la combinaison (règles : certains marchés du même match
   sont incompatibles, ex. 1X2 et Double chance).

### 8.3 Multi-matchs

L'indépendance entre matchs distincts est **raisonnable mais non garantie** (facteurs communs :
week-end international, météo, arbitrage). On applique :

```
P_combo = Π p_j × (1 + ρ_adj)
```

`ρ_adj` est estimé sur l'historique des résidus de modèle (corrélation moyenne des erreurs par
journée) et borné à ±0,02. Si les matchs partagent une compétition et une journée, `ρ_adj` est
estimé ; sinon 0.

### 8.4 Règles produit

- Maximum **3 jambes** par combiné en v1.
- Pas de combiné si une jambe est `C` ou moins.
- EV du combiné calculé sur la probabilité jointe, avec IC bootstrap.
- Affichage obligatoire : « La cote combinée inclut la marge du bookmaker sur chaque jambe. »
- Aucun combiné proposé automatiquement : l'utilisateur le construit.

---

## 9. Gestion de mise (simulation uniquement)

```
f* = (p · o − 1) / (o − 1)          (Kelly)
mise = bankroll × min(f* × k, cap)
```

- `k` = fraction de Kelly, défaut **0,25**, plafonnée à 0,5.
- `cap` = 1 % de la bankroll par pari (défaut), 5 % par jour.
- `f* ≤ 0` → pas de mise.
- **Aucune Martingale, aucune progression multiplicative après perte.**
- La bankroll initiale est définie par l'utilisateur ; aucun montant par défaut n'est imposé.
- La simulation est toujours étiquetée « simulé » ; aucun paiement réel.

Exemple : `p = 0,58`, `o = 1,95` → `f* = (1,131 − 1)/0,95 = 0,1379` (13,8 %),
avec `k = 0,25` → 3,45 %, plafonné à 1 % → **1 % de la bankroll**.

---

## 10. Évaluation et calibration

| Métrique | Formule | Usage |
|---|---|---|
| Brier | `(1/N) Σ (p_i − y_i)²` | probabilités 1X2, BTTS, O/U |
| Log loss | `−(1/N) Σ [y ln p + (1−y) ln(1−p)]` | comparaison de modèles |
| RPS (Ranked Probability Score) | somme des écarts cumulés sur les issues ordonnées | 1X2 (tient compte de l'ordre H > D > A) |
| ECE | `Σ (n_b/N) · |acc_b − conf_b|` sur 10 bins | calibration |
| Courbe de calibration | `observed_rate` vs `mean_predicted` par bin | diagnostic visuel |
| CLV | `o_prise / o_clôture − 1` | qualité de la prise de cote |
| ROI | `profit / misé` | performance |
| Yield | identique au ROI dans ce contexte | — |
| Drawdown max | plus forte baisse depuis un sommet | risque |
| Taux de réussite | `gagnées / réglées` | indicatif seulement |

Une probabilité est **calibrée** si `ECE ≤ 0,05` et si la courbe reste dans la bande ±5 points
sur tous les bins ayant `n ≥ 30`.

---

## 11. Backtest et validation

### 11.1 Protocole

1. **Split chronologique strict** : train < validation < test, jamais de mélange aléatoire.
2. **Purge** : supprimer les matchs dont le résultat chevauche la fenêtre d'entraînement.
3. **Embargo** : 7 jours entre train et test pour éviter la fuite par mise à jour tardive.
4. **Features as-of** : uniquement les données disponibles avant le coup d'envoi
   (`prediction_contexts.feature_cutoff`).
5. **Walk-forward** : fenêtre glissante de 3 saisons, réentraînement mensuel simulé.
6. **Sélections ≥ 1 000** pour publier un ROI, avec IC bootstrap par match (block bootstrap).
7. **Comparaison au marché** : log loss du modèle vs log loss des probabilités sans marge.
8. **Pas de conclusion si `n < 1 000`** ; pas de promesse de rentabilité.

### 11.2 Ce qui invalide un backtest

- Cotes d'ouverture utilisées avec des features de fin de match.
- Résultats du match dans les features.
- Sélection des seuils **après** avoir vu le test (overfitting).
- Absence de correction pour tests multiples (12 marchés × 4 seuils).
- ROI calculé sans les matchs nuls/remboursés (DNB, AH).

### 11.3 Livrables phase 4

- Rapport par marché : n, Brier, log loss, ECE, ROI, yield, drawdown, CLV, IC.
- Courbes de calibration.
- Analyse par compétition et par tranche de cotes.
- Journal des versions de modèles et des seuils.
- Jeu de données de test gelé et reproductible (hash).

---

## 12. Règlement des marchés (extraits)

| Marché | Règle implémentée |
|---|---|
| 1X2 | 90 min + arrêts, prolongations exclues |
| DNB | nul → mise remboursée (mise rendue, profit 0) |
| AH ligne entière | nul après handicap → remboursé |
| AH demi-ligne | pas de remboursement |
| AH quart de ligne | demi-mise sur chaque demi-ligne, combinaison `won/half_won/push/half_lost/lost` |
| O/U | strictement supérieur/inférieur à la ligne |
| BTTS | les deux équipes marquent au moins une fois |
| CS | score final exact, temps réglementaire |
| Corners / cartons | selon le règlement du bookmaker (stocké dans `markets.settlement_rules`) |
| Joueur | titularisation et temps de jeu selon le bookmaker ; un joueur entré en jeu peut être réglé différemment |

Chaque règlement est **testé** avec des cas limites (0-0, 2-2, quart de ligne, abandon, forfait).

---

## 13. Propriétés testables (extrait)

| # | Propriété |
|---|---|
| P1 | `Σ π_i = 1` à `1e-6` pour chaque méthode |
| P2 | `EV = p·o − 1` et `cote juste = 1/p` à `1e-6` |
| P3 | Monotonie : `o₁ > o₂ ⇒ EV(o₁) > EV(o₂)` à `p` constant |
| P4 | Aucune priorité `A/B` si `EV⁻ ≤ 0` |
| P5 | Aucune priorité `A` si cote non vérifiée |
| P6 | Un marché à marge > `max_margin` ne produit aucune sélection |
| P7 | `P(A ∧ B)` d'un même match ≠ `P(A)·P(B)` (sauf indépendance démontrée) |
| P8 | La somme des probabilités 1X2 = 1 à `1e-6` |
| P9 | Un combiné de 2 jambes dont une `D` est refusé |
| P10 | Kelly ≤ cap, et `f* ≤ 0 ⇒ mise = 0` |
| P11 | Aucune prédiction ne contient une donnée postérieure à `feature_cutoff` |
| P12 | Rejouer le même payload d'ingestion ne crée pas de doublon |
