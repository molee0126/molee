import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../domain/assessment.dart';
import '../domain/landmarks.dart';

/// Calls the native on-device ML Kit detector. No network or upload client.
/// Each request owns its detector and always releases it, including on failure.
class MlKitLandmarkEngine implements LandmarkEngine {
  const MlKitLandmarkEngine();
  @override
  Future<LandmarkResult> detect(File image, FacePhoto photo) async {
    if (photo.angle != FaceAngle.front) {
      return evaluateLandmarks(photo: photo, faceCount: 0);
    }
    if (!Platform.isIOS && !Platform.isAndroid) {
      return LandmarkResult(
        photoId: photo.id,
        state: LandmarkState.unavailable,
        message: '本机关键点检测需要 iPhone 或 Android 真机，此环境未运行原生检测。',
      );
    }
    FaceDetector? detector;
    try {
      if (!await image.exists()) {
        throw const FileSystemException('Missing capture');
      }
      detector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          enableContours: false,
          enableClassification: false,
          enableTracking: false,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
      final faces = await detector.processImage(
        InputImage.fromFilePath(image.path),
      );
      if (faces.length != 1) {
        return evaluateLandmarks(photo: photo, faceCount: faces.length);
      }
      final face = faces.single;
      final points = <String, Point<double>>{};
      for (final entry in face.landmarks.entries) {
        if (entry.value case final value?) {
          points[entry.key.name] = Point(
            value.position.x.toDouble(),
            value.position.y.toDouble(),
          );
        }
      }
      return evaluateLandmarks(
        photo: photo,
        faceCount: 1,
        points: points,
        yaw: face.headEulerAngleY,
        pitch: face.headEulerAngleX,
        roll: face.headEulerAngleZ,
      );
    } on Object {
      return LandmarkResult(
        photoId: photo.id,
        state: LandmarkState.unavailable,
        message: '本机检测暂不可用，未生成任何关键点结果。照片仍保存在本机，可稍后重试。',
      );
    } finally {
      try {
        await detector?.close();
      } on Object {
        /* No result is invented if native cleanup fails. */
      }
    }
  }
}
