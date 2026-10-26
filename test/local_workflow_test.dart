import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:face_ai/domain/assessment.dart';
import 'package:face_ai/data/local_repository.dart';
import 'package:face_ai/application/assessment_controller.dart';

Assessment fresh() => Assessment.start(
  LocalConsent(
    acceptedAt: DateTime.utc(2026, 10, 26),
    entryMode: EntryMode.guest,
  ),
);
void main() {
  late Directory temp;
  late LocalRepository repo;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('faceai_test_');
    repo = LocalRepository(Directory('${temp.path}/private'));
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });
  test(
    'serialization preserves consent, goals, status and disables uploads',
    () {
      final a = fresh().copyWith(goals: {AestheticGoal.contour});
      final copy = Assessment.fromJson(
        jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>,
      );
      expect(copy.id, a.id);
      expect(copy.goals, a.goals);
      expect(copy.consent.toJson()['cloudUpload'], false);
      expect(copy.nextAngle, FaceAngle.front);
    },
  );
  test('cannot complete missing angles or empty goals', () {
    expect(() => fresh().finish(), throwsStateError);
    expect(
      () => fresh().copyWith(goals: {AestheticGoal.record}).finish(),
      throwsStateError,
    );
  });
  test('cannot mutate model collections externally', () {
    final a = fresh();
    expect(() => a.goals.add(AestheticGoal.profile), throwsUnsupportedError);
    expect(() => a.photos.clear(), throwsUnsupportedError);
  });
  test('rejects future schema, cloud consent and traversal identifiers', () {
    expect(
      () => Assessment.fromJson({...fresh().toJson(), 'schemaVersion': 99}),
      throwsFormatException,
    );
    expect(() => repo.directoryFor('../outside'), throwsArgumentError);
    expect(
      () => LocalConsent.fromJson({
        ...fresh().consent.toJson(),
        'cloudUpload': true,
      }),
      throwsFormatException,
    );
    expect(
      () => FacePhoto.fromJson({'fileName': '../../outside.jpg'}),
      throwsFormatException,
    );
  });
  test('drafts survive repository restart and remain isolated', () async {
    final a = fresh().copyWith(goals: {AestheticGoal.record});
    await repo.save(a);
    await repo.save(fresh());
    final loaded = await LocalRepository(repo.root).loadAll();
    expect(loaded.assessments.length, 2);
    expect(loaded.unreadableCount, 0);
    expect(loaded.assessments.firstWhere((x) => x.id == a.id).goals, a.goals);
  });
  test(
    'capture, retake, completion and deletion persist across restart',
    () async {
      var a = fresh().copyWith(goals: {AestheticGoal.contour});
      final source = File('${temp.path}/capture.jpg');
      await source.writeAsBytes([255, 216, 255, 217]);
      for (final angle in FaceAngle.values) {
        a = await repo.attachPhoto(
          assessment: a,
          angle: angle,
          source: source,
          width: 20,
          height: 30,
          sensorOrientation: 90,
        );
      }
      final oldFront = a.photos[FaceAngle.front]!;
      a = await repo.attachPhoto(
        assessment: a,
        angle: FaceAngle.front,
        source: source,
        width: 30,
        height: 40,
        sensorOrientation: 90,
      );
      expect(a.photos.length, 5);
      expect(a.photos[FaceAngle.front]!.id, isNot(oldFront.id));
      a = a.finish();
      await repo.save(a);
      expect(
        (await repo.loadAll()).assessments.single.status,
        AssessmentStatus.captured,
      );
      expect(await repo.photoFile(a, oldFront).exists(), false);
      await repo.delete(a.id);
      expect((await repo.loadAll()).assessments, isEmpty);
    },
  );
  test('failed retake does not change committed photo', () async {
    final source = File('${temp.path}/capture.jpg');
    await source.writeAsBytes([1, 2, 3]);
    var a = await repo.attachPhoto(
      assessment: fresh(),
      angle: FaceAngle.front,
      source: source,
      width: 20,
      height: 30,
      sensorOrientation: 90,
    );
    final old = a.photos[FaceAngle.front]!;
    await expectLater(
      repo.attachPhoto(
        assessment: a,
        angle: FaceAngle.front,
        source: File('${temp.path}/missing'),
        width: 20,
        height: 30,
        sensorOrientation: 90,
      ),
      throwsA(isA<FileSystemException>()),
    );
    a = (await repo.loadAll()).assessments.single;
    expect(a.photos[FaceAngle.front]!.id, old.id);
    expect(await repo.photoFile(a, old).exists(), true);
  });
  test('corrupt latest metadata recovers prior generation', () async {
    final a = fresh();
    await repo.save(a);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repo.save(a.copyWith(goals: {AestheticGoal.record}));
    final files = await repo
        .directoryFor(a.id)
        .list()
        .where((x) => x.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    await files.first.writeAsString('{broken');
    final loaded = await repo.loadAll();
    expect(loaded.assessments.single.goals, isEmpty);
  });
  test(
    'missing image returns resumable draft instead of false completion',
    () async {
      var a = fresh().copyWith(goals: {AestheticGoal.record});
      final source = File('${temp.path}/capture.jpg');
      await source.writeAsBytes([1, 2]);
      for (final angle in FaceAngle.values) {
        a = await repo.attachPhoto(
          assessment: a,
          angle: angle,
          source: source,
          width: 20,
          height: 30,
          sensorOrientation: 90,
        );
      }
      await repo.save(a.finish());
      await repo.photoFile(a, a.photos[FaceAngle.left45]!).delete();
      final loaded = await repo.loadAll();
      expect(loaded.unreadableCount, 1);
      expect(loaded.assessments.single.status, AssessmentStatus.draft);
      expect(loaded.assessments.single.nextAngle, FaceAngle.left45);
    },
  );
  test('interrupted temporary metadata never becomes a record', () async {
    final a = fresh();
    await repo.save(a);
    await File(
      '${repo.directoryFor(a.id).path}/999999.tmp',
    ).writeAsString('broken');
    expect((await repo.loadAll()).assessments.single.id, a.id);
  });
  test('unreadable directory is reported, not erased', () async {
    final d = repo.directoryFor(fresh().id);
    await d.create(recursive: true);
    await File('${d.path}/broken.json').writeAsString('broken');
    final loaded = await repo.loadAll();
    expect(loaded.unreadableCount, 1);
    expect(await d.exists(), true);
  });
  test('controller saves before publishing new state', () async {
    final controller = AssessmentController(repo);
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.start(EntryMode.local);
    await expectLater(controller.setGoals({}), throwsStateError);
    expect(controller.current!.goals, isEmpty);
    expect(controller.busy, false);
    await controller.setGoals({AestheticGoal.profile});
    final restarted = AssessmentController(repo);
    addTearDown(restarted.dispose);
    await restarted.initialize();
    expect(restarted.records.single.goals, {AestheticGoal.profile});
  });
  test(
    'new saves remain newest after a backwards system clock change',
    () async {
      final a = fresh();
      await repo.save(a);
      final metadata =
          (await repo
                  .directoryFor(a.id)
                  .list()
                  .where((x) => x.path.endsWith('.json'))
                  .cast<File>()
                  .toList())
              .single;
      await metadata.rename(
        '${repo.directoryFor(a.id).path}/9999999999999999_old.json',
      );
      await repo.save(a.copyWith(goals: {AestheticGoal.profile}));
      expect((await repo.loadAll()).assessments.single.goals, {
        AestheticGoal.profile,
      });
    },
  );
}
