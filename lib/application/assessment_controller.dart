import 'dart:io';
import 'package:flutter/foundation.dart';
import '../data/local_repository.dart';
import '../domain/assessment.dart';

class AssessmentController extends ChangeNotifier {
  AssessmentController(this.repository);
  final LocalRepository repository;
  List<Assessment> records = [];
  Assessment? current;
  bool busy = false;
  int unreadableCount = 0;
  Future<void> initialize() async {
    final loaded = await repository.loadAll();
    records = loaded.assessments;
    unreadableCount = loaded.unreadableCount;
    notifyListeners();
  }

  Future<void> _exclusive(Future<void> Function() action) async {
    if (busy) throw StateError('正在保存，请稍候');
    busy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> start(EntryMode mode) => _exclusive(() async {
    final assessment = Assessment.start(
      LocalConsent(acceptedAt: DateTime.now().toUtc(), entryMode: mode),
    );
    await repository.save(assessment);
    _setCurrent(assessment);
  });
  void resume(Assessment record) {
    current = record;
    notifyListeners();
  }

  Future<void> setGoals(Set<AestheticGoal> goals) => _exclusive(() async {
    if (goals.isEmpty) throw StateError('请至少选择一个诉求');
    final next = current!.copyWith(goals: goals);
    await repository.save(next);
    _setCurrent(next);
  });
  Future<void> capture({
    required FaceAngle angle,
    required File source,
    required int width,
    required int height,
    required int sensorOrientation,
  }) => _exclusive(() async {
    final next = await repository.attachPhoto(
      assessment: current!,
      angle: angle,
      source: source,
      width: width,
      height: height,
      sensorOrientation: sensorOrientation,
    );
    _setCurrent(next);
  });
  Future<void> finish() => _exclusive(() async {
    final next = current!.finish();
    await repository.save(next);
    _setCurrent(next);
  });
  Future<void> delete(Assessment record) => _exclusive(() async {
    await repository.delete(record.id);
    records.removeWhere((r) => r.id == record.id);
    if (current?.id == record.id) current = null;
  });
  void _setCurrent(Assessment assessment) {
    current = assessment;
    records = [assessment, ...records.where((r) => r.id != assessment.id)];
  }
}
