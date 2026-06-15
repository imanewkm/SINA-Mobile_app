# -*- coding: utf-8 -*-
"""Generate a draw.io (mxGraph) Gantt chart of the SINA project's
best-practice development phases.

Run:  python diagrams/gen_gantt.py
Out:  diagrams/diagramme_de_gantt.drawio
"""
from xml.sax.saxutils import escape

WEEKS = 16
COL_W = 56          # width of one week column
LABEL_W = 300       # width of the task-name column
ROW_H = 26
HEAD_H = 30
X0 = 40
Y0 = 40

cells = []
_id = [10]


def nid():
    _id[0] += 1
    return "g%d" % _id[0]


def box(value, style, x, y, w, h):
    cells.append(
        '<mxCell id="%s" value="%s" style="%s" vertex="1" parent="1">'
        '<mxGeometry x="%g" y="%g" width="%g" height="%g" as="geometry"/></mxCell>'
        % (nid(), escape(value), style, x, y, w, h))


GRID_X = X0 + LABEL_W

# ----- phases: (title, colour) and their tasks (name, start_week, end_week) ---
PHASES = [
    ("Phase 0 - Cadrage & veille", "#F5F5F5", "#666666", [
        ("Etude des besoins & cahier des charges", 1, 2),
        ("Etat de l'art / veille technologique", 1, 3),
        ("Conception UML (cas d'usage, sequence, classes)", 2, 4),
    ]),
    ("Phase 1 - Temps reel & correction", "#DAE8FC", "#6C8EBF", [
        ("Migration web (Flask) -> mobile natif", 3, 6),
        ("Correction labels COCO + classes cibles", 4, 5),
        ("Inference deportee sur isolate", 5, 7),
        ("Pretraitement Float32 + letterbox", 5, 7),
        ("Delegues XNNPACK / GPU / NNAPI", 6, 8),
    ]),
    ("Phase 2 - Accessibilite d'abord", "#D5E8D4", "#82B366", [
        ("Retours haptiques + earcons d'urgence", 7, 9),
        ("Audio spatial (direction / distance)", 8, 9),
        ("Coexistence TalkBack + audit Semantics", 8, 10),
        ("Mode malvoyant (contraste, cibles >=64dp)", 9, 10),
    ]),
    ("Phase 3 - Parite fonctionnelle", "#FFE6CC", "#D79B00", [
        ("Service de premier plan + throttle batterie", 9, 11),
        ("Modes Navigation / Explore / Lecture (OCR)", 10, 12),
        ("Distance par profondeur (ARCore) - couture", 11, 12),
        ("Feux de circulation / passages pietons", 11, 13),
    ]),
    ("Phase 4 - Durcissement & validation", "#E1D5E7", "#9673A6", [
        ("Modele personnalise 24 classes (Colab)", 12, 14),
        ("SOS autonome (SMS + appel multi-contacts)", 13, 14),
        ("Tests (flutter analyze + tests unitaires)", 13, 15),
        ("Deploiement APK & test sur appareil reel", 14, 15),
        ("Redaction du rapport (LaTeX)", 12, 16),
    ]),
]

# ---------- header row (weeks) ------------------------------------------------
HEAD_STYLE = ("rounded=0;whiteSpace=wrap;html=1;fillColor=#23445D;"
              "strokeColor=#23445D;fontColor=#FFFFFF;fontStyle=1;")
box("Tache  \\  Semaine", HEAD_STYLE, X0, Y0, LABEL_W, HEAD_H)
for w in range(WEEKS):
    box("S%d" % (w + 1), HEAD_STYLE, GRID_X + w * COL_W, Y0, COL_W, HEAD_H)

# ---------- rows --------------------------------------------------------------
y = Y0 + HEAD_H
LABEL_STYLE = ("text;html=1;align=left;verticalAlign=middle;spacingLeft=8;"
               "fillColor=#FFFFFF;strokeColor=#BBBBBB;fontSize=11;")
PHASE_STYLE = ("text;html=1;align=left;verticalAlign=middle;spacingLeft=6;"
               "fontStyle=1;fontSize=12;fillColor={bg};strokeColor={st};")
CELLGRID = "rounded=0;fillColor=none;strokeColor=#E6E6E6;html=1;"

for ptitle, bg, st, tasks in PHASES:
    # phase banner spanning the whole width
    span = LABEL_W + WEEKS * COL_W
    box(ptitle, PHASE_STYLE.format(bg=bg, st=st), X0, y, span, ROW_H)
    y += ROW_H
    for name, s, e in tasks:
        box(name, LABEL_STYLE, X0, y, LABEL_W, ROW_H)
        # faint grid cells for the weeks
        for w in range(WEEKS):
            box("", CELLGRID, GRID_X + w * COL_W, y, COL_W, ROW_H)
        # the task bar
        bx = GRID_X + (s - 1) * COL_W + 3
        bw = (e - s + 1) * COL_W - 6
        bar_style = ("rounded=1;whiteSpace=wrap;html=1;fillColor=%s;"
                     "strokeColor=%s;fontColor=#222222;fontSize=10;"
                     "arcSize=40;" % (bg, st))
        box("S%d-S%d" % (s, e), bar_style, bx, y + 4, bw, ROW_H - 8)
        y += ROW_H

# ---------- continuous best-practices band ------------------------------------
y += 6
span = LABEL_W + WEEKS * COL_W
note = ("Bonnes pratiques continues : controle de version Git (commits atomiques), "
        "analyse statique (flutter analyze) et tests a chaque lot, "
        "developpement iteratif & incremental, offline-first / zero cout.")
box(note, ("text;html=1;align=left;verticalAlign=middle;spacingLeft=8;"
           "fillColor=#FFF2CC;strokeColor=#D6B656;fontSize=10;fontStyle=2;"),
    X0, y, span, ROW_H + 14)

# ---------- title -------------------------------------------------------------
box("SINA - Diagramme de Gantt (phases de developpement & bonnes pratiques)",
    "text;html=1;align=left;verticalAlign=middle;fontSize=14;fontStyle=1;"
    "fillColor=none;strokeColor=none;", X0, 6, span, 28)

# ---------- document ----------------------------------------------------------
body = "\n        ".join(cells)
total_w = X0 + LABEL_W + WEEKS * COL_W + 60
total_h = y + 80
doc = (
    '<mxfile host="app.diagrams.net" version="24.0.0">\n'
    '  <diagram id="sina-gantt" name="Diagramme de Gantt">\n'
    '    <mxGraphModel dx="1400" dy="900" grid="0" gridSize="10" guides="1" '
    'tooltips="1" connect="0" arrows="0" fold="1" page="1" pageScale="1" '
    'pageWidth="%d" pageHeight="%d" math="0" shadow="0">\n'
    '      <root>\n'
    '        <mxCell id="0"/>\n'
    '        <mxCell id="1" parent="0"/>\n'
    '        %s\n'
    '      </root>\n'
    '    </mxGraphModel>\n'
    '  </diagram>\n'
    '</mxfile>\n' % (total_w, total_h, body)
)

with open("diagrams/diagramme_de_gantt.drawio", "w", encoding="utf-8") as f:
    f.write(doc)
print("wrote diagrams/diagramme_de_gantt.drawio  (%d cells)" % len(cells))
