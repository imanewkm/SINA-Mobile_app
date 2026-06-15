# -*- coding: utf-8 -*-
"""Generate a draw.io (mxGraph) class diagram for the SINA Flutter app.

Run:  python diagrams/gen_class_diagram.py
Out:  diagrams/diagramme_de_classe.drawio   (open at https://app.diagrams.net)
"""
from xml.sax.saxutils import escape

ROW_H = 22
SEP_H = 8
TITLE_H = 26

CLASS_STYLE = (
    "swimlane;fontStyle=1;align=center;verticalAlign=top;childLayout=stackLayout;"
    "horizontal=1;startSize=26;horizontalStack=0;resizeParent=1;resizeParentMax=0;"
    "resizeLast=0;collapsible=1;swimlaneFillColor=#FFFFFF;{fill}"
)
ROW_STYLE = (
    "text;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;"
    "spacingLeft=6;spacingRight=4;overflow=hidden;rotatable=0;"
    "points=[[0,0.5],[1,0.5]];portConstraint=eastwest;fontSize=11;"
)
SEP_STYLE = (
    "line;strokeWidth=1;fillColor=none;align=left;verticalAlign=middle;"
    "spacingTop=-1;spacingLeft=3;spacingRight=3;rotatable=0;labelPosition=right;"
    "points=[];portConstraint=eastwest;strokeColor=inherit;"
)

cells = []
_id = [10]


def nid():
    _id[0] += 1
    return "n%d" % _id[0]


def cell_xml(cid, value, style, parent, x=0, y=0, w=0, h=0, edge=False,
             source=None, target=None, vertex=True):
    geo = ('<mxGeometry x="%g" y="%g" width="%g" height="%g" as="geometry"/>'
           % (x, y, w, h)) if vertex else '<mxGeometry relative="1" as="geometry"/>'
    if edge:
        return ('<mxCell id="%s" value="%s" style="%s" edge="1" parent="%s" '
                'source="%s" target="%s"><mxGeometry relative="1" as="geometry"/>'
                '</mxCell>' % (cid, escape(value), style, parent, source, target))
    return ('<mxCell id="%s" value="%s" style="%s" vertex="1" parent="%s">%s'
            '</mxCell>' % (cid, escape(value), style, parent, geo))


def add_class(name, x, y, w, attrs, methods, fill="", stereotype=None):
    cid = nid()
    title = name if not stereotype else "<<%s>>\n%s" % (stereotype, name)
    n_rows = len(attrs) + len(methods)
    h = TITLE_H + n_rows * ROW_H + (SEP_H if methods else 0)
    style = CLASS_STYLE.format(fill=fill)
    cells.append(cell_xml(cid, title, style, "1", x, y, w, h))
    oy = TITLE_H
    for a in attrs:
        cells.append(cell_xml(nid(), a, ROW_STYLE, cid, 0, oy, w, ROW_H))
        oy += ROW_H
    if methods:
        cells.append(cell_xml(nid(), "", SEP_STYLE, cid, 0, oy, w, SEP_H))
        oy += SEP_H
        for m in methods:
            cells.append(cell_xml(nid(), m, ROW_STYLE, cid, 0, oy, w, ROW_H))
            oy += ROW_H
    return cid


# ---- colours -----------------------------------------------------------------
CTRL = "fillColor=#FFE6CC;strokeColor=#D79B00;"     # controller (orange)
SERV = "fillColor=#DAE8FC;strokeColor=#6C8EBF;"     # services   (blue)
MODL = "fillColor=#D5E8D4;strokeColor=#82B366;"     # models     (green)
ENUM = "fillColor=#E1D5E7;strokeColor=#9673A6;"     # enum       (purple)

# ---- controller --------------------------------------------------------------
ctrl = add_class(
    "AppController", 520, 380, 250,
    ["- instance: AppController {static}",
     "+ state: AppState",
     "+ curLang: String",
     "+ cameraOn: bool",
     "+ statusText: String",
     "+ sosConfirming: bool",
     "+ sosCountdown: int",
     "+ boxesNotifier: ValueNotifier<List<RawBox>>",
     "+ cameraController: CameraController?"],
    ["+ boot()",
     "+ activate()",
     "+ startCamera() / stopCamera()",
     "+ describeScene()",
     "+ readText()",
     "+ setLang(lang)",
     "+ triggerSOS() / confirmSosNow()",
     "+ announceLocation() / Status() / Help()"],
    fill=CTRL)

# ---- services (around the controller) ---------------------------------------
det = add_class("DetectorService", 60, 40, 230,
                ["- _isolate: Isolate", "- _interpreter (TFLite)"],
                ["+ init()", "+ detect(image): List<RawBox>", "+ dispose()"], SERV)

stt = add_class("SttService", 320, 40, 230,
                ["- _speech: SpeechToText", "- _locale: String"],
                ["+ init(): bool", "+ listen(lang, onResult)", "+ stop() / cancel()"], SERV)

tts = add_class("TtsService", 580, 40, 230,
                ["- _tts: FlutterTts"],
                ["+ init()", "+ configure(rate, volume)", "+ speak(text)", "+ stop()"], SERV)

gps = add_class("GpsService", 840, 40, 230,
                ["+ last: Position?"],
                ["+ start() / stop()", "+ currentPosition(): Position?", "+ isStale(): bool"], SERV)

alert = add_class("AlertService", 60, 300, 230,
                  ["- _alerts: List<SinaAlert>", "- _notifications"],
                  ["+ init()", "+ addAlert(msg, lat, lng): SinaAlert", "+ showSosNotification(body)"], SERV)

settings = add_class("SettingsService", 60, 520, 230,
                     ["- instance {static}", "- _prefs: SharedPreferences"],
                     ["+ init()", "+ getRaw(k) / setRaw(k, v)"], SERV)

ocr = add_class("OcrService", 1060, 300, 220,
                ["- _recognizer (ML Kit)"],
                ["+ readFromFile(path): String", "+ dispose()"], SERV)

spatial = add_class("SpatialAudioService", 1060, 460, 220,
                    ["- _player: AudioPlayer"],
                    ["+ init()", "+ cue(position, distance)", "+ dispose()"], SERV)

depth = add_class("DepthService", 1060, 620, 220,
                  ["- _channel: MethodChannel"],
                  ["+ init()", "+ depthAt(points): List<double>", "+ dispose()"], SERV)

sms = add_class("SmsService", 320, 760, 215,
                [], ["+ send(phone, msg): bool", "+ requestPermission(): bool"], SERV)

call = add_class("CallService", 560, 760, 215,
                 [], ["+ call(phone): bool", "+ requestPermission(): bool"], SERV)

# ---- models ------------------------------------------------------------------
appstate = add_class("AppState", 840, 300, 180,
                     ["idle", "listening", "responding"], [], ENUM, stereotype="enumeration")

detection = add_class("Detection", 840, 470, 230,
                      ["+ label: String", "+ distance: String", "+ position: String",
                       "+ confidence: double", "+ box: Rect", "+ spoken: Map<String,String>"],
                      ["+ spokenFor(lang): String"], MODL)

rawbox = add_class("RawBox", 60, 760, 230,
                   ["+ classId: int", "+ label: String", "+ confidence: double",
                    "+ x1,y1,x2,y2: double", "+ lightState: String?", "+ distanceMeters: double?"],
                   ["+ rect: Rect"], MODL)

sinaalert = add_class("SinaAlert", 840, 760, 230,
                      ["+ id: int", "+ message: String", "+ lat: double?",
                       "+ lng: double?", "+ timestamp: DateTime"],
                      ["+ toJson() / fromJson()"], MODL)

contact = add_class("EmergencyContact", 1100, 40, 220,
                    ["+ name: String", "+ phone: String"],
                    ["+ toJson() / fromJson()"], MODL)

# ---- edges -------------------------------------------------------------------
COMP = ("endArrow=diamondThin;endFill=1;endSize=10;html=1;rounded=0;"
        "edgeStyle=orthogonalEdgeStyle;strokeColor=#6C8EBF;")
USES = ("endArrow=open;endFill=0;dashed=1;html=1;rounded=0;"
        "edgeStyle=orthogonalEdgeStyle;strokeColor=#82B366;")
ASSOC = ("endArrow=open;endFill=0;html=1;rounded=0;"
         "edgeStyle=orthogonalEdgeStyle;strokeColor=#9673A6;")


def edge(src, dst, style, label=""):
    cells.append(cell_xml(nid(), label, style, "1", edge=True,
                          source=src, target=dst, vertex=False))


# controller composes the services
for s in (det, stt, tts, gps, alert, settings, ocr, spatial, depth, sms, call):
    edge(ctrl, s, COMP)

# controller -> models it manipulates
edge(ctrl, appstate, ASSOC, "state")
edge(ctrl, detection, USES)
edge(ctrl, contact, USES)

# services -> the model objects they produce/consume
edge(det, rawbox, USES, "creates")
edge(alert, sinaalert, USES, "creates")
edge(detection, rawbox, ASSOC, "grouped from")
edge(settings, contact, USES)

# ---- document ----------------------------------------------------------------
body = "\n        ".join(cells)
doc = (
    '<mxfile host="app.diagrams.net" version="24.0.0">\n'
    '  <diagram id="sina-classes" name="Diagramme de classes">\n'
    '    <mxGraphModel dx="1400" dy="900" grid="1" gridSize="10" guides="1" '
    'tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" '
    'pageWidth="1654" pageHeight="1169" math="0" shadow="0">\n'
    '      <root>\n'
    '        <mxCell id="0"/>\n'
    '        <mxCell id="1" parent="0"/>\n'
    '        %s\n'
    '      </root>\n'
    '    </mxGraphModel>\n'
    '  </diagram>\n'
    '</mxfile>\n' % body
)

with open("diagrams/diagramme_de_classe.drawio", "w", encoding="utf-8") as f:
    f.write(doc)
print("wrote diagrams/diagramme_de_classe.drawio  (%d cells)" % len(cells))
