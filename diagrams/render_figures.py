# -*- coding: utf-8 -*-
"""Render the SINA class diagram and Gantt chart as vector PDFs for the LaTeX
report (same content as the .drawio files, laid out for print).

Run:  python diagrams/render_figures.py
Out:  report/figures/uml_classes.pdf
      report/figures/gantt.pdf
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, FancyArrowPatch
from matplotlib.path import Path
import matplotlib.patches as mpatches

# ---- palette (matches the .drawio fills) ------------------------------------
CTRL = ("#FFE6CC", "#D79B00")
SERV = ("#DAE8FC", "#6C8EBF")
MODL = ("#D5E8D4", "#82B366")
ENUM = ("#E1D5E7", "#9673A6")


def class_box(ax, x, y, w, h, title, members, fill, stereotype=None,
              title_fs=8.5, mem_fs=7.0):
    """Draw a UML class box anchored at top-left (x, y); y grows downward."""
    face, edge = fill
    # body
    ax.add_patch(Rectangle((x, y - h), w, h, facecolor="white",
                           edgecolor=edge, linewidth=1.0, zorder=2))
    # title band
    th = 0.42 if stereotype else 0.30
    ax.add_patch(Rectangle((x, y - th), w, th, facecolor=face,
                           edgecolor=edge, linewidth=1.0, zorder=3))
    if stereotype:
        ax.text(x + w / 2, y - 0.13, "<<%s>>" % stereotype, ha="center",
                va="center", fontsize=mem_fs - 0.5, style="italic", zorder=4)
        ax.text(x + w / 2, y - 0.30, title, ha="center", va="center",
                fontsize=title_fs, fontweight="bold", zorder=4)
    else:
        ax.text(x + w / 2, y - th / 2, title, ha="center", va="center",
                fontsize=title_fs, fontweight="bold", zorder=4)
    # members
    ty = y - th - 0.20
    for m in members:
        ax.text(x + 0.10, ty, m, ha="left", va="center", fontsize=mem_fs,
                family="monospace", zorder=4)
        ty -= 0.225
    return (x, y, w, h)


def edge(ax, p1, p2, color, dashed=False, comp=False, lw=1.0):
    style = "-" if not dashed else (0, (4, 3))
    arr = "-"
    fap = FancyArrowPatch(p1, p2, arrowstyle="-|>", mutation_scale=9,
                          color=color, lw=lw, linestyle=style,
                          shrinkA=0, shrinkB=0, zorder=1)
    ax.add_patch(fap)
    if comp:  # composition diamond at the controller end (p1)
        ax.plot(p1[0], p1[1], marker="D", color=color, markersize=5,
                markerfacecolor=color, zorder=5)


# =============================================================================
#  1) CLASS DIAGRAM  (layered: models on top, controller in middle, services)
# =============================================================================
def render_uml():
    # standard orientation: larger y = higher on screen
    fig, ax = plt.subplots(figsize=(12.6, 9.4))
    ax.set_xlim(0, 16)
    ax.set_ylim(0, 14)
    ax.axis("off")

    # ---- models row (top) ----------------------------------------------------
    models = [
        ("AppState", ["idle", "listening", "responding"], ENUM, "enumeration"),
        ("Detection", ["+ label   + distance", "+ position  + confidence",
                        "+ box   + spoken{}"], MODL, None),
        ("RawBox", ["+ classId  + label", "+ x1,y1,x2,y2", "+ lightState?",
                    "+ distanceMeters?"], MODL, None),
        ("SinaAlert", ["+ id   + message", "+ lat?  + lng?", "+ timestamp"],
         MODL, None),
        ("EmergencyContact", ["+ name", "+ phone"], MODL, None),
    ]
    mw, mh, gap = 2.78, 1.75, 0.40
    total = len(models) * mw + (len(models) - 1) * gap
    mx0 = (16 - total) / 2
    ymodels = 13.4
    model_anchor = {}
    for i, (name, mem, fill, st) in enumerate(models):
        mx = mx0 + i * (mw + gap)
        class_box(ax, mx, ymodels, mw, mh, name, mem, fill, stereotype=st)
        model_anchor[name] = (mx + mw / 2, ymodels - mh)  # bottom-center

    # ---- controller (middle, wide) ------------------------------------------
    cw, ch = 13.6, 1.95
    cx = (16 - cw) / 2
    ctop = 9.4                       # top edge of controller
    cbot = ctop - ch                 # bottom edge
    ax.add_patch(Rectangle((cx, cbot), cw, ch, facecolor="white",
                           edgecolor=CTRL[1], linewidth=1.4, zorder=2))
    ax.add_patch(Rectangle((cx, ctop - 0.42), cw, 0.42, facecolor=CTRL[0],
                           edgecolor=CTRL[1], linewidth=1.4, zorder=3))
    ax.text(cx + cw / 2, ctop - 0.21,
            "AppController   <<singleton, ChangeNotifier>>",
            ha="center", va="center", fontsize=10.5, fontweight="bold", zorder=4)
    left = ["+ state: AppState", "+ curLang: String", "+ cameraOn: bool",
            "+ boxesNotifier: ValueNotifier<List<RawBox>>"]
    right = ["+ boot()   + activate()", "+ startCamera() / stopCamera()",
             "+ describeScene()   + readText()",
             "+ triggerSOS() / confirmSosNow()"]
    ty = ctop - 0.66
    for l in left:
        ax.text(cx + 0.25, ty, l, ha="left", va="center", fontsize=7.6,
                family="monospace", zorder=4)
        ty -= 0.31
    ty = ctop - 0.66
    for r in right:
        ax.text(cx + cw / 2 + 0.25, ty, r, ha="left", va="center", fontsize=7.6,
                family="monospace", zorder=4)
        ty -= 0.31

    # ---- services (bottom, 3 rows) ------------------------------------------
    services = [
        ("DetectorService", ["+ detect(): List<RawBox>", "+ init() / dispose()"]),
        ("SttService", ["+ listen(lang)", "+ stop() / cancel()"]),
        ("TtsService", ["+ speak(text)", "+ configure()"]),
        ("GpsService", ["+ currentPosition()", "+ start() / stop()"]),
        ("AlertService", ["+ addAlert(): SinaAlert", "+ showSosNotification()"]),
        ("SettingsService", ["+ getRaw() / setRaw()", "+ init()"]),
        ("OcrService", ["+ readFromFile(): String"]),
        ("SpatialAudioService", ["+ cue(pos, dist)"]),
        ("DepthService", ["+ depthAt(): List<double>"]),
        ("SmsService", ["+ send(phone, msg)"]),
        ("CallService", ["+ call(phone)"]),
    ]
    cols = 4
    sw, sh, sgx, sgy = 3.45, 1.30, 0.30, 0.55
    grid_w = cols * sw + (cols - 1) * sgx
    sx0 = (16 - grid_w) / 2
    row0_top = 6.1
    pitch = sh + sgy

    def svc_top(i):
        r, c = divmod(i, cols)
        sx = sx0 + c * (sw + sgx)
        sytop = row0_top - r * pitch
        return sx, sytop

    for i, (name, mem) in enumerate(services):
        sx, sytop = svc_top(i)
        class_box(ax, sx, sytop, sw, sh, name, mem, SERV)
        # composition spoke from controller bottom edge down to service top
        top = (sx + sw / 2, sytop)
        anchor_x = min(max(top[0], cx + 0.3), cx + cw - 0.3)
        edge(ax, (anchor_x, cbot), top, CTRL[1], comp=True, lw=0.9)

    # ---- controller -> models (associations, upward) ------------------------
    for name, kind in [("AppState", "state"), ("Detection", "uses"),
                       ("EmergencyContact", "uses")]:
        mb = model_anchor[name]
        ax.add_patch(FancyArrowPatch(
            (min(max(mb[0], cx + 0.3), cx + cw - 0.3), ctop), (mb[0], mb[1]),
            arrowstyle="-|>", mutation_scale=9, color=ENUM[1], lw=0.9,
            linestyle=(0, (4, 3)) if kind == "uses" else "-",
            shrinkA=0, shrinkB=0, zorder=1))

    # ---- service -> model dependencies (creates) ----------------------------
    for si, mname in [(0, "RawBox"), (4, "SinaAlert")]:
        sx, sytop = svc_top(si)
        st = (sx + sw / 2, sytop)
        mb = model_anchor[mname]
        ax.add_patch(FancyArrowPatch(
            st, mb, arrowstyle="-|>", mutation_scale=8, color=MODL[1], lw=0.8,
            linestyle=(0, (2, 2)), connectionstyle="arc3,rad=-0.16",
            shrinkA=2, shrinkB=2, zorder=1, alpha=0.7))

    # ---- legend (empty band between models and controller) ------------------
    leg = [mpatches.Patch(facecolor=CTRL[0], edgecolor=CTRL[1], label="Contrôleur"),
           mpatches.Patch(facecolor=SERV[0], edgecolor=SERV[1], label="Services"),
           mpatches.Patch(facecolor=MODL[0], edgecolor=MODL[1], label="Modèles"),
           mpatches.Patch(facecolor=ENUM[0], edgecolor=ENUM[1], label="Énumération")]
    ax.legend(handles=leg, loc="center", ncol=4, fontsize=8.5, frameon=False,
              bbox_to_anchor=(0.5, 0.785))
    ax.annotate("◆ composition   ⇢ dépendance / association",
                xy=(0.5, 0.745), xycoords="axes fraction", ha="center",
                fontsize=7.5, color="#555555")

    fig.tight_layout()
    fig.savefig("report/figures/uml_classes.pdf", bbox_inches="tight")
    plt.close(fig)
    print("wrote report/figures/uml_classes.pdf")


# =============================================================================
#  2) GANTT CHART
# =============================================================================
def render_gantt():
    WEEKS = 4
    PHASES = [
        ("Phase 1 : Analyse & conception", ("#F5F5F5", "#666666"), [
            ("Cadrage, besoins & cahier des charges", 1, 1),
            ("État de l'art / veille technologique", 1, 1),
            ("Conception UML (cas d'usage, séquence, classes)", 1, 1),
        ]),
        ("Phase 2 : Développement & intégration", SERV, [
            ("Audit prototype web + migration → Flutter", 1, 2),
            ("Pipeline détection (YOLO/TFLite + isolate)", 2, 2),
            ("Prétraitement, letterbox, délégués XNNPACK", 2, 3),
            ("Interfaces vocales (TTS/STT, 3 langues)", 2, 3),
            ("Accessibilité (haptique, audio spatial, mode malvoyant)", 3, 3),
            ("Fonctions avancées (OCR, SOS, GPS)", 3, 3),
        ]),
        ("Phase 3 : Modèle, tests & déploiement", MODL, [
            ("Modèle personnalisé 24 classes (export/intégration)", 3, 4),
            ("Tests (flutter analyze + tests unitaires)", 4, 4),
            ("Déploiement APK & test sur appareil réel", 4, 4),
        ]),
        ("Tâche transverse", ENUM, [
            ("Rédaction du rapport (continu)", 1, 4),
        ]),
    ]
    n_rows = sum(1 + len(t) for _, _, t in PHASES)
    fig_h = max(5.0, 0.40 * n_rows + 1.6)
    fig, ax = plt.subplots(figsize=(11.0, fig_h))

    row = 0
    yticks, ylabels = [], []
    # iterate top-down
    def yof(r):
        return n_rows - r  # invert so row 0 is at top

    for ptitle, (face, edge_c), tasks in PHASES:
        # phase band across all weeks
        ax.add_patch(Rectangle((0.5, yof(row) - 0.5), WEEKS, 1.0,
                               facecolor=edge_c, edgecolor="none", alpha=0.85,
                               zorder=1))
        ax.text(0.6, yof(row), ptitle, ha="left", va="center",
                fontsize=9, fontweight="bold", color="white", zorder=3)
        row += 1
        for name, s, e in tasks:
            yticks.append(yof(row))
            ylabels.append(name)
            # faint row background
            ax.add_patch(Rectangle((0.5, yof(row) - 0.42), WEEKS, 0.84,
                                   facecolor="#FAFAFA", edgecolor="none", zorder=0))
            # bar
            ax.add_patch(FancyBboxPatch((s - 1 + 0.5 + 0.06, yof(row) - 0.28),
                                        (e - s + 1) - 0.12, 0.56,
                                        boxstyle="round,pad=0.0,rounding_size=0.12",
                                        facecolor=face, edgecolor=edge_c,
                                        linewidth=1.0, zorder=2))
            ax.text(s - 1 + 0.5 + (e - s + 1) / 2, yof(row),
                    "S%d–S%d" % (s, e), ha="center", va="center",
                    fontsize=6.6, color="#222222", zorder=3)
            row += 1

    # week gridlines + labels
    for w in range(WEEKS + 1):
        ax.plot([w + 0.5, w + 0.5], [0.3, n_rows + 0.6], color="#DDDDDD",
                lw=0.6, zorder=0)
    for w in range(1, WEEKS + 1):
        ax.text(w, n_rows + 0.9, "S%d" % w, ha="center", va="center",
                fontsize=7.5, fontweight="bold")

    ax.set_yticks(yticks)
    ax.set_yticklabels(ylabels, fontsize=7.6)
    ax.set_xlim(0.5, WEEKS + 0.5)
    ax.set_ylim(0, n_rows + 1.5)
    ax.set_xticks([])
    for spine in ax.spines.values():
        spine.set_visible(False)
    ax.tick_params(length=0)
    ax.set_title("SINA : Diagramme de Gantt (phases de développement & bonnes pratiques)",
                 fontsize=11, fontweight="bold", pad=14)
    # continuous-practices note
    ax.text(0.5, -0.5,
            "Bonnes pratiques continues : Git (commits atomiques) · flutter analyze + tests à chaque lot · "
            "développement itératif & incrémental · offline-first / zéro coût.",
            ha="left", va="center", fontsize=7.2, style="italic", color="#555555")

    fig.tight_layout()
    fig.savefig("report/figures/gantt.pdf", bbox_inches="tight")
    plt.close(fig)
    print("wrote report/figures/gantt.pdf")


# =============================================================================
#  3) USE-CASE DIAGRAM  (Figure 2.1)
# =============================================================================
def _actor(ax, x, y, label, color="#333333"):
    # simple stick figure centred at (x, y) (y = head-top region)
    ax.add_patch(plt.Circle((x, y), 0.22, fill=False, lw=1.6, color=color, zorder=3))
    ax.plot([x, x], [y - 0.22, y - 1.0], color=color, lw=1.6, zorder=3)      # body
    ax.plot([x - 0.42, x + 0.42], [y - 0.55, y - 0.55], color=color, lw=1.6, zorder=3)  # arms
    ax.plot([x, x - 0.34], [y - 1.0, y - 1.55], color=color, lw=1.6, zorder=3)  # legs
    ax.plot([x, x + 0.34], [y - 1.0, y - 1.55], color=color, lw=1.6, zorder=3)
    ax.text(x, y - 1.95, label, ha="center", va="center", fontsize=9,
            fontweight="bold", color=color)


def render_usecase():
    fig, ax = plt.subplots(figsize=(11.5, 7.4))
    ax.set_xlim(0, 16)
    ax.set_ylim(0, 11)
    ax.axis("off")

    # system boundary
    ax.add_patch(Rectangle((4.4, 0.7), 7.2, 9.6, fill=False, lw=1.4,
                           edgecolor="#23445D", zorder=1))
    ax.text(8.0, 9.9, "SINA", ha="center", va="center", fontsize=12,
            fontweight="bold", color="#23445D")

    use_cases = [
        ("UC01 : Démarrer la détection", 8.7),
        ("UC02 : Recevoir une alerte vocale", 7.7),
        ("UC03 : Émettre une commande vocale", 6.7),
        ("UC04 : Lire un texte (OCR)", 5.7),
        ("UC05 : Déclencher un SOS", 4.7),
        ("UC06 : Configurer les paramètres", 3.7),
        ("UC07 : Consulter la carte GPS", 2.0),
    ]
    uc_pos = {}
    for label, y in use_cases:
        e = mpatches.Ellipse((8.0, y), 6.2, 0.78, facecolor="#DAE8FC",
                             edgecolor="#6C8EBF", lw=1.1, zorder=2)
        ax.add_patch(e)
        ax.text(8.0, y, label, ha="center", va="center", fontsize=8.4, zorder=3)
        uc_pos[label.split(" :")[0]] = (8.0, y)

    # actors
    _actor(ax, 1.7, 7.0, "Utilisateur\nmalvoyant")
    _actor(ax, 14.3, 5.0, "Proche /\nfamille")
    ua = (1.95, 6.3)   # right-ish of user
    pa = (14.05, 4.1)  # left-ish of family

    def line(p, ux, col="#555555", dashed=False):
        x, y = uc_pos[ux]
        edgex = 4.95 if p[0] < 8 else 11.05
        ax.plot([p[0], edgex], [p[1], y], color=col, lw=1.0,
                linestyle="--" if dashed else "-", zorder=1)

    for uc in ["UC01", "UC02", "UC03", "UC04", "UC05", "UC06"]:
        line(ua, uc)
    line(pa, "UC07")
    # family also receives the SOS (UC05) -> association
    x5, y5 = uc_pos["UC05"]
    ax.annotate("", xy=(pa[0], pa[1]), xytext=(11.05, y5),
                arrowprops=dict(arrowstyle="->", color="#C0392B", lw=1.1,
                                linestyle=(0, (4, 3))), zorder=2)
    ax.text(12.4, 4.55, "notifie", fontsize=7.5, color="#C0392B", style="italic")

    ax.set_title("SINA : Diagramme de cas d'utilisation",
                 fontsize=12, fontweight="bold", pad=8)
    fig.tight_layout()
    fig.savefig("report/figures/usecase.pdf", bbox_inches="tight")
    plt.close(fig)
    print("wrote report/figures/usecase.pdf")


# =============================================================================
#  4) SEQUENCE DIAGRAM  (Figure 2.2)
# =============================================================================
def render_sequence():
    fig, ax = plt.subplots(figsize=(13.2, 7.8))
    ax.set_xlim(0, 17)
    ax.set_ylim(0, 12)
    ax.axis("off")

    lifelines = [
        ("Utilisateur", 1.4, ENUM),
        ("SttService", 4.0, SERV),
        ("AppController", 7.2, CTRL),
        ("DetectorService\n(isolate)", 10.4, SERV),
        ("SpatialAudio /\nTtsService", 13.2, SERV),
        ("Gps /\nAlertService", 15.8, MODL),
    ]
    xpos = {}
    top = 11.2
    bottom = 0.8
    for name, x, fill in lifelines:
        ax.add_patch(FancyBboxPatch((x - 1.0, top), 2.0, 0.7,
                                    boxstyle="round,pad=0.02,rounding_size=0.08",
                                    facecolor=fill[0], edgecolor=fill[1],
                                    lw=1.1, zorder=3))
        ax.text(x, top + 0.35, name, ha="center", va="center", fontsize=7.8,
                fontweight="bold", zorder=4)
        ax.plot([x, x], [bottom, top], color="#888888", lw=0.9,
                linestyle=(0, (3, 3)), zorder=1)
        xpos[name] = x

    U = xpos["Utilisateur"]; S = xpos["SttService"]; C = xpos["AppController"]
    D = xpos["DetectorService\n(isolate)"]; T = xpos["SpatialAudio /\nTtsService"]
    G = xpos["Gps /\nAlertService"]

    def msg(x1, x2, y, label, dashed=False, col="#222222"):
        ax.annotate("", xy=(x2, y), xytext=(x1, y),
                    arrowprops=dict(arrowstyle="-|>", color=col, lw=1.1,
                                    linestyle=(0, (4, 3)) if dashed else "-"),
                    zorder=2)
        mid = (x1 + x2) / 2
        ax.text(mid, y + 0.16, label, ha="center", va="bottom", fontsize=7.4,
                zorder=4)

    def selfmsg(x, y, label):
        ax.annotate("", xy=(x + 0.05, y - 0.45), xytext=(x + 0.9, y - 0.45),
                    arrowprops=dict(arrowstyle="-|>", color="#222222", lw=1.0),
                    zorder=2)
        ax.plot([x, x + 0.9, x + 0.9], [y, y, y - 0.45], color="#222222",
                lw=1.0, zorder=2)
        ax.text(x + 1.0, y - 0.22, label, ha="left", va="center", fontsize=7.2,
                zorder=4)

    y = 10.2
    msg(U, S, y, "« ouvre la caméra »"); y -= 0.9
    msg(S, C, y, "commande reconnue"); y -= 0.9
    msg(C, D, y, "activer + flux d'images"); y -= 0.9
    msg(D, C, y, "boîtes filtrées (NMS)", dashed=True, col="#6C8EBF"); y -= 0.9
    selfmsg(C, y, "analyse scène (distance / position)"); y -= 1.05
    msg(C, T, y, "son spatial + annonce vocale"); y -= 0.9
    msg(C, G, y, "[si DANGER] position GPS + SOS", col="#C0392B"); y -= 0.9
    msg(C, U, y, "réécoute (STT)", dashed=True, col="#9673A6")

    ax.set_title("SINA : Diagramme de séquence (détection et annonce d'un obstacle)",
                 fontsize=11.5, fontweight="bold", pad=8)
    fig.tight_layout()
    fig.savefig("report/figures/sequence.pdf", bbox_inches="tight")
    plt.close(fig)
    print("wrote report/figures/sequence.pdf")


if __name__ == "__main__":
    render_uml()
    render_gantt()
    render_usecase()
    render_sequence()
