# 06 — UX/UI Android : design system et maquettes

Version 1.0 — Phase 1. Les maquettes filaires ci-dessous sont **la référence contractuelle**.
Les visuels `design/mockups/*.svg` en sont l'habillage.

---

## 1. Principes de conception

1. **La réponse avant la donnée.** L'utilisateur voit d'abord « y a-t-il une opportunité ? »,
   puis les chiffres qui la justifient.
2. **Le doute est visible.** Toute incertitude (données manquantes, cote ancienne, modèle peu
   calibré) est affichée, pas cachée.
3. **Pas de fausse précision.** On affiche 58 %, pas 58,37 % ; l'EV à 0,1 point près.
4. **Une seule action principale par écran.**
5. **Zéro culpabilisation, zéro promesse.** Aucun « gain garanti », aucun compte à rebours agressif.
6. **Utilisable à une main, en 3G, sur un écran 360 dp.**

---

## 2. Design system

### 2.1 Couleurs

| Token | Sombre | Clair | Usage |
|---|---|---|---|
| `bg` | `#0B0F14` | `#F6F8FA` | Fond |
| `surface` | `#121821` | `#FFFFFF` | Cartes |
| `surfaceAlt` | `#1A2230` | `#EEF2F6` | Lignes, puces |
| `border` | `#243044` | `#DDE3EA` | Séparateurs |
| `text` | `#EAF0F7` | `#111827` | Texte principal |
| `textMuted` | `#8A94A6` | `#5B6675` | Secondaire |
| `primary` | `#00D68F` | `#00875A` | Action, valeur positive |
| `accent` | `#4CD7F6` | `#0077B6` | Information, priorité B |
| `warning` | `#FFB020` | `#B26A00` | Priorité C, données partielles |
| `danger` | `#FF5A5F` | `#C62828` | Erreur, valeur négative |
| `priorityA` | `#00D68F` | `#00875A` | A |
| `priorityB` | `#4CD7F6` | `#0077B6` | B |
| `priorityC` | `#FFB020` | `#B26A00` | C |
| `priorityD` | `#8A94A6` | `#5B6675` | D |
| `noBet` | `#5A6473` | `#6B7280` | NO BET |

Contraste minimum 4,5:1 pour le texte, 3:1 pour les éléments graphiques. La couleur ne porte
**jamais** seule une information : toujours couleur + lettre (A/B/C/D) + libellé.

### 2.2 Typographie

| Rôle | Taille / graisse | Police |
|---|---|---|
| Titre écran | 22 / 700 | Inter |
| Titre section | 13 / 700, majuscules, `letter-spacing 0.08em` | Inter |
| Corps | 15 / 400 | Inter |
| Carte — équipe | 16 / 600 | Inter |
| Chiffre clé (cote, EV) | 18–24 / 700, tabulaire | JetBrains Mono |
| Légende | 12 / 400 | Inter |
| Badge priorité | 12 / 800 | Inter |

Les chiffres utilisent `font-feature-settings: "tnum"` pour éviter les sauts de largeur.
Le texte supporte `textScaleFactor` 1,3 sans troncature des libellés critiques.

### 2.3 Espacement, rayons, ombres

- Grille 4 dp. Marges écran 16 dp. Gouttière 12 dp.
- Rayons : cartes 16, boutons 12, badges 8 (ou pilule).
- Élévation : 0 (bordures) en sombre, ombre douce 0 2 8 rgba(0,0,0,.06) en clair.
- Hauteur de ligne tactile minimale : 48 dp.

### 2.4 Composants

| Composant | Règles |
|---|---|
| `MatchCard` | 88–104 dp, logo 24 dp, 2 lignes max par nom, badge statut, pastille d'analyse |
| `PriorityBadge` | A/B/C/D/NO BET, couleur + lettre, jamais seul |
| `ValueRow` | Marché · cote · proba · EV · badge ; cote à droite, alignée |
| `ProbBar` | Barre 1X2 segmentée, légende accessible |
| `FreshnessChip` | « il y a 42 s » vert, « 6 min » orange, « 22 min » rouge + « périmée » |
| `EmptyState` | Icône, titre court, phrase explicative, action |
| `Skeleton` | Forme exacte du contenu, pas de spinner plein écran |
| `Banner` | Erreur/offline/stale, non bloquant, refermable |
| `Sheet` | Détail d'opportunité, hauteur 70 %, drag handle |

---

## 3. Arborescence et navigation

```
Splash → (première fois) Onboarding 3 écrans → Connexion / Inscription
   │
   └─ Shell principal (bottom bar 5 destinations)
        ├─ 1. Accueil
        │    ├─ Meilleures opportunités du jour
        │    ├─ Matchs en direct
        │    ├─ Quick actions : Favoris · Historique · Statistiques
        │    └─ État système (serveur, données, fraîcheur)
        ├─ 2. Matchs
        │    ├─ Filtres (Aujourd'hui, Demain, 7 j, Direct, Analysés, Value, Favoris)
        │    ├─ Recherche
        │    └─ Fiche match
        │         ├─ Onglet Résumé
        │         ├─ Onglet Statistiques
        │         ├─ Onglet Marchés
        │         ├─ Onglet IA
        │         └─ Onglet Compositions
        ├─ 3. Value Betting
        │    ├─ Flux A/B/C
        │    ├─ Filtres marché / compétition / EV
        │    └─ Détail opportunité (sheet)
        ├─ 4. Direct
        │    ├─ Matchs live (score, minute)
        │    └─ Opportunités live (badge LIVE, fraîcheur stricte)
        └─ 5. Profil
             ├─ Compte, thème, langue, fuseau
             ├─ Notifications (préférences)
             ├─ Bankroll & simulation
             ├─ Historique · Statistiques · Favoris (aussi depuis Accueil)
             ├─ Avertissements légaux
             └─ Administration (si rôle)
```

**Pourquoi 5 onglets.** Material 3 recommande 3 à 5 destinations. Huit onglets sur 360 dp
donnent des cibles < 44 dp et des libellés tronqués. Les 8 sections demandées restent toutes
accessibles, mais Favoris/Historique/Statistiques sont des ** destinations secondaires** avec
accès direct depuis l'Accueil (raccourcis) et le Profil. Si vous préférez 8 onglets, c'est un
choix explicite à valider (question 1 de `docs/01`).

---

## 4. Écran 1 — Accueil

```
┌──────────────────────────────────────────────┐
│ 9:41   ●●●○○ 4G                    78 % ▮▮  │
├──────────────────────────────────────────────┤
│ Bonjour, Alex                        ⚙   🔔² │
│ ● Serveur OK · données il y a 42 s           │
├──────────────────────────────────────────────┤
│ ┌───────────────────┐ ┌───────────────────┐  │
│ │ 128               │ │ 96                │  │
│ │ matchs programmés │ │ matchs analysés   │  │
│ └───────────────────┘ └───────────────────┘  │
│ ┌───────────────────┐ ┌───────────────────┐  │
│ │ 14                │ │ 3                 │  │
│ │ opportunités      │ │ priorité A        │  │
│ └───────────────────┘ └───────────────────┘  │
│                                              │
│ MEILLEURES OPPORTUNITÉS DU JOUR      Tout →  │
│ ┌──────────────────────────────────────────┐ │
│ │ Over 2,5 buts            ⬤ A   1,95      │ │
│ │ Arsenal – Chelsea        IA 58 %         │ │
│ │ Premier League · 17:30   EV +13,1 %      │ │
│ │ ⏱ cote vérifiée il y a 42 s              │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ BTTS Oui                 ⬤ B   1,85      │ │
│ │ Lens – Lyon              IA 57 %         │ │
│ │ Ligue 1 · 19:00          EV +5,5 %       │ │
│ └──────────────────────────────────────────┘ │
│                                              │
│ EN DIRECT                          2 matchs  │
│ ┌──────────────────────────────────────────┐ │
│ │ 67'  Séville 1 – 1 Real Betis    LIVE    │ │
│ └──────────────────────────────────────────┘ │
│                                              │
├──────────────────────────────────────────────┤
│  ⌂        ⚽        ◈         ▶        ☺     │
│ Accueil  Matchs   Value    Direct   Profil   │
└──────────────────────────────────────────────┘
```

Règles :

- Les 4 compteurs sont **cliquables** (filtre correspondant).
- « Serveur OK » ouvre un panneau d'état : dernière synchro, fournisseurs, fraîcheur.
- La carte d'opportunité affiche **la source de la cote** au tap (sheet), pas sur la carte.
- Si aucune opportunité : bandeau « Aucune opportunité fiable aujourd'hui » + lien vers les matchs.
- **Jamais** de carrousel automatique.

---

## 5. Écran 2 — Matchs

```
┌──────────────────────────────────────────────┐
│ Matchs                              🔍  ⚙    │
├──────────────────────────────────────────────┤
│ [ Tous ][ Auj. ][ Demain ][ 7 j ][ Direct ]  │  ← scroll horizontal
│ [ Analysés ][ Value ][ Favoris ]              │
├──────────────────────────────────────────────┤
│ Aujourd'hui · 3 compétitions                 │
│ ┌──────────────────────────────────────────┐ │
│ │ 🏴 Premier League                    J12 │ │
│ │ 17:30   Arsenal       2,10   │  3,40   │ │
│ │         Chelsea       3,60   │  1,95   │ │
│ │ ● Analysé · Qualité 86 % · 3 value       │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ 🇫🇷 Ligue 1                           J10 │ │
│ │ 19:00   Lens          2,45   │  3,20   │ │
│ │         Lyon          2,90   │  2,80   │ │
│ │ ◐ Analyse en cours…                      │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ 🇧🇫 Fasofoot                         J8  │ │
│ │ 16:00   Étoile Filante  —    │   —     │ │
│ │         ASFA Yennenga   —    │   —     │ │
│ │ ⚠ Cotes indisponibles · analyse limitée  │ │
│ └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

- Le tri par défaut est **date/heure**, pas par « meilleure cote ».
- Les cotes affichées sont **les meilleures cotes vérifiées** ; un tap ouvre la comparaison.
- Un match sans données affiche « — », jamais 0.
- Pull-to-refresh + rafraîchissement auto si l'écran est visible et le match à moins de 2 h.

---

## 6. Écran 3 — Fiche match

```
┌──────────────────────────────────────────────┐
│ ←  Premier League · J12            ☆   ⋯    │
│    Arsenal  –  Chelsea                       │
│    Sam. 31 oct. · 17:30 · Emirates Stadium   │
│    ● Analysé · modèle ens-2.3.0 · 09:12      │
├──────────────────────────────────────────────┤
│ MEILLEURES OPPORTUNITÉS IA                   │
│ ┌──────────────────────────────────────────┐ │
│ │ Over 2,5 buts         1,95  58 %  +13,1 %│ │
│ │                    ⬤A  ⏱ 42 s   Détail →│ │
│ ├──────────────────────────────────────────┤ │
│ │ BTTS Oui              1,85  57 %   +5,5 %│ │
│ │                    ⬤B  ⏱ 1 min  Détail →│ │
│ ├──────────────────────────────────────────┤ │
│ │ Double chance 1X      1,40  75 %   +5,0 %│ │
│ │                    ⬤B  ⏱ 1 min  Détail →│ │
│ └──────────────────────────────────────────┘ │
│ ⚠ Cotes 1xBet — vérifier la disponibilité    │
│   de l'opérateur dans votre pays.            │
├──────────────────────────────────────────────┤
│ [Résumé] Statistiques  Marchés  IA  Compo    │
├──────────────────────────────────────────────┤
│ PROBABILITÉS 1X2                             │
│  Arsenal 45 % ███████████░░░░░░░░░░░░        │
│  Nul     27 % ███████░░░░░░░░░░░░░░░░        │
│  Chelsea 28 % ███████░░░░░░░░░░░░░░░░        │
│  Buts attendus 2,7 · Incertitude moyenne     │
│                                              │
│ SCORES LES PLUS PROBABLES                    │
│  1-1 12 %   2-1 10 %   1-0 9 %   0-1 8 %     │
│  ⚠ Un score probable n'est pas un résultat   │
│    attendu.                                  │
└──────────────────────────────────────────────┘
```

Onglets :

| Onglet | Contenu |
|---|---|
| Résumé | Enjeu, forme (5 derniers), confrontations, blessures, classement |
| Statistiques | Buts, xG, tirs, corners, cartons, BTTS, O/U, clean sheets, domicile/extérieur, période + source |
| Marchés | Tous les marchés disponibles, cotes comparées, meilleure cote accessible |
| IA | Toutes les probabilités, IC, qualité des données, facteurs, version, date |
| Compo | Probable (badge orange) ou officielle (badge vert), heure de publication |

Règle d'or : **la section « Meilleures opportunités IA » est toujours la première**, avant les
statistiques. Si aucune sélection ne passe les seuils :

```
│ AUCUNE OPPORTUNITÉ VALUE BETTING POUR CE MATCH│
│ Les cotes ne présentent pas d'avantage         │
│ suffisant après incertitude.                   │
│ [ Voir pourquoi ]                              │
```

---

## 7. Écran 4 — Détail d'une opportunité (sheet)

```
┌──────────────────────────────────────────────┐
│                    ▬▬▬                       │
│ Over 2,5 buts                     ⬤ A        │
│ Arsenal – Chelsea · Premier League           │
├──────────────────────────────────────────────┤
│  Cote        1,95      1xBet   ⏱ 42 s        │
│  Prob. IA    58 %      IC 54,5 – 61,4 %      │
│  Sans marge  48,7 %                          │
│  Cote juste  1,72                            │
│  EV          +13,1 %   borne basse +5,7 %    │
│  Score       82,4 / 100                      │
├──────────────────────────────────────────────┤
│ POURQUOI ?                                   │
│ ✓ Modèle calibré sur ce marché (ECE 0,028)   │
│ ✓ Écart de 9,3 pts face au marché sans marge │
│ ✓ Cote vérifiée il y a moins de 2 minutes    │
│                                              │
│ RISQUES                                      │
│ ! Compositions non officielles               │
│ ! Cote en baisse depuis l'ouverture          │
├──────────────────────────────────────────────┤
│ COMPARAISON DES BOOKMAKERS                   │
│ 1xBet      1,95  ✓ vérifiée   +13,1 %        │
│ Betano     1,91  ✓ vérifiée   +10,8 %        │
│ Pinnacle   1,88  ⚠ retard     +9,0 %         │
│ Lonabet    —     non saisie                  │
├──────────────────────────────────────────────┤
│ [ Simuler une mise ]   [ Ajouter aux favoris]│
│ Aucun pari réel. Simulation uniquement.      │
└──────────────────────────────────────────────┘
```

- L'EV est affichée avec sa **borne basse** ; si elle est négative, la priorité ne peut pas être A.
- « Simuler » est désactivé si la cote est périmée ou si aucune bankroll n'existe.
- Le détail des calculs est accessible via « Voir le calcul » (pédagogie, langage simple).

---

## 8. Écran 5 — Value Betting

```
┌──────────────────────────────────────────────┐
│ Value Betting                    ⓘ  ⚙        │
│ 14 opportunités actives · 3 en priorité A    │
├──────────────────────────────────────────────┤
│ [ A ][ B ][ C ][ Tous ]   Marché ▾  EV ≥3 %  │
├──────────────────────────────────────────────┤
│ AUJOURD'HUI                                  │
│ ┌──────────────────────────────────────────┐ │
│ │ ⬤A  Over 2,5 buts            1,95       │ │
│ │     Arsenal – Chelsea        58 % +13,1 %│ │
│ │     Premier League · 17:30   ⏱ 42 s     │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ ⬤B  BTTS Oui                 1,85       │ │
│ │     Lens – Lyon              57 %  +5,5 %│ │
│ └──────────────────────────────────────────┘ │
│                                              │
│ DEMAIN                                       │
│ ┌──────────────────────────────────────────┐ │
│ │ ⬤C  Under 9,5 corners        1,80       │ │
│ │     Real – Barça             54 %  +3,2 %│ │
│ │     ⚠ données corners partielles         │ │
│ └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

- Un onglet « A » vide affiche : « Aucune opportunité de priorité A. Le moteur préfère ne rien
  recommander plutôt qu'une sélection fragile. »
- Le tri par défaut est `priorité puis score`, jamais par EV brute.
- Un bandeau global rappelle : « Les cotes affichées sont celles d'opérateurs vérifiés.
  Vérifiez leur disponibilité dans votre pays. »

---

## 9. Écran 6 — Direct

```
┌──────────────────────────────────────────────┐
│ Direct                              ⟳        │
│ ● Temps réel · 2 matchs                      │
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ 67'   Séville  1 – 1  Real Betis   LIVE  │ │
│ │ Poss. 54/46 · Tirs 9/7 · Corners 4/3     │ │
│ │ Proba live : 38 % / 30 % / 32 %          │ │
│ │ ⚠ Marché live : cote vérifiée il y a 12 s│ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ 23'   Nantes  0 – 0  Rennes        LIVE  │ │
│ │ Données live insuffisantes → analyse     │ │
│ │ suspendue.                               │ │
│ └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

- Les recommandations live portent un badge `LIVE` et une fraîcheur stricte (30 s).
- Si les données live sont insuffisantes ou trop anciennes : **aucune recommandation**, message
  explicite. On ne « meuble » pas.
- L'onglet Direct se vide automatiquement s'il n'y a aucun match live.

---

## 10. Écran 7 — Favoris

```
┌──────────────────────────────────────────────┐
│ Favoris                                      │
├──────────────────────────────────────────────┤
│ ÉQUIPES                                      │
│  ★ Arsenal        ★ Real Madrid              │
│ COMPÉTITIONS                                 │
│  ★ Premier League ★ Ligue 1                  │
│ MATCHS À VENIR                               │
│ ┌──────────────────────────────────────────┐ │
│ │ 17:30 Arsenal – Chelsea      ● Analysé   │ │
│ └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

- Ajout/suppression par étoile, optimiste, avec rollback si l'API échoue.
- Les favoris sont synchronisés entre appareils du même compte.

---

## 11. Écran 8 — Historique

```
┌──────────────────────────────────────────────┐
│ Historique                    Filtres ▾      │
│ 128 recommandations · 30 j                   │
├──────────────────────────────────────────────┤
│ 30 OCT  Over 2,5 buts  1,95  +13,1 %  ⬤A     │
│         Arsenal 2–1 Chelsea       ✅ Gagné   │
│ 30 OCT  BTTS Oui       1,85  +5,5 %   ⬤B     │
│         Lens 1–1 Lyon             ✅ Gagné   │
│ 29 OCT  1X2 Away       3,20  +4,1 %   ⬤B     │
│         Séville 1–1 Betis         ❌ Perdu   │
│ 29 OCT  Over 2,5 buts  1,90  +2,9 %   ⬤C     │
│         …                          ⏸ En cours│
├──────────────────────────────────────────────┤
│ ⓘ Résultats passés ≠ garantie future.        │
└──────────────────────────────────────────────┘
```

- Chaque ligne ouvre le détail : probabilité au moment de la reco, cote, résultat, CLV.
- Les recommandations **non réglées** restent visibles avec un statut clair.
- Aucune suppression possible côté utilisateur (intégrité de l'historique).

---

## 12. Écran 9 — Statistiques

```
┌──────────────────────────────────────────────┐
│ Statistiques du moteur         30 jours ▾    │
├──────────────────────────────────────────────┤
│ ┌──────────────┐ ┌──────────────┐            │
│ │ ROI simulé   │ │ Yield        │            │
│ │ +4,2 %       │ │ +3,8 %       │            │
│ │ n = 128      │ │ IC95 ±6,1 pt │            │
│ └──────────────┘ └──────────────┘            │
│ ┌──────────────┐ ┌──────────────┐            │
│ │ Réussite     │ │ CLV moyen    │            │
│ │ 54,7 %       │ │ +1,9 %       │            │
│ └──────────────┘ └──────────────┘            │
│                                              │
│ CALIBRATION 1X2                              │
│  Prédit  ██████████░░░░░░  45 %              │
│  Observé █████████░░░░░░░  43 %              │
│  ECE 0,028 · échantillon 412                 │
│                                              │
│ PAR MARCHÉ                                   │
│  1X2      n=412  Brier 0,19  ROI +3,1 %      │
│  O/U 2,5  n=286  Brier 0,22  ROI +5,4 %      │
│  BTTS     n=198  Brier 0,21  ROI +2,7 %      │
│                                              │
│ ⚠ Échantillon insuffisant pour conclure      │
│   sur la rentabilité (n < 1 000).            │
└──────────────────────────────────────────────┘
```

- Aucune statistique sans `n`, sans période, sans IC.
- Si `n < 100` : « échantillon insuffisant », pas de pourcentage.
- Le graphique de calibration est un composant accessible (description textuelle fournie).

---

## 13. Écran 10 — Profil et paramètres

```
┌──────────────────────────────────────────────┐
│ Profil                                       │
│ Alex · alex@exemple.com                      │
│ Rôle : utilisateur                           │
├──────────────────────────────────────────────┤
│ APPARENCE                                    │
│  Thème            Sombre ▾                   │
│  Langue           Français ▾                 │
│  Fuseau           Africa/Ouagadougou ▾       │
├──────────────────────────────────────────────┤
│ NOTIFICATIONS                                │
│  Priorité A seulement              ●──       │
│  Priorité B                        ○──       │
│  Mouvement de cote                 ●──       │
│  Compositions officielles          ●──       │
│  Début / fin de match favori       ●──       │
│  Alerte de synchronisation         ●──       │
│  Heures calmes        22:00 – 07:00          │
├──────────────────────────────────────────────┤
│ SIMULATION                                   │
│  Bankroll          1 500,00 XOF              │
│  Kelly fractionné  25 %                      │
│  Mise max          1 % par pari              │
│  [ Gérer ma bankroll ]                       │
├──────────────────────────────────────────────┤
│ Favoris · Historique · Statistiques          │
│ Sécurité · Avertissements légaux             │
│ Administration (admin)                       │
│ Déconnexion                                  │
└──────────────────────────────────────────────┘
```

- La bankroll est **vide par défaut** : l'utilisateur doit la définir explicitement.
- Le Kelly est expliqué en une phrase, avec plafond, et peut être désactivé.
- Aucune option « Martingale ».

---

## 14. Écran 11 — Administration

```
┌──────────────────────────────────────────────┐
│ Administration                    admin      │
├──────────────────────────────────────────────┤
│ SYSTÈME          ● API OK  ● DB OK  ● Queue  │
│ Fournisseurs     2/3 actifs · quota 68 %     │
│ Dernière collecte il y a 38 s                │
├──────────────────────────────────────────────┤
│ UTILISATEURS            128 actifs      →    │
│ FOURNISSEURS            The Odds API    →    │
│ MODÈLES                 ens-2.3.0 ●     →    │
│ SEUILS VALUE            12 marchés      →    │
│ COLLECTES               Journal         →    │
│ AUDIT                   Journal         →    │
│ SAUVEGARDES             Dernière 03:00  →    │
└──────────────────────────────────────────────┘
```

- Chaque action sensible demande une confirmation et est journalisée.
- Les clés API ne sont **jamais** affichées : seulement « configurée / non configurée ».
- Accessible uniquement aux rôles `admin` (et `analyst` en lecture sur modèles/collectes).

---

## 15. Onboarding, permissions, états

### Onboarding (3 écrans, une seule fois)

1. « Des probabilités, pas des promesses. » — explication en 2 phrases.
2. « Nous comparons les cotes et signalons seulement les écarts fiables. Parfois : aucune
   opportunité. »
3. « 18+. Les pertes sont possibles. Vous restez responsable de vos décisions. » + case à cocher.

### Permissions Android

| Permission | Moment | Si refus |
|---|---|---|
| Notifications (Android 13+) | Après la première opportunité consultée, pas au lancement | L'app fonctionne, bandeau discret dans le profil |
| Réseau | implicite | — |
| Biométrie (option) |À l'activation dans le profil | Mot de passe conservé |

Aucune permission de localisation, de contacts, de stockage externe.

### États d'écran

| État | Rendu |
|---|---|
| Chargement initial | Squelettes de cartes (pas de spinner plein écran) |
| Rafraîchissement | Indicateur fin en haut, contenu conservé |
| Vide (aucune opportunité) | Message positif, pas d'alarme |
| Hors ligne | Bandeau « Hors ligne — dernières données à 14:32 », contenu en cache |
| Données périmées | Chip orange + désactivation des actions de simulation |
| Erreur serveur | Bandeau + « Réessayer », contenu en cache si disponible |
| Erreur d'autorisation | « Session expirée », retour à la connexion, pas de perte de contexte |
| Maintenance | Écran dédié avec heure de retour estimée |

---

## 16. Contenu et microcopie

| Situation | Texte |
|---|---|
| Avertissement permanent (profil, détail) | « Les probabilités sont des estimations. Aucun gain n'est garanti. Les pertes sont possibles. » |
| Aucune opportunité | « Aucune opportunité fiable pour le moment. Le moteur préfère ne rien recommander. » |
| Cote périmée | « Cote non vérifiée depuis 6 min. Elle ne peut plus déclencher de recommandation. » |
| EV positive | « Espérance positive sur le long terme, pas une garantie sur ce match. » |
| Score exact | « Score le plus probable, pas un résultat attendu. » |
| Données manquantes | « Donnée indisponible pour cette compétition. » (jamais 0, jamais une estimation inventée) |

Interdits rédactionnels : « pari sûr », « gains garantis », « pronostic certain », « meilleur
bookmaker », « capital garanti », compte à rebours artificiel.

---

## 17. Accessibilité et performance

- TalkBack : chaque carte a une description complète (« Arsenal contre Chelsea, 17 h 30,
  analysé, 3 opportunités, meilleure priorité A »).
- Focus visible, ordre de lecture logique, pas d'information portée par la couleur seule.
- Taille de police système respectée jusqu'à 1,3 ; au-delà, mise en page adaptative.
- Listes virtualisées, images WebP/AVIF, cache disque 7 jours pour les logos.
- Objectif : ouverture < 1,5 s, défilement 60 fps sur appareil 4 Go de RAM.
- Mode économie de données : désactive les logos et les animations.

---

## 18. Points à valider sur ces maquettes

1. Navigation à 5 onglets (ou 8 ?).
2. Position de « Meilleures opportunités IA » en tête de fiche match.
3. Affichage systématique de la borne basse de l'EV et de l'incertitude.
4. Mention explicite de l'opérateur et de sa disponibilité pays.
5. Absence de compte à rebours et de ton promotionnel.
6. Bankroll vide par défaut.
