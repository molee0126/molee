import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../application/assessment_controller.dart';
import '../domain/assessment.dart';
import '../platform/capture_camera.dart';
import 'app.dart';

class CapturePage extends StatefulWidget {
  const CapturePage({
    super.key,
    required this.controller,
    required this.camera,
    required this.request,
  });
  final AssessmentController controller;
  final CaptureCamera camera;
  final CaptureRequest request;
  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> with WidgetsBindingObserver {
  late FaceAngle angle =
      widget.request.angle ?? widget.controller.current!.nextAngle;
  CapturedImage? pending;
  Uint8List? pendingPreview;
  bool working = false;
  bool active = true;
  bool released = false;
  String? captureError;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.camera.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active) {
      unawaited(widget.camera.start());
    } else {
      unawaited(widget.camera.stop());
    }
  }

  Future<void> _shoot() async {
    setState(() {
      working = true;
      captureError = null;
    });
    CapturedImage? picture;
    try {
      picture = await widget.camera.takePicture();
      final previewBytes = await picture.file.readAsBytes();
      if (!mounted || !active) {
        await picture.discard();
        return;
      }
      setState(() {
        pending = picture;
        pendingPreview = previewBytes;
      });
    } on Object {
      await picture?.discard();
      if (mounted) setState(() => captureError = '拍摄未完成，请保持应用在前台后重试。');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _accept() async {
    final picture = pending;
    if (picture == null) return;
    setState(() => working = true);
    final ok = await perform(
      context,
      () => widget.controller.capture(
        angle: angle,
        source: picture.file,
        width: picture.width,
        height: picture.height,
        sensorOrientation: picture.sensorOrientation,
      ),
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => working = false);
      return;
    }
    await picture.discard();
    if (!mounted) return;
    pending = null;
    pendingPreview = null;
    if (widget.request.retake) {
      await _release();
      if (mounted) Navigator.pop(context);
    } else if (widget.controller.current!.hasAllAngles) {
      await _release();
      if (mounted) Navigator.pushReplacementNamed(context, Routes.review);
    } else {
      setState(() {
        angle = widget.controller.current!.nextAngle;
        working = false;
      });
    }
  }

  Future<void> _release() async {
    if (released) return;
    released = true;
    await widget.camera.shutdown();
  }

  Future<void> _leave() async {
    if (working) return;
    await _release();
    if (mounted) goHome(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(pending?.discard() ?? Future.value());
    unawaited(_release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !working,
    child: ListenableBuilder(
      listenable: widget.camera,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('五角度采集'),
          actions: [
            TextButton(
              onPressed: working ? null : _leave,
              child: const Text('退出并保留'),
            ),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  Text(
                    '03 / 04 · 已保存 ${widget.controller.current!.photos.length}/5 张',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: widget.controller.current!.photos.length / 5,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    angle.label,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    angle.instruction,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ColoredBox(
                        color: const Color(0xFF172E29),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (pending != null && pendingPreview != null)
                              Image.memory(pendingPreview!, fit: BoxFit.contain)
                            else if (widget.camera.ready)
                              Center(child: widget.camera.preview()),
                            if (pending == null && widget.camera.ready)
                              IgnorePointer(
                                child: CustomPaint(
                                  painter: FaceGuidePainter(angle),
                                ),
                              ),
                            if (pending == null && !widget.camera.ready)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: widget.camera.error != null
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.no_photography_outlined,
                                              size: 44,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              widget.camera.error!,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                height: 1.6,
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: working
                                                  ? null
                                                  : () => widget.camera.start(),
                                              child: const Text(
                                                '重试相机',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : const CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                ),
                              ),
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 16,
                              child: Text(
                                pending != null
                                    ? '拍摄预览 · 尚未保存'
                                    : '轮廓仅为构图示意 · 角度需手动调整',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  backgroundColor: Color(0x99000000),
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (captureError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        captureError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (pending != null) ...[
                    const Text(
                      '确认面部完整、自然且清晰，再保存这一张。',
                      style: TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: working ? null : _accept,
                      child: Text(working ? '正在保存…' : '使用这张并保存'),
                    ),
                    TextButton(
                      onPressed: working
                          ? null
                          : () async {
                              final old = pending;
                              setState(() => pending = null);
                              await old?.discard();
                            },
                      child: const Text('重新拍摄'),
                    ),
                  ] else
                    FilledButton.icon(
                      onPressed: working || !widget.camera.ready
                          ? null
                          : _shoot,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(working ? '拍摄中…' : '拍摄${angle.label}'),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final a in FaceAngle.values)
                        ActionChip(
                          avatar: Icon(
                            widget.controller.current!.photos.containsKey(a)
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 16,
                          ),
                          label: Text(a.label),
                          onPressed: working || pending != null
                              ? null
                              : () => setState(() => angle = a),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '左右指你自己的左右脸。预览可能呈镜像；方向提示以文字为准。影像仅在你点击保存后进入本地档案。',
                    style: TextStyle(color: Color(0xFF596760), height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Illustration only: no AI detection or automatic pose validation is implied.
class FaceGuidePainter extends CustomPainter {
  FaceGuidePainter(this.angle);
  final FaceAngle angle;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final side = angle == FaceAngle.left90 || angle == FaceAngle.right90;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .44),
      width: size.width * (side ? .46 : .62),
      height: size.height * .63,
    );
    canvas.drawOval(rect, paint);
    paint.color = Colors.white.withValues(alpha: .3);
    canvas.drawLine(
      Offset(rect.left - 10, size.height * .38),
      Offset(rect.right + 10, size.height * .38),
      paint,
    );
    canvas.drawLine(
      Offset(size.width / 2, rect.top),
      Offset(size.width / 2, rect.bottom),
      paint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * .91),
        width: size.width * .82,
        height: size.height * .4,
      ),
      3.45,
      2.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(FaceGuidePainter oldDelegate) =>
      angle != oldDelegate.angle;
}
