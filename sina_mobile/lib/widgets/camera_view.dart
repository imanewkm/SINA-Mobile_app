import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../controller/app_controller.dart';
import '../models/detection.dart';
import 'bbox_painter.dart';

/// Full-screen camera preview with a bounding-box overlay. Renders nothing
/// when the camera is off or not yet initialized.
class CameraView extends StatelessWidget {
  final AppController controller;
  const CameraView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final cam = controller.cameraController;
    if (!controller.cameraOn ||
        cam == null ||
        !cam.value.isInitialized) {
      return const SizedBox.shrink();
    }

    // Visual-only; excluded from semantics here (inside the widget) so the
    // outer Positioned stays a direct child of the parent Stack.
    return Positioned.fill(
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: cam.value.previewSize?.height ?? 1,
                height: cam.value.previewSize?.width ?? 1,
                child: CameraPreview(cam),
              ),
            ),
            Positioned.fill(
              child: ValueListenableBuilder<List<RawBox>>(
                valueListenable: controller.boxesNotifier,
                builder: (_, boxes, __) => CustomPaint(
                  painter: BBoxPainter(
                    boxes: boxes,
                    lang: controller.curLang,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
