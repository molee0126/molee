import 'dart:io';
import 'dart:math';
import 'assessment.dart';

enum LandmarkState {
  detected,
  noFace,
  multipleFaces,
  insufficient,
  unsupportedAngle,
  unavailable,
}

class LandmarkResult {
  LandmarkResult({
    required this.photoId,
    required this.state,
    required this.message,
    Map<String, Point<double>> points = const {},
    this.yaw,
    this.pitch,
    this.roll,
  }) : points = Map.unmodifiable(points);
  final String photoId;
  final LandmarkState state;
  final String message;
  final Map<String, Point<double>> points;
  final double? yaw;
  final double? pitch;
  final double? roll;
  // This is a detector response, never an aesthetic or medical assessment.
  bool get hasUsablePoints => state == LandmarkState.detected;
}

abstract interface class LandmarkEngine {
  Future<LandmarkResult> detect(File image, FacePhoto photo);
}

/// Experimental capture hints only. Do not use these to derive aesthetic scores.
LandmarkResult evaluateLandmarks({
  required FacePhoto photo,
  required int faceCount,
  Map<String, Point<double>> points = const {},
  double? yaw,
  double? pitch,
  double? roll,
}) {
  LandmarkResult result(LandmarkState state, String message) => LandmarkResult(
    photoId: photo.id,
    state: state,
    message: message,
    points: state == LandmarkState.detected ? points : const {},
    yaw: yaw,
    pitch: pitch,
    roll: roll,
  );
  if (photo.angle != FaceAngle.front) {
    return result(LandmarkState.unsupportedAngle, '侧脸关键点尚未完成验证，本轮仅检测正面照片。');
  }
  if (faceCount == 0) {
    return result(LandmarkState.noFace, '没有定位到面部。请检查光线、遮挡和画面完整性。');
  }
  if (faceCount != 1) {
    return result(LandmarkState.multipleFaces, '画面中有多张脸，请只保留你本人后重拍。');
  }
  if (photo.width < 200 ||
      photo.height < 200 ||
      points.length < 5 ||
      points.values.any(
        (p) =>
            !p.x.isFinite ||
            !p.y.isFinite ||
            p.x < 0 ||
            p.y < 0 ||
            p.x > photo.width ||
            p.y > photo.height,
      )) {
    return result(LandmarkState.insufficient, '面部信息不足，暂不显示关键点。请使用清晰、完整的正面照片。');
  }
  if (yaw == null ||
      pitch == null ||
      roll == null ||
      !yaw.isFinite ||
      !pitch.isFinite ||
      !roll.isFinite ||
      yaw.abs() > 15 ||
      pitch.abs() > 15 ||
      roll.abs() > 12) {
    return result(
      LandmarkState.insufficient,
      '正面姿态信息不足或偏转较大，建议平视镜头后重拍。提示规则仍待真机验证。',
    );
  }
  return result(LandmarkState.detected, '已在本机返回面部关键点。定位结果仅用于后续算法验证，尚未进行美学评估。');
}
