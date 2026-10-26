import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CapturedImage {
  const CapturedImage(
    this.file,
    this.width,
    this.height,
    this.sensorOrientation,
  );
  final File file;
  final int width;
  final int height;
  final int sensorOrientation;
  Future<void> discard() async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      /* Cache cleanup. */
    }
  }
}

abstract class CaptureCamera extends ChangeNotifier {
  bool get ready;
  String? get error;
  Widget preview();
  Future<void> start();
  Future<void> stop();
  Future<CapturedImage> takePicture();
  Future<void> shutdown();
}

class DeviceCaptureCamera extends CaptureCamera {
  CameraController? _controller;
  Future<void> _queue = Future.value();
  bool _wanted = false;
  bool _closed = false;
  String? _error;
  @override
  bool get ready => _controller?.value.isInitialized == true && _wanted;
  @override
  String? get error => _error;
  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> _serial(Future<void> Function() task) {
    final next = _queue.then((_) => task());
    _queue = next.catchError((Object _) {});
    return next;
  }

  @override
  Future<void> start() {
    _wanted = true;
    return _serial(() async {
      if (_closed || !_wanted || ready) return;
      _error = null;
      _notify();
      CameraController? candidate;
      try {
        final cameras = await availableCameras();
        final front = cameras.where(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        if (front.isEmpty) {
          _error = '未找到前置相机。请使用有前置相机的手机。';
          return;
        }
        candidate = CameraController(
          front.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await candidate.initialize();
        await candidate.lockCaptureOrientation(DeviceOrientation.portraitUp);
        if (!_wanted || _closed) {
          await _disposeNative(candidate);
          return;
        }
        _controller = candidate;
      } on CameraException catch (e) {
        _error = switch (e.code) {
          'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' =>
            '相机权限未开启。请在系统设置中允许 FaceAI 使用相机，再点击重试。',
          'CameraAccessRestricted' => '系统限制了相机访问，请检查设备的访问限制。',
          _ => '相机暂时无法使用，请关闭其他拍摄应用后重试。',
        };
        await _disposeNative(candidate);
      } on Object {
        _error = '相机初始化失败，请重试。';
        await _disposeNative(candidate);
      } finally {
        _notify();
      }
    });
  }

  Future<void> _disposeNative(CameraController? controller) async {
    try {
      await controller?.dispose();
    } on Object {
      /* Native cleanup must not crash the route or lifecycle callback. */
    }
  }

  @override
  Future<void> stop() {
    _wanted = false;
    return _serial(() async {
      final previous = _controller;
      _controller = null;
      await _disposeNative(previous);
      _notify();
    });
  }

  @override
  Widget preview() =>
      ready ? CameraPreview(_controller!) : const SizedBox.shrink();
  @override
  Future<CapturedImage> takePicture() => _serialCapture();
  Future<CapturedImage> _serialCapture() async {
    // Capture and lifecycle disposal use the same queue.
    CapturedImage? result;
    await _serial(() async {
      if (!ready) throw StateError('相机尚未就绪');
      final controller = _controller!;
      final picture = await controller.takePicture();
      final file = File(picture.path);
      try {
        final codec = await ui.instantiateImageCodec(await file.readAsBytes());
        final frame = await codec.getNextFrame();
        result = CapturedImage(
          file,
          frame.image.width,
          frame.image.height,
          controller.description.sensorOrientation,
        );
        frame.image.dispose();
        codec.dispose();
      } on Object {
        if (await file.exists()) await file.delete();
        rethrow;
      }
    });
    return result!;
  }

  @override
  Future<void> shutdown() async {
    _closed = true;
    await stop();
    super.dispose();
  }
}
