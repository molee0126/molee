import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:face_ai/domain/assessment.dart';
import 'package:face_ai/domain/landmarks.dart';
import 'package:face_ai/platform/mlkit_landmark_engine.dart';

FacePhoto photo({FaceAngle angle = FaceAngle.front, int size = 800}) =>
    FacePhoto(
      id: 'test-photo',
      angle: angle,
      fileName: 'front_test.jpg',
      capturedAt: DateTime.utc(2026, 10, 26),
      width: size,
      height: size,
      sensorOrientation: 90,
    );
Map<String, Point<double>> fixturePoints() => {
  for (var i = 0; i < 6; i++) 'fixture_$i': Point<double>(100.0 + i * 20, 200),
};
void main() {
  test('no face and multiple faces produce no usable landmark data', () {
    expect(
      evaluateLandmarks(photo: photo(), faceCount: 0).state,
      LandmarkState.noFace,
    );
    final many = evaluateLandmarks(
      photo: photo(),
      faceCount: 2,
      points: fixturePoints(),
    );
    expect(many.state, LandmarkState.multipleFaces);
    expect(many.points, isEmpty);
  });
  test('profile poses are explicitly unsupported in this first module', () {
    for (final angle in FaceAngle.values.where((a) => a != FaceAngle.front)) {
      expect(
        evaluateLandmarks(
          photo: photo(angle: angle),
          faceCount: 1,
          points: fixturePoints(),
        ).state,
        LandmarkState.unsupportedAngle,
      );
    }
  });
  test(
    'insufficient points, invalid coordinates and small images cannot pass',
    () {
      expect(
        evaluateLandmarks(photo: photo(), faceCount: 1).state,
        LandmarkState.insufficient,
      );
      expect(
        evaluateLandmarks(
          photo: photo(),
          faceCount: 1,
          points: {...fixturePoints(), 'invalid': const Point(double.nan, 20)},
        ).state,
        LandmarkState.insufficient,
      );
      expect(
        evaluateLandmarks(
          photo: photo(size: 100),
          faceCount: 1,
          points: fixturePoints(),
        ).state,
        LandmarkState.insufficient,
      );
    },
  );
  test('unknown pose and excessive yaw cannot pass', () {
    expect(
      evaluateLandmarks(
        photo: photo(),
        faceCount: 1,
        points: fixturePoints(),
      ).state,
      LandmarkState.insufficient,
    );
    expect(
      evaluateLandmarks(
        photo: photo(),
        faceCount: 1,
        points: fixturePoints(),
        yaw: 35,
        pitch: 0,
        roll: 0,
      ).state,
      LandmarkState.insufficient,
    );
  });
  test(
    'valid detector response keeps source identity and immutable coordinates',
    () {
      final source = photo();
      final result = evaluateLandmarks(
        photo: source,
        faceCount: 1,
        points: fixturePoints(),
        yaw: 1,
        pitch: 2,
        roll: 0,
      );
      expect(result.hasUsablePoints, true);
      expect(result.photoId, source.id);
      expect(() => result.points.clear(), throwsUnsupportedError);
    },
  );
  test(
    'unsupported desktop returns unavailable without invented points',
    () async {
      if (Platform.isIOS || Platform.isAndroid) return;
      final result = await const MlKitLandmarkEngine().detect(
        File('does-not-exist.jpg'),
        photo(),
      );
      expect(result.state, LandmarkState.unavailable);
      expect(result.points, isEmpty);
    },
  );
}
