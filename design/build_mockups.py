#!/usr/bin/env python3
"""Génère les maquettes SVG (Phase 1) de FOOTBALL VALUE AI.

Ce script est un outil de design, pas du code applicatif.
Sortie : design/mockups/*.svg (360x800, viewBox identique).
"""
from pathlib import Path

OUT = Path(__file__).parent / "mockups"
OUT.mkdir(parents=True, exist_ok=True)

W, H = 360, 800
BG = "#0B0F14"
SURF = "#121821"
SURF2 = "#1A2230"
BRD = "#243044"
TXT = "#EAF0F7"
MUT = "#8A94A6"
GREEN = "#00D68F"
BLUE = "#4CD7F6"
WARN = "#FFB020"
RED = "#FF5A5F"
DIM = "#5A6473"
FONT = "Inter, 'Segoe UI', Arial, sans-serif"
MONO = "'JetBrains Mono', Consolas, monospace"


def esc(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def rect(x, y, w, h, fill=SURF, r=16, stroke=None, sw=1, opacity=1.0):
    s = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}"'
    if opacity != 1.0:
        s += f' fill-opacity="{opacity}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-width="{sw}"'
    return s + "/>"


def text(x, y, s, size=12, fill=TXT, weight=400, anchor="start", family=FONT, ls=None, opacity=1.0):
    extra = ""
    if ls:
        extra += f' letter-spacing="{ls}"'
    if opacity != 1.0:
        extra += f' fill-opacity="{opacity}"'
    return (
        f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" '
        f'font-weight="{weight}" fill="{fill}" text-anchor="{anchor}"{extra}>{esc(s)}</text>'
    )


def circle(cx, cy, r, fill, opacity=1.0):
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}" fill-opacity="{opacity}"/>'


def line(x1, y1, x2, y2, color=BRD, sw=1):
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{sw}"/>'


def badge(x, y, letter, color, size=20):
    return (
        rect(x, y, size, size, color, r=7, opacity=0.16)
        + text(x + size / 2, y + size / 2 + 4, letter, size=11, fill=color, weight=800, anchor="middle")
    )


def chip(x, y, w, label, active=False, h=26):
    fill = GREEN if active else SURF2
    fg = "#07130E" if active else MUT
    return rect(x, y, w, h, fill, r=13, stroke=None if active else BRD) + text(
        x + w / 2, y + h / 2 + 4, label, size=10, fill=fg, weight=700, anchor="middle"
    )


def status_bar():
    return (
        text(16, 21, "9:41", size=11, weight=600)
        + text(78, 21, "●●●○○", size=8, fill=MUT)
        + text(120, 21, "4G", size=9, fill=MUT)
        + text(330, 21, "78 %", size=10, fill=MUT, anchor="end")
        + rect(300, 13, 22, 9, "none", r=3, stroke=MUT, sw=1)
        + rect(302, 15, 15, 5, GREEN, r=2)
    )


def bottom_nav(active=0):
    items = [("⌂", "Accueil"), ("⚽", "Matchs"), ("◈", "Value"), ("▶", "Direct"), ("☺", "Profil")]
    out = [rect(0, 728, W, 72, "#0E141C", r=0), line(0, 728, W, 728)]
    slot = W / 5
    for i, (icon, label) in enumerate(items):
        cx = slot * i + slot / 2
        color = GREEN if i == active else MUT
        out.append(text(cx, 758, icon, size=17, fill=color, anchor="middle"))
        out.append(text(cx, 778, label, size=9, fill=color, weight=700 if i == active else 400, anchor="middle"))
        if i == active:
            out.append(rect(cx - 12, 732, 24, 3, GREEN, r=2))
    return "".join(out)


def svg(body: str) -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
        f'viewBox="0 0 {W} {H}" role="img">'
        f'<rect width="{W}" height="{H}" fill="{BG}"/>' + body + "</svg>"
    )


def home():
    b = [status_bar()]
    b.append(rect(16, 34, 22, 22, GREEN, r=7))
    b.append(text(27, 49, "FV", size=9, fill="#07130E", weight=800, anchor="middle"))
    b.append(text(44, 43, "FOOTBALL VALUE AI", size=8, fill=MUT, weight=700, ls="1.4"))
    b.append(text(44, 55, "Analyse · Probabilités · Value", size=8, fill=DIM))

    b.append(text(16, 86, "Bonjour, Alex", size=22, weight=700))
    b.append(text(318, 84, "⚙", size=15, fill=MUT, anchor="middle"))
    b.append(text(342, 84, "🔔", size=14, fill=MUT, anchor="middle"))
    b.append(circle(20, 104, 3, GREEN))
    b.append(text(28, 108, "Serveur opérationnel · données il y a 42 s", size=10, fill=MUT))

    kpis = [("128", "matchs programmés"), ("96", "matchs analysés"),
            ("14", "opportunités"), ("3", "priorité A")]
    for i, (val, lab) in enumerate(kpis):
        col = i % 2
        row = i // 2
        x = 16 + col * 170
        y = 124 + row * 60
        b.append(rect(x, y, 158, 52))
        b.append(text(x + 12, y + 23, val, size=21, fill=GREEN if i == 3 else TXT, weight=700, family=MONO))
        b.append(text(x + 12, y + 40, lab, size=9, fill=MUT))

    b.append(text(16, 268, "MEILLEURES OPPORTUNITÉS DU JOUR", size=9, fill=MUT, weight=800, ls="1.1"))
    b.append(text(344, 268, "Tout →", size=9, fill=GREEN, weight=700, anchor="end"))

    cards = [
        ("A", GREEN, "Over 2,5 buts", "Arsenal – Chelsea", "Premier League · 17:30", "1,95", "58 %", "+13,1 %"),
        ("B", BLUE, "BTTS Oui", "Lens – Lyon", "Ligue 1 · 19:00", "1,85", "57 %", "+5,5 %"),
        ("B", BLUE, "Double chance 1X", "Real – Barça", "La Liga · 21:00", "1,40", "75 %", "+5,0 %"),
    ]
    y = 280
    for letter, color, market, teams, comp, odds, prob, ev in cards:
        b.append(rect(16, y, 328, 84))
        b.append(badge(28, y + 14, letter, color))
        b.append(text(56, y + 28, market, size=13, weight=700))
        b.append(text(56, y + 44, teams, size=10, fill=MUT))
        b.append(text(56, y + 58, comp, size=9, fill=DIM))
        b.append(text(332, y + 26, odds, size=18, fill=TXT, weight=700, family=MONO, anchor="end"))
        b.append(text(332, y + 43, "IA " + prob, size=9, fill=MUT, anchor="end"))
        b.append(text(332, y + 60, "EV " + ev, size=11, fill=GREEN, weight=700, family=MONO, anchor="end"))
        b.append(text(56, y + 73, "⏱ cote vérifiée il y a 42 s", size=8, fill=DIM))
        y += 92

    b.append(text(16, 580, "EN DIRECT", size=9, fill=MUT, weight=800, ls="1.1"))
    b.append(text(344, 580, "2 matchs", size=9, fill=MUT, anchor="end"))
    b.append(rect(16, 590, 328, 56))
    b.append(text(28, 614, "67'", size=11, fill=RED, weight=800, family=MONO))
    b.append(text(58, 614, "Séville  1 – 1  Real Betis", size=12, weight=600))
    b.append(rect(286, 600, 44, 18, RED, r=9, opacity=0.16))
    b.append(text(308, 613, "LIVE", size=8, fill=RED, weight=800, anchor="middle"))
    b.append(text(58, 632, "Poss. 54/46 · Tirs 9/7 · Corners 4/3", size=9, fill=MUT))
    b.append(bottom_nav(0))
    return svg("".join(b))


def matches():
    b = [status_bar()]
    b.append(text(16, 60, "Matchs", size=22, weight=700))
    b.append(circle(310, 53, 16, SURF2))
    b.append(text(310, 58, "🔍", size=12, fill=MUT, anchor="middle"))
    b.append(circle(342, 53, 16, SURF2))
    b.append(text(342, 58, "⚙", size=12, fill=MUT, anchor="middle"))

    chips1 = [("Tous", 52, True), ("Auj.", 48, False), ("Demain", 60, False), ("7 j", 40, False), ("Direct", 58, False)]
    x = 16
    for lab, w, act in chips1:
        b.append(chip(x, 80, w, lab, act))
        x += w + 8
    chips2 = [("Analysés", 70, False), ("Value", 52, False), ("Favoris", 64, False)]
    x = 16
    for lab, w, act in chips2:
        b.append(chip(x, 114, w, lab, act))
        x += w + 8

    b.append(text(16, 166, "AUJOURD'HUI · 3 COMPÉTITIONS", size=9, fill=MUT, weight=800, ls="1.0"))

    games = [
        ("Premier League", "J12", "17:30", "Arsenal", "Chelsea", "2,10", "3,40", "3,60",
         "● Analysé · Qualité 86 % · 3 value", GREEN, SURF),
        ("Ligue 1", "J10", "19:00", "Lens", "Lyon", "2,45", "3,20", "2,90",
         "◐ Analyse en cours…", WARN, SURF),
        ("Fasofoot", "J8", "16:00", "Étoile Filante", "ASFA Yennenga", "—", "—", "—",
         "⚠ Cotes indisponibles · analyse limitée", DIM, SURF2),
    ]
    y = 178
    for comp, j, t, home, away, o1, ox, o2, status, scol, fill in games:
        b.append(rect(16, y, 328, 116, fill))
        b.append(text(28, y + 20, comp, size=10, fill=MUT, weight=700))
        b.append(text(332, y + 20, j, size=9, fill=DIM, anchor="end"))
        b.append(line(28, y + 30, 332, y + 30))
        b.append(text(28, y + 50, t, size=10, fill=GREEN, weight=700, family=MONO))
        b.append(text(74, y + 50, home, size=12, weight=600))
        b.append(text(74, y + 70, away, size=12, weight=600))
        b.append(text(228, y + 38, "1", size=8, fill=DIM, anchor="middle"))
        b.append(text(272, y + 38, "X", size=8, fill=DIM, anchor="middle"))
        b.append(text(316, y + 38, "2", size=8, fill=DIM, anchor="middle"))
        b.append(text(228, y + 60, o1, size=11, fill=TXT, weight=700, family=MONO, anchor="middle"))
        b.append(text(272, y + 60, ox, size=11, fill=TXT, weight=700, family=MONO, anchor="middle"))
        b.append(text(316, y + 60, o2, size=11, fill=TXT, weight=700, family=MONO, anchor="middle"))
        b.append(text(28, y + 96, status, size=9, fill=scol))
        y += 124

    b.append(rect(16, 552, 328, 40, SURF2, r=12))
    b.append(text(28, 577, "ℹ  Les cotes affichées sont vérifiées et datées.", size=9, fill=MUT))
    b.append(bottom_nav(1))
    return svg("".join(b))


def match_detail():
    b = [status_bar()]
    b.append(text(22, 56, "←", size=18, fill=TXT))
    b.append(text(44, 52, "Premier League · J12", size=10, fill=MUT))
    b.append(text(316, 52, "☆", size=16, fill=MUT))
    b.append(text(342, 52, "⋯", size=16, fill=MUT))
    b.append(text(44, 78, "Arsenal  –  Chelsea", size=19, weight=700))
    b.append(text(44, 94, "Sam. 31 oct. · 17:30 · Emirates Stadium", size=9, fill=MUT))
    b.append(text(44, 108, "● Analysé · ens-2.3.0 · 09:12", size=9, fill=GREEN))

    b.append(text(16, 136, "MEILLEURES OPPORTUNITÉS IA", size=9, fill=MUT, weight=800, ls="1.0"))
    rows = [
        ("A", GREEN, "Over 2,5 buts", "1,95", "58 %", "+13,1 %", "42 s"),
        ("B", BLUE, "BTTS Oui", "1,85", "57 %", "+5,5 %", "1 min"),
        ("B", BLUE, "Double chance 1X", "1,40", "75 %", "+5,0 %", "1 min"),
    ]
    y = 146
    for letter, color, label, odds, prob, ev, age in rows:
        b.append(rect(16, y, 328, 56))
        b.append(badge(26, y + 18, letter, color, 20))
        b.append(text(54, y + 24, label, size=12, weight=700))
        b.append(text(54, y + 40, prob + " · cote vérifiée il y a " + age, size=9, fill=MUT))
        b.append(text(332, y + 23, odds, size=15, fill=TXT, weight=700, family=MONO, anchor="end"))
        b.append(text(332, y + 40, ev, size=10, fill=GREEN, weight=700, family=MONO, anchor="end"))
        y += 62

    b.append(rect(16, 336, 328, 34, SURF2, r=10))
    b.append(text(26, 357, "⚠  Cotes 1xBet — vérifier la disponibilité de l'opérateur.", size=8, fill=WARN))

    tabs = ["Résumé", "Statistiques", "Marchés", "IA", "Compo"]
    x = 16
    for i, tab in enumerate(tabs):
        w = 56 if i else 62
        if i == 0:
            b.append(text(x + 6, 396, tab, size=10, fill=GREEN, weight=700))
            b.append(rect(x, 402, 52, 2, GREEN, r=1))
        else:
            b.append(text(x + 6, 396, tab, size=10, fill=MUT))
        x += w

    b.append(text(16, 430, "PROBABILITÉS 1X2", size=9, fill=MUT, weight=800, ls="1.0"))
    probs = [("Arsenal", 0.45, GREEN), ("Nul", 0.27, DIM), ("Chelsea", 0.28, BLUE)]
    y = 444
    for name, p, color in probs:
        b.append(text(16, y + 10, name, size=10, fill=MUT))
        b.append(rect(74, y, 240, 8, SURF2, r=4))
        b.append(rect(74, y, int(240 * p * 2), 8, color, r=4, opacity=0.85))
        b.append(text(332, y + 10, f"{int(p*100)} %", size=10, family=MONO, anchor="end"))
        y += 24
    b.append(text(16, y + 12, "Buts attendus 2,7 · Incertitude moyenne", size=9, fill=MUT))
    b.append(text(16, y + 26, "Qualité des données 86 % · modèle ens-2.3.0", size=9, fill=DIM))

    b.append(text(16, 548, "SCORES LES PLUS PROBABLES", size=9, fill=MUT, weight=800, ls="1.0"))
    scores = [("1-1", "12 %"), ("2-1", "10 %"), ("1-0", "9 %"), ("0-1", "8 %")]
    x = 16
    for sc, p in scores:
        b.append(rect(x, 558, 74, 44, SURF2, r=10))
        b.append(text(x + 37, 576, sc, size=13, weight=700, family=MONO, anchor="middle"))
        b.append(text(x + 37, 592, p, size=9, fill=MUT, anchor="middle"))
        x += 82
    b.append(text(16, 620, "⚠ Un score probable n'est pas un résultat attendu.", size=8, fill=WARN))

    b.append(rect(16, 636, 328, 56, SURF, r=12, stroke=BRD))
    b.append(text(28, 658, "Aucune garantie de gain", size=10, weight=700))
    b.append(text(28, 674, "Une EV positive ne garantit pas un gain sur ce match.", size=8, fill=MUT))

    b.append(bottom_nav(1))
    return svg("".join(b))


def value_screen():
    b = [status_bar()]
    b.append(text(16, 60, "Value Betting", size=22, weight=700))
    b.append(circle(310, 53, 16, SURF2))
    b.append(text(310, 58, "ⓘ", size=12, fill=MUT, anchor="middle"))
    b.append(circle(342, 53, 16, SURF2))
    b.append(text(342, 58, "⚙", size=12, fill=MUT, anchor="middle"))
    b.append(text(16, 82, "14 opportunités actives · 3 en priorité A", size=10, fill=MUT))

    chips = [("A", 34, True), ("B", 34, False), ("C", 34, False), ("Tous", 52, False)]
    x = 16
    for lab, w, act in chips:
        b.append(chip(x, 94, w, lab, act))
        x += w + 8
    b.append(text(200, 112, "Marché ▾", size=9, fill=MUT))
    b.append(text(268, 112, "EV ≥ 3 % ▾", size=9, fill=MUT))

    b.append(text(16, 152, "AUJOURD'HUI", size=9, fill=MUT, weight=800, ls="1.0"))
    rows = [
        ("A", GREEN, "Over 2,5 buts", "Arsenal – Chelsea", "Premier League · 17:30", "1,95", "58 %", "+13,1 %", "42 s", None),
        ("B", BLUE, "BTTS Oui", "Lens – Lyon", "Ligue 1 · 19:00", "1,85", "57 %", "+5,5 %", "1 min", None),
        ("C", WARN, "Under 9,5 corners", "Real – Barça", "La Liga · 21:00", "1,80", "54 %", "+3,2 %", "2 min", "⚠ corners partiels"),
    ]
    y = 164
    for letter, color, label, teams, comp, odds, prob, ev, age, note in rows:
        h = 96 if note else 86
        b.append(rect(16, y, 328, h))
        b.append(badge(28, y + 14, letter, color))
        b.append(text(56, y + 27, label, size=13, weight=700))
        b.append(text(56, y + 43, teams, size=10, fill=MUT))
        b.append(text(56, y + 57, comp, size=9, fill=DIM))
        b.append(text(332, y + 25, odds, size=18, weight=700, family=MONO, anchor="end"))
        b.append(text(332, y + 41, "IA " + prob, size=9, fill=MUT, anchor="end"))
        b.append(text(332, y + 57, "EV " + ev, size=11, fill=GREEN, weight=700, family=MONO, anchor="end"))
        b.append(text(56, y + 72, "⏱ vérifiée il y a " + age, size=8, fill=DIM))
        if note:
            b.append(text(56, y + 86, note, size=8, fill=WARN))
        y += h + 10

    b.append(rect(16, y + 6, 328, 52, SURF2, r=12))
    b.append(text(28, y + 26, "Aucune opportunité priorité A ?", size=10, weight=700))
    b.append(text(28, y + 41, "Le moteur préfère ne rien recommander.", size=8, fill=MUT))

    b.append(rect(16, y + 70, 328, 40, SURF, r=12, stroke=BRD))
    b.append(text(28, y + 95, "18+ · Les pertes sont possibles. Aucun gain garanti.", size=8, fill=MUT))
    b.append(bottom_nav(2))
    return svg("".join(b))


if __name__ == "__main__":
    screens = {
        "01-accueil.svg": home(),
        "02-matchs.svg": matches(),
        "03-fiche-match.svg": match_detail(),
        "04-value.svg": value_screen(),
    }
    for name, content in screens.items():
        (OUT / name).write_text(content, encoding="utf-8")
        print("écrit :", OUT / name)
