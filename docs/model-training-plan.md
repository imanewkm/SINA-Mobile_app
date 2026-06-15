# SINA — Custom Obstacle Model: Training Plan (free resources)

Goal: train **one YOLOv8n model** covering the full SINA obstacle scope, using
**free, pre-annotated datasets** (minimal/no manual labelling), export to TFLite
(float16, imgsz 320), and drop it into the app. The decoder is class-count-
agnostic, so the only app change is the label/target constants.

Companion notebook: `scripts/sina_custom_model_colab.ipynb`.
Related: `scripts/export_tflite.py`, `docs/arcore_depth.md`, `docs/worklog-2026-06-07.md`.

---

## 1. Target classes (unified, 0-based — this order IS the app mapping)

| idx | class | primary free source |
|-----|-------|---------------------|
| 0 | person | Open Images V7 |
| 1 | bicycle | Open Images V7 |
| 2 | car | Open Images V7 |
| 3 | bus | Open Images V7 |
| 4 | truck | Open Images V7 |
| 5 | traffic light | Open Images V7 (+ BDD100K for colour) |
| 6 | stop sign | Open Images V7 |
| 7 | bench | Open Images V7 |
| 8 | dog | Open Images V7 |
| 9 | pole | Roboflow Universe (+ Open Images "Street light" proxy, SideGuide) |
| 10 | stairs | Open Images V7 "Stairs" (+ Roboflow) |
| 11 | curb | Roboflow Universe (+ SideGuide / Cityscapes) |
| 12 | door | Open Images V7 "Door" |
| 13 | crosswalk | Roboflow Universe "zebra crossing" (+ Mapillary) |

11 of 14 classes come from **one** source (Open Images V7). Only **pole, curb,
crosswalk** need supplementary Roboflow datasets.

---

## 2. Named free resources

- **Ultralytics YOLOv8** — model + training/export (`yolov8n.pt`).
- **Open Images V7** (Google) — 600 boxable classes incl. Person, Bicycle, Car,
  Bus, Truck, Traffic light, Stop sign, Bench, Dog, **Stairs**, **Door**,
  **Street light**. Annotations CC-BY. Pulled via **FiftyOne**.
- **FiftyOne** (Voxel51) — tool to download Open Images subsets (only the classes
  you want) and export to YOLO format.
- **Roboflow Universe** — thousands of community datasets, many already YOLOv8;
  source for **pole / curb / crosswalk** and extra stairs variety. Supports
  merging + class remap + YOLOv8 export. Check each dataset's licence.
- **SideGuide** — dataset purpose-built for blind sidewalk navigation (poles,
  bollards, stairs, curbs, barricades…). Optional sidewalk-specific supplement.
- **BDD100K** (Berkeley) — driving data with **traffic-light colour** + vehicles.
  Optional, to strengthen traffic lights.
- **Cityscapes / Mapillary Vistas** — rich urban segmentation (curb, crosswalk,
  pole). Optional; needs seg→box conversion; stricter licences.
- **COCO** — alternative source for the 9 common classes if not using Open Images.

> Licence note: SINA is free/open-source — prefer Open Images (CC-BY), COCO, and
> permissively-licensed Roboflow datasets. Verify Cityscapes/Mapillary/SideGuide
> terms before shipping.

---

## 3. Step-by-step (run in Colab, GPU runtime)

### Step 0 — Setup
```python
%pip install -q ultralytics fiftyone ai-edge-litert roboflow
```

### Step 1 — Pull the 11 common classes from Open Images V7 (FiftyOne)
Cap samples per class to keep the set balanced and the download manageable
(common classes like person/car are huge; rare ones small).
```python
import fiftyone as fo, fiftyone.zoo as foz
OI = ["Person","Bicycle","Car","Bus","Truck","Traffic light",
      "Stop sign","Bench","Dog","Stairs","Door","Street light"]
ds = foz.load_zoo_dataset(
    "open-images-v7", split="train", label_types=["detections"],
    classes=OI, max_samples=12000, seed=42, shuffle=True)
ds.export(export_dir="/content/oi", dataset_type=fo.types.YOLOv5Dataset,
          label_field="ground_truth", classes=OI)
# Also pull a validation split the same way into /content/oi_val.
```
This writes YOLO `images/` + `labels/` + a `dataset.yaml` with OI's own indices.

### Step 2 — Pull pole / curb / crosswalk from Roboflow Universe
Search Universe for: **"pole detection"**, **"curb detection"**, **"zebra
crossing" / "crosswalk"**, **"stairs detection"**. For each chosen project use
its export snippet:
```python
from roboflow import Roboflow
rf = Roboflow(api_key="YOUR_KEY")
d = rf.workspace("WS").project("PROJECT").version(N).download("yolov8", location="/content/rf_pole")
# repeat for curb, crosswalk (and optional extra stairs)
```
(Optional) Add **SideGuide** for sidewalk poles/curbs/stairs.

### Step 3 — Remap every source to the unified 14-class indices
Each source uses different class IDs/names. Write a tiny remapper that, for each
source, maps its label name → the unified index in section 1, rewrites every
`labels/*.txt` first column, and copies images into one merged tree:
```
/content/sina/images/{train,val}
/content/sina/labels/{train,val}
```
Drop any labels whose class isn't in our 14 (e.g. Open Images extras). Keep
"Street light" → map to `9 pole`.

### Step 4 — Write the unified data.yaml
```yaml
path: /content/sina
train: images/train
val: images/val
names:
  0: person
  1: bicycle
  2: car
  3: bus
  4: truck
  5: traffic light
  6: stop sign
  7: bench
  8: dog
  9: pole
  10: stairs
  11: curb
  12: door
  13: crosswalk
```

### Step 5 — Balance check (important)
Count instances per class. Person/car will dwarf stairs/curb/crosswalk. Fixes:
- cap over-represented classes (re-pull OI with smaller `max_samples` for common
  ones), and/or
- gather more rare-class images from additional Roboflow projects, and/or
- rely on YOLO's built-in augmentation (mosaic, flip, hsv) — already on.
Aim for at least a few hundred–1k instances per rare class.

### Step 6 — Train
```python
from ultralytics import YOLO
YOLO('yolov8n.pt').train(data='/content/sina/data.yaml',
    imgsz=320, epochs=100, batch=32, patience=20, name='sina')
```
`imgsz=320` is mandatory (matches `kInputSize`). ~30–90 min on a T4.

### Step 7 — Validate
```python
m = YOLO('runs/detect/sina/weights/best.pt'); print(m.val(imgsz=320).box.map50)
```
Inspect per-class mAP; if a class is weak, add data for it and retrain.

### Step 8 — Export float16 TFLite + verify
```python
out = YOLO('runs/detect/sina/weights/best.pt').export(format='tflite', imgsz=320, half=True)
from ai_edge_litert.interpreter import Interpreter; import numpy as np
it = Interpreter(model_path=str(out)); it.allocate_tensors()
i = it.get_input_details()[0]
assert list(i['shape'])==[1,320,320,3] and np.dtype(i['dtype']).name=='float32'
```

### Step 9 — Integrate into the app
1. Rename the downloaded file to `yolov8n.tflite`, overwrite
   `sina_mobile/assets/models/yolov8n.tflite`.
2. `lib/constants/yolo_config.dart`:
   ```dart
   const Set<int> targetClassIds = {0,1,2,3,4,5,6,7,8,9,10,11,12,13};
   const Map<int,String> cocoLabels = {
     0:'person',1:'bicycle',2:'car',3:'bus',4:'truck',5:'traffic light',
     6:'stop sign',7:'bench',8:'dog',9:'pole',10:'stairs',11:'curb',
     12:'door',13:'crosswalk'};
   ```
   (Traffic light is still index-checked for colour — update the `classId == 9`
   check in `detector_service.dart` / `_processTrafficLights` to the new traffic
   light index **5**.)
3. `lib/constants/labels.dart` — add fr/en/ar for the new labels:
   ```dart
   'pole':     {'fr':'Poteau','en':'Pole','ar':'عمود'},
   'stairs':   {'fr':'Escalier','en':'Stairs','ar':'درج'},
   'curb':     {'fr':'Bordure','en':'Curb','ar':'حافة الرصيف'},
   'door':     {'fr':'Porte','en':'Door','ar':'باب'},
   'crosswalk':{'fr':'Passage piéton','en':'Crosswalk','ar':'ممر المشاة'},
   ```
4. Rebuild: `flutter build apk --release`.

---

## 4. Gotchas / decisions
- **Traffic-light index changes** from COCO's 9 to the new model's **5** — update
  the hard-coded `classId == 9` check used by the colour classifier.
- **curb & crosswalk** are the hardest to source as boxes (they're road-surface
  features) — Roboflow zebra-crossing datasets are plentiful; curb is rarer, so
  SideGuide/Cityscapes may be needed.
- Keep **imgsz=320** everywhere; re-verify float32 I/O after every export.
- Iterate: train → check per-class mAP → add data for weak classes → retrain.

## 5. Fast-path (smallest effort)
If you want a quick first model: pull **Open Images V7** for the 11 it covers
(section 1), add **one Roboflow crosswalk** + **one pole** dataset, skip curb for
v1, train, ship. Add curb later.
