# -*- coding: utf-8 -*-
"""Generate Chapter-3 figures for SINA: real result graphs (from the Colab run's
data.json) and conceptual diagrams (data-flow, YOLOv8 architecture, methodology,
class taxonomy). Vector PDFs into report/figures/.

Run:  python diagrams/gen_results.py
"""
import json
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, FancyArrowPatch

CTRL = ("#FFE6CC", "#D79B00")
SERV = ("#DAE8FC", "#6C8EBF")
MODL = ("#D5E8D4", "#82B366")
ENUM = ("#E1D5E7", "#9673A6")
RED = ("#F8CECC", "#B85450")

FR = {  # English model class -> French label
 "bench": "banc", "bicycle": "vélo", "bus": "bus", "bus stop": "arrêt de bus",
 "car": "voiture", "crutch": "béquille", "curb": "bordure", "dog": "chien",
 "fire hydrant": "bouche d'incendie", "motorcycle": "moto", "person": "personne",
 "pole": "poteau", "spherical roadblock": "borne sphérique", "stairs": "escalier",
 "stop sign": "panneau stop", "street light": "lampadaire",
 "traffic light": "feu de circulation", "train": "train", "tree": "arbre",
 "truck": "camion", "warning column": "balise", "waste container": "poubelle",
 "door": "porte", "crosswalk": "passage piéton"}

DANGER = {"car", "bus", "truck", "motorcycle", "bicycle", "train", "dog"}
OBST = {"person", "pole", "curb", "stairs", "spherical roadblock", "warning column",
        "fire hydrant", "bench", "waste container", "door", "crutch"}
# everything else -> traversée / info

def grp_color(name):
    if name in DANGER:
        return RED[0], RED[1]
    if name in OBST:
        return SERV[0], SERV[1]
    return MODL[0], MODL[1]


D = json.load(open("report/figures/train/data.json", encoding="utf-8"))


# ============================================================ 1) training curve
def train_curve():
    ep = D["epochs"]                      # rows of [P, R, mAP50, mAP5095]
    x = list(range(1, len(ep) + 1))
    P = [r[0] for r in ep]; R = [r[1] for r in ep]
    m50 = [r[2] for r in ep]; m5095 = [r[3] for r in ep]
    fig, ax = plt.subplots(figsize=(9.2, 5.0))
    ax.plot(x, m50, color="#1f6fb4", lw=2.2, label="mAP@0,5")
    ax.plot(x, m5095, color="#82B366", lw=2.0, label="mAP@0,5:0,95")
    ax.plot(x, P, color="#D79B00", lw=1.4, ls="--", label="Précision")
    ax.plot(x, R, color="#9673A6", lw=1.4, ls="--", label="Rappel")
    ax.axhline(0.531, color="#1f6fb4", lw=0.8, ls=":", alpha=0.6)
    ax.annotate("mAP@0,5 finale ≈ 0,53", xy=(len(x), 0.531),
                xytext=(len(x) - 22, 0.575), fontsize=9, color="#1f6fb4",
                arrowprops=dict(arrowstyle="->", color="#1f6fb4", lw=0.8))
    ax.set_xlabel("Époque"); ax.set_ylabel("Score")
    ax.set_xlim(1, len(x)); ax.set_ylim(0, 0.75)
    ax.grid(True, alpha=0.3)
    ax.legend(loc="lower right", fontsize=9, ncol=2, frameon=True)
    ax.set_title("Évolution des métriques de validation au cours de l'entraînement "
                 "(60 époques)", fontsize=11, fontweight="bold")
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    fig.tight_layout()
    fig.savefig("report/figures/fig_train_curve.pdf", bbox_inches="tight")
    plt.close(fig); print("wrote fig_train_curve.pdf")


# ============================================================ 2) per-class mAP
def class_map():
    items = sorted(D["per_class"].items(), key=lambda kv: kv[1][2])  # by mAP50 asc
    names = [FR[k] for k, _ in items]
    vals = [v[2] for _, v in items]
    cols = [grp_color(k)[0] for k, _ in items]
    edg = [grp_color(k)[1] for k, _ in items]
    fig, ax = plt.subplots(figsize=(9.2, 7.4))
    y = range(len(items))
    ax.barh(list(y), vals, color=cols, edgecolor=edg, height=0.72)
    for i, v in enumerate(vals):
        ax.text(v + 0.01, i, f"{v:.2f}", va="center", fontsize=8)
    ax.axvline(0.531, color="#333333", lw=1.0, ls="--")
    ax.text(0.531 + 0.005, 0.4, "moyenne 0,53", rotation=90, fontsize=8,
            color="#333333", va="bottom")
    ax.set_yticks(list(y)); ax.set_yticklabels(names, fontsize=9)
    ax.set_xlim(0, 1.0); ax.set_xlabel("mAP@0,5")
    ax.set_title("Précision par classe du modèle personnalisé (24 classes)",
                 fontsize=11, fontweight="bold")
    from matplotlib.patches import Patch
    leg = [Patch(facecolor=RED[0], edgecolor=RED[1], label="Danger (mobiles)"),
           Patch(facecolor=SERV[0], edgecolor=SERV[1], label="Obstacle (fixes)"),
           Patch(facecolor=MODL[0], edgecolor=MODL[1], label="Traversée / info")]
    ax.legend(handles=leg, loc="lower right", fontsize=8.5, frameon=True)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    fig.tight_layout()
    fig.savefig("report/figures/fig_class_map.pdf", bbox_inches="tight")
    plt.close(fig); print("wrote fig_class_map.pdf")


# ============================================================ 3) class distribution
def class_dist():
    items = sorted(D["instances"].items(), key=lambda kv: kv[1])
    names = [FR[k] for k, _ in items]
    vals = [v for _, v in items]
    cols = [grp_color(k)[0] for k, _ in items]
    edg = [grp_color(k)[1] for k, _ in items]
    fig, ax = plt.subplots(figsize=(9.2, 7.4))
    y = range(len(items))
    ax.barh(list(y), vals, color=cols, edgecolor=edg, height=0.72)
    for i, v in enumerate(vals):
        ax.text(v + 40, i, str(v), va="center", fontsize=8)
    ax.set_yticks(list(y)); ax.set_yticklabels(names, fontsize=9)
    ax.set_xlim(0, max(vals) * 1.12)
    ax.set_xlabel("Nombre d'instances annotées")
    ax.set_title("Distribution des classes dans le jeu de données fusionné "
                 "(24 classes)", fontsize=11, fontweight="bold")
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    fig.tight_layout()
    fig.savefig("report/figures/fig_class_dist.pdf", bbox_inches="tight")
    plt.close(fig); print("wrote fig_class_dist.pdf")


# ============================================================ helpers (diagrams)
def box(ax, x, y, w, h, text, fill, fs=9, bold=True):
    ax.add_patch(FancyBboxPatch((x, y), w, h,
                 boxstyle="round,pad=0.02,rounding_size=0.06",
                 facecolor=fill[0], edgecolor=fill[1], lw=1.3, zorder=2))
    ax.text(x + w / 2, y + h / 2, text, ha="center", va="center",
            fontsize=fs, fontweight="bold" if bold else "normal", zorder=3)


def arrow(ax, p1, p2, color="#555555", lw=1.4):
    ax.add_patch(FancyArrowPatch(p1, p2, arrowstyle="-|>", mutation_scale=12,
                 color=color, lw=lw, shrinkA=1, shrinkB=1, zorder=1))


# ============================================================ 4) data-flow
def dataflow():
    fig, ax = plt.subplots(figsize=(12.6, 5.4))
    ax.set_xlim(0, 22); ax.set_ylim(0, 9); ax.axis("off")
    box(ax, 0.3, 6.5, 2.7, 1.4, "Caméra\n(YUV420)", ENUM, 9)
    # isolate band
    ax.add_patch(Rectangle((3.6, 0.5), 11.0, 8.0, facecolor="#F7F7F7",
                 edgecolor="#BBBBBB", ls="--", lw=1.2, zorder=0))
    ax.text(9.1, 8.1, "Isolate Dart dédié (hors fil d'interface)",
            ha="center", fontsize=9, style="italic", color="#666666")
    steps = ["YUV → RGB", "Letterbox\n320×320", "Float32List\n[1,320,320,3]",
             "YOLOv8n\nTFLite", "Décodage\nboîtes", "NMS\n(IoU 0,45)"]
    xs = [3.8, 5.7, 7.6, 9.6, 11.5, 13.0]
    ws = [1.7, 1.7, 1.8, 1.7, 1.6, 1.5]
    ys = 5.6
    prev = (3.0, 7.2)
    for i, (s, x, w) in enumerate(zip(steps, xs, ws)):
        box(ax, x, ys, w, 1.5, s, SERV, 8)
        arrow(ax, prev, (x, ys + 0.75))
        prev = (x + w, ys + 0.75)
    # controller
    box(ax, 15.2, 5.6, 3.1, 1.5, "AppController\nscène : distance/position", CTRL, 8.5)
    arrow(ax, prev, (15.2, 6.35))
    # outputs
    outs = [("TTS\n(voix)", SERV), ("Haptique\n(vibration)", SERV),
            ("Audio spatial\n(earcon)", SERV), ("GPS / SOS\n(famille)", RED)]
    for i, (t, c) in enumerate(outs):
        bx = 15.0 + (i % 2) * 3.6
        by = 3.2 - (i // 2) * 1.9
        box(ax, bx, by, 3.2, 1.4, t, c, 8.5)
        arrow(ax, (16.75, 5.6), (bx + 1.6, by + 1.4), color="#999999", lw=1.0)
    ax.set_title("Chaîne de traitement temps réel de SINA (de l'image à la restitution)",
                 fontsize=12, fontweight="bold")
    fig.tight_layout()
    fig.savefig("report/figures/fig_dataflow.pdf", bbox_inches="tight")
    plt.close(fig); print("wrote fig_dataflow.pdf")


# ============================================================ 5) YOLOv8 architecture
def yolo_arch():
    fig, ax = plt.subplots(figsize=(12.6, 3.6))
    ax.set_xlim(0, 22); ax.set_ylim(0, 5); ax.axis("off")
    blocks = [("Entrée\n320×320×3", ENUM, 2.6),
              ("Backbone\nCSPDarknet / C2f\n(extraction de\ncaractéristiques)", SERV, 3.4),
              ("Neck\nPAN-FPN\n(fusion multi-\néchelles)", MODL, 3.2),
              ("Tête découplée\nanchor-free\n(localisation +\nclassification)", CTRL, 3.4),
              ("Sortie\n[1, 4+24, 2100]", ENUM, 2.8)]
    x = 0.4
    prev = None
    for t, c, w in blocks:
        box(ax, x, 1.4, w, 2.2, t, c, 8.5)
        if prev is not None:
            arrow(ax, prev, (x, 2.5))
        prev = (x + w, 2.5)
        x += w + 1.0
    ax.set_title("Architecture du détecteur YOLOv8n (nano)", fontsize=12,
                 fontweight="bold")
    fig.tight_layout()
    fig.savefig("report/figures/fig_yolo_arch.pdf", bbox_inches="tight")
    plt.close(fig); print("wrote fig_yolo_arch.pdf")


# ============================================================ 6) methodology
def methodology():
    fig, ax = plt.subplots(figsize=(13.2, 6.2))
    ax.set_xlim(0, 23.5); ax.set_ylim(0, 11); ax.axis("off")
    # 4 sources -> fusion
    srcs = ["OOD (fpn/ood-pbnro)\n~10 000 images, 22 cl.",
            "Crosswalk\n(+ passage piéton)",
            "Stair-Sidewalk\n(+ escaliers)",
            "Obstacles-for-Blind\n(+ porte, personnes)"]
    for i, s in enumerate(srcs):
        box(ax, 0.4, 8.6 - i * 2.0, 4.6, 1.5, s, MODL, 8)
    box(ax, 6.6, 5.2, 3.4, 1.8, "Fusion par\nnom de classe\n(24 classes)", SERV, 9)
    for i in range(4):
        arrow(ax, (5.0, 9.35 - i * 2.0), (6.6, 6.1), color="#999999", lw=1.0)
    chain = [("Annotations\nYOLO (boîtes)", SERV),
             ("Augmentation\n(mosaic, flip, HSV)", SERV),
             ("Entraînement\nYOLOv8n (transfert,\n60 époques, 320 px)", CTRL),
             ("Export TFLite\nfloat16 (~6 Mo)", MODL),
             ("Intégration\napp Flutter", ENUM)]
    x = 11.2
    prev = (10.0, 6.1)
    for t, c in chain:
        box(ax, x, 5.2, 2.0, 1.8, t, c, 7.5)
        arrow(ax, prev, (x, 6.1))
        prev = (x + 2.0, 6.1)
        x += 2.0  # boxes touch; small gap via arrow shrink
        x += 0.2
    ax.set_title("Démarche de constitution des données et d'entraînement du modèle",
                 fontsize=12, fontweight="bold")
    fig.tight_layout()
    fig.savefig("report/figures/fig_methodology.pdf", bbox_inches="tight")
    plt.close(fig); print("wrote fig_methodology.pdf")


# ============================================================ 7) class taxonomy
def taxonomy():
    groups = [("Danger (mobiles)", RED,
               ["voiture", "bus", "camion", "moto", "vélo", "train", "chien"]),
              ("Obstacle (fixes / au sol)", SERV,
               ["personne", "poteau", "bordure", "escalier", "borne sphérique",
                "balise", "bouche d'incendie", "banc", "poubelle", "porte", "béquille"]),
              ("Traversée / information", MODL,
               ["feu de circulation", "passage piéton", "panneau stop",
                "arrêt de bus", "lampadaire", "arbre"])]
    fig, ax = plt.subplots(figsize=(12.0, 5.6))
    ax.set_xlim(0, 12); ax.set_ylim(0, 10); ax.axis("off")
    cw = 3.7
    for gi, (title, col, items) in enumerate(groups):
        x = 0.3 + gi * 3.9
        h = 0.6 + len(items) * 0.62 + 0.7
        ax.add_patch(FancyBboxPatch((x, 8.6 - h), cw, h,
                     boxstyle="round,pad=0.04,rounding_size=0.1",
                     facecolor=col[0], edgecolor=col[1], lw=1.4, zorder=1))
        ax.text(x + cw / 2, 8.35, title, ha="center", va="top", fontsize=10,
                fontweight="bold", zorder=2)
        for j, it in enumerate(items):
            ax.text(x + cw / 2, 7.7 - j * 0.62, "• " + it, ha="center", va="top",
                    fontsize=9, zorder=2)
    ax.set_title("Taxonomie des 24 classes détectées, par niveau de priorité",
                 fontsize=12, fontweight="bold")
    fig.tight_layout()
    fig.savefig("report/figures/fig_taxonomy.pdf", bbox_inches="tight")
    plt.close(fig); print("wrote fig_taxonomy.pdf")


if __name__ == "__main__":
    train_curve(); class_map(); class_dist()
    dataflow(); yolo_arch(); methodology(); taxonomy()
