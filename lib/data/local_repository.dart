import 'dart:convert';
import 'dart:io';
import '../domain/assessment.dart';

class LoadResult {
  const LoadResult(this.assessments, this.unreadableCount);
  final List<Assessment> assessments;
  final int unreadableCount;
}

/// Two committed metadata generations preserve rollback if a write is interrupted.
class LocalRepository {
  LocalRepository(this.root);
  final Directory root;
  Directory directoryFor(String id) {
    if (!isLocalId(id)) throw ArgumentError('非法记录编号');
    return Directory('${root.path}/$id');
  }

  File photoFile(Assessment assessment, FacePhoto photo) {
    if (!isPhotoName(photo.fileName)) throw ArgumentError('非法影像路径');
    return File('${directoryFor(assessment.id).path}/${photo.fileName}');
  }

  Future<void> save(Assessment assessment) async {
    final directory = directoryFor(assessment.id);
    await directory.create(recursive: true);
    final previous = await _generations(directory);
    final last = previous.isEmpty
        ? 0
        : int.tryParse(previous.first.uri.pathSegments.last.split('_').first) ??
              0;
    final now = DateTime.now().microsecondsSinceEpoch;
    final generation = '${now > last ? now : last + 1}_${newLocalId()}';
    final temporary = File('${directory.path}/$generation.tmp');
    await temporary.writeAsString(jsonEncode(assessment.toJson()), flush: true);
    await temporary.rename('${directory.path}/$generation.json');
    // Cleanup must never turn a successful commit into a reported failure.
    try {
      await _collectObsolete(directory);
    } on FileSystemException {
      /* Retry later. */
    }
  }

  Future<void> _collectObsolete(Directory directory) async {
    final committed = await _generations(directory);
    for (final stale in committed.skip(2)) {
      try {
        await stale.delete();
      } on FileSystemException {
        /* Best effort. */
      }
    }
    // Keep images referenced by either rollback generation; delete superseded captures.
    final keep = <String>{};
    for (final metadata in committed.take(2)) {
      try {
        final data =
            jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
        for (final p in data['photos'] as List) {
          keep.add((p as Map)['fileName'] as String);
        }
      } on Object {
        return;
      }
    }
    await for (final item in directory.list(followLinks: false)) {
      final name = item.uri.pathSegments.last;
      if (item is File && isPhotoName(name) && !keep.contains(name)) {
        try {
          await item.delete();
        } on FileSystemException {
          /* Retry later. */
        }
      }
    }
  }

  Future<List<File>> _generations(Directory directory) async {
    final files = await directory
        .list(followLinks: false)
        .where((f) => f is File && f.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((a, b) {
      int sequence(File file) =>
          int.tryParse(file.uri.pathSegments.last.split('_').first) ?? 0;
      final numeric = sequence(b).compareTo(sequence(a));
      return numeric == 0 ? b.path.compareTo(a.path) : numeric;
    });
    return files;
  }

  Future<LoadResult> loadAll() async {
    await root.create(recursive: true);
    final assessments = <Assessment>[];
    var unreadable = 0;
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final id = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (!isLocalId(id)) continue;
      Assessment? loaded;
      var needsAttention = false;
      for (final generation in await _generations(entry)) {
        try {
          final candidate = Assessment.fromJson(
            jsonDecode(await generation.readAsString()) as Map<String, dynamic>,
          );
          if (candidate.id != id) throw const FormatException('记录编号不符');
          loaded = candidate;
          break;
        } on Object {
          needsAttention =
              true; // The prior generation may still be recoverable.
        }
      }
      if (loaded == null) {
        unreadable++;
        continue;
      }
      final existing = <FaceAngle, FacePhoto>{};
      for (final photo in loaded.photos.values) {
        if (await photoFile(loaded, photo).exists()) {
          existing[photo.angle] = photo;
        }
      }
      if (existing.length != loaded.photos.length) {
        needsAttention = true;
        loaded = loaded.copyWith(
          photos: existing,
          status: AssessmentStatus.draft,
        );
      }
      if (needsAttention) unreadable++;
      assessments.add(loaded);
    }
    assessments.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return LoadResult(assessments, unreadable);
  }

  Future<Assessment> attachPhoto({
    required Assessment assessment,
    required FaceAngle angle,
    required File source,
    required int width,
    required int height,
    required int sensorOrientation,
  }) async {
    if (width <= 0 || height <= 0 || await source.length() == 0) {
      throw const FormatException('照片数据无效，请重拍');
    }
    final directory = directoryFor(assessment.id);
    await directory.create(recursive: true);
    final id = newLocalId();
    final fileName = '${angle.name}_$id.jpg';
    final destination = File('${directory.path}/$fileName');
    await source.copy(destination.path);
    final photo = FacePhoto(
      id: id,
      angle: angle,
      fileName: fileName,
      capturedAt: DateTime.now().toUtc(),
      width: width,
      height: height,
      sensorOrientation: sensorOrientation,
    );
    final next = assessment.copyWith(
      photos: {...assessment.photos, angle: photo},
      status: AssessmentStatus.draft,
    );
    try {
      await save(next);
    } on Object {
      await destination.delete();
      rethrow;
    }
    return next;
  }

  Future<void> delete(String id) async {
    final directory = directoryFor(id);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
