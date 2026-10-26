import 'dart:math';

enum FaceAngle {
  front('正面', '面向镜头，双眼平视，表情放松。', 0),
  left45('左侧 45°', '鼻尖向你自己的右侧转约 45°，展示左脸。', 45),
  right45('右侧 45°', '鼻尖向你自己的左侧转约 45°，展示右脸。', -45),
  left90('左侧 90°', '鼻尖向你自己的右侧转约 90°，展示左侧轮廓。', 90),
  right90('右侧 90°', '鼻尖向你自己的左侧转约 90°，展示右侧轮廓。', -90);

  const FaceAngle(this.label, this.instruction, this.targetYaw);
  final String label;
  final String instruction;
  final int targetYaw;
}

enum AestheticGoal {
  proportions('了解面部比例'),
  contour('关注面部轮廓'),
  symmetry('了解左右差异'),
  profile('了解侧面特征'),
  record('建立个人影像记录');

  const AestheticGoal(this.label);
  final String label;
}

enum EntryMode { guest, local }

enum AssessmentStatus { draft, captured }

class LocalConsent {
  const LocalConsent({required this.acceptedAt, required this.entryMode});
  static const version = '2026-10-26.v1';
  final DateTime acceptedAt;
  final EntryMode entryMode;
  Map<String, Object> toJson() => {
    'version': version,
    'acceptedAt': acceptedAt.toUtc().toIso8601String(),
    'entryMode': entryMode.name,
    'localImageStorage': true,
    'adultSelfConfirmed': true,
    'landmarkProcessing': 'explicit_local_request',
    'cloudUpload': false,
  };
  factory LocalConsent.fromJson(Map<String, dynamic> json) {
    if (json['version'] != version ||
        json['cloudUpload'] != false ||
        json['localImageStorage'] != true ||
        json['adultSelfConfirmed'] != true) {
      throw const FormatException('不支持的授权版本');
    }
    return LocalConsent(
      acceptedAt: DateTime.parse(json['acceptedAt'] as String),
      entryMode: EntryMode.values.byName(json['entryMode'] as String),
    );
  }
}

class FacePhoto {
  const FacePhoto({
    required this.id,
    required this.angle,
    required this.fileName,
    required this.capturedAt,
    required this.width,
    required this.height,
    required this.sensorOrientation,
    this.lens = 'front',
    this.previewMirrored = true,
  });
  final String id;
  final FaceAngle angle;
  final String fileName;
  final DateTime capturedAt;
  final int width;
  final int height;
  final int sensorOrientation;
  final String lens;
  final bool previewMirrored;
  Map<String, Object> toJson() => {
    'id': id,
    'angle': angle.name,
    'fileName': fileName,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'width': width,
    'height': height,
    'sensorOrientation': sensorOrientation,
    'lens': lens,
    'previewMirrored': previewMirrored,
    'isDemo': false,
  };
  factory FacePhoto.fromJson(Map<String, dynamic> json) {
    final name = json['fileName'] as String;
    if (!isPhotoName(name)) throw const FormatException('非法影像路径');
    final width = json['width'] as int;
    final height = json['height'] as int;
    if (width <= 0 || height <= 0) throw const FormatException('非法影像尺寸');
    return FacePhoto(
      id: json['id'] as String,
      angle: FaceAngle.values.byName(json['angle'] as String),
      fileName: name,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      width: width,
      height: height,
      sensorOrientation: json['sensorOrientation'] as int,
      lens: json['lens'] as String,
      previewMirrored: json['previewMirrored'] as bool,
    );
  }
}

class Assessment {
  Assessment({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.consent,
    Set<AestheticGoal> goals = const {},
    Map<FaceAngle, FacePhoto> photos = const {},
    this.status = AssessmentStatus.draft,
  }) : goals = Set.unmodifiable(goals),
       photos = Map.unmodifiable(photos);
  factory Assessment.start(LocalConsent consent) {
    final now = DateTime.now().toUtc();
    return Assessment(
      id: newLocalId(),
      createdAt: now,
      updatedAt: now,
      consent: consent,
    );
  }
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final LocalConsent consent;
  final Set<AestheticGoal> goals;
  final Map<FaceAngle, FacePhoto> photos;
  final AssessmentStatus status;
  bool get hasAllAngles => FaceAngle.values.every(photos.containsKey);
  FaceAngle get nextAngle => FaceAngle.values.firstWhere(
    (a) => !photos.containsKey(a),
    orElse: () => FaceAngle.front,
  );
  Assessment copyWith({
    Set<AestheticGoal>? goals,
    Map<FaceAngle, FacePhoto>? photos,
    AssessmentStatus? status,
  }) => Assessment(
    id: id,
    createdAt: createdAt,
    updatedAt: DateTime.now().toUtc(),
    consent: consent,
    goals: goals ?? this.goals,
    photos: photos ?? this.photos,
    status: status ?? this.status,
  );
  Assessment finish() {
    if (!hasAllAngles || goals.isEmpty) throw StateError('请先完成诉求选择及五角度采集');
    return copyWith(status: AssessmentStatus.captured);
  }

  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'consent': consent.toJson(),
    'goals': goals.map((g) => g.name).toList(),
    'photos': photos.values.map((p) => p.toJson()).toList(),
    'status': status.name,
  };
  factory Assessment.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 || !isLocalId(json['id'] as String)) {
      throw const FormatException('无法读取此记录版本');
    }
    final items = (json['photos'] as List)
        .map((p) => FacePhoto.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();
    if (items.map((p) => p.angle).toSet().length != items.length) {
      throw const FormatException('重复拍摄角度');
    }
    final result = Assessment(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      consent: LocalConsent.fromJson(
        Map<String, dynamic>.from(json['consent'] as Map),
      ),
      goals: (json['goals'] as List)
          .map((g) => AestheticGoal.values.byName(g as String))
          .toSet(),
      photos: {for (final p in items) p.angle: p},
      status: AssessmentStatus.values.byName(json['status'] as String),
    );
    if (result.status == AssessmentStatus.captured && !result.hasAllAngles) {
      throw const FormatException('采集完成记录缺失角度');
    }
    return result;
  }
}

String newLocalId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

bool isLocalId(String value) => RegExp(r'^[a-f0-9]{32}$').hasMatch(value);
bool isPhotoName(String value) =>
    RegExp(r'^[a-zA-Z0-9_-]+\.jpg$').hasMatch(value);
