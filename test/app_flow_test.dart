import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:face_ai/application/assessment_controller.dart';
import 'package:face_ai/data/local_repository.dart';
import 'package:face_ai/domain/assessment.dart';
import 'package:face_ai/platform/capture_camera.dart';
import 'package:face_ai/ui/app.dart';

class FakeCamera extends CaptureCamera {
  FakeCamera(this.directory, {this.denied = false});
  final Directory directory;
  final bool denied;
  int starts = 0;
  int stops = 0;
  int shots = 0;
  bool opened = false;
  bool closed = false;
  @override
  bool get ready => opened;
  @override
  String? get error => denied ? '相机权限未开启' : null;
  @override
  Widget preview() => const ColoredBox(color: Colors.grey);
  @override
  Future<void> start() async {
    starts++;
    opened = !denied;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    stops++;
    opened = false;
    notifyListeners();
  }

  @override
  Future<CapturedImage> takePicture() async {
    shots++;
    final file = File('${directory.path}/shot_$shots.png');
    await file.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNQzU74DwADmQHwLH5FmAAAAABJRU5ErkJggg==',
      ),
    );
    return CapturedImage(file, 1, 1, 90);
  }

  @override
  Future<void> shutdown() async {
    closed = true;
    opened = false;
    super.dispose();
  }
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 220, maxScrolls: 30);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  late Directory temp;
  late AssessmentController controller;
  late FakeCamera camera;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('faceai_widget_');
    controller = AssessmentController(
      LocalRepository(Directory('${temp.path}/private')),
    );
    await controller.initialize();
    camera = FakeCamera(temp);
  });
  tearDown(() async {
    controller.dispose();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    // Windows may retain a decoder's file handle for a short interval.
    for (var attempt = 0; ; attempt++) {
      try {
        await temp.delete(recursive: true);
        break;
      } on FileSystemException catch (error) {
        if (attempt >= 10) {
          // The Windows engine may memory-map a decoded image until process exit.
          // No product assertion is skipped; only temporary fixture cleanup waits.
          if (Platform.isWindows && error.osError?.errorCode == 32) break;
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });
  testWidgets(
    'consent blocks progress and camera starts only after explicit preparation',
    (tester) async {
      await tester.pumpWidget(
        FaceAiApp(controller: controller, cameraFactory: () => camera),
      );
      await tap(tester, '游客开始');
      expect(camera.starts, 0);
      await reveal(tester, find.text('同意并继续'));
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '同意并继续'),
      );
      expect(button.onPressed, isNull);
      await tap(tester, '我已年满 18 周岁，拍摄对象是我本人');
      await tap(tester, '我了解上述说明，同意在本机保存本次照片与诉求');
      // Real file IO cannot complete while the fake async clock is held.
      await reveal(tester, find.text('同意并继续'));
      await tester.runAsync(() async {
        await tester.tap(find.text('同意并继续'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.text('美学诉求'), findsOneWidget);
      expect(camera.starts, 0);
      await tap(tester, AestheticGoal.record.label);
      await reveal(tester, find.text('保存诉求，进入准备'));
      await tester.runAsync(() async {
        await tester.tap(find.text('保存诉求，进入准备'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      await tap(tester, '我已做好拍摄准备');
      await tap(tester, '开启相机，开始采集');
      expect(camera.starts, 1);
      await reveal(tester, find.text('拍摄正面'));
      expect(find.text('拍摄正面'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'five real UI captures save locally and finish without an assessment score',
    (tester) async {
      await tester.runAsync(() async {
        await controller.start(EntryMode.guest);
        await controller.setGoals({AestheticGoal.record});
      });
      await tester.pumpWidget(
        FaceAiApp(controller: controller, cameraFactory: () => camera),
      );
      final context = tester.element(find.text('FaceAI'));
      Navigator.pushNamed(context, Routes.capture);
      await tester.pumpAndSettle();
      for (final angle in FaceAngle.values) {
        await reveal(tester, find.text('拍摄${angle.label}'));
        await tester.runAsync(() async {
          await tester.tap(find.text('拍摄${angle.label}'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(find.text('使用这张并保存'), findsOneWidget);
        await reveal(tester, find.text('使用这张并保存'));
        await tester.runAsync(() async {
          await tester.tap(find.text('使用这张并保存'));
          await Future<void>.delayed(const Duration(milliseconds: 150));
        });
        await tester.pumpAndSettle();
      }
      expect(controller.current!.photos.length, 5);
      expect(camera.closed, true);
      expect(find.text('影像确认'), findsOneWidget);
      expect(find.textContaining('当前没有生成美学评估报告'), findsOneWidget);
      await reveal(tester, find.text('确认采集完成，返回首页'));
      await tester.runAsync(() async {
        await tester.tap(find.text('确认采集完成，返回首页'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(controller.current!.status, AssessmentStatus.captured);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
    },
  );
  testWidgets('denied camera offers retry and exit, never fake captures', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await controller.start(EntryMode.guest);
      await controller.setGoals({AestheticGoal.record});
    });
    camera = FakeCamera(temp, denied: true);
    await tester.pumpWidget(
      FaceAiApp(controller: controller, cameraFactory: () => camera),
    );
    Navigator.pushNamed(tester.element(find.text('FaceAI')), Routes.capture);
    await tester.pumpAndSettle();
    expect(find.text('相机权限未开启'), findsOneWidget);
    await reveal(tester, find.text('拍摄正面'));
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '拍摄正面'))
          .onPressed,
      isNull,
    );
    // Scroll back to the camera error before retrying.
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 350));
    await tester.pumpAndSettle();
    await tap(tester, '重试相机');
    expect(camera.starts, 2);
    await tap(tester, '退出并保留');
    expect(controller.current!.photos, isEmpty);
    expect(camera.closed, true);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  });
  testWidgets('background stops camera and resume reopens it', (tester) async {
    await tester.runAsync(() async {
      await controller.start(EntryMode.guest);
      await controller.setGoals({AestheticGoal.record});
    });
    await tester.pumpWidget(
      FaceAiApp(controller: controller, cameraFactory: () => camera),
    );
    Navigator.pushNamed(tester.element(find.text('FaceAI')), Routes.capture);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(camera.stops, greaterThan(0));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(camera.starts, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  });
  testWidgets(
    'small screen and large text remain scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(FaceAiApp(controller: controller));
      await tester.pumpAndSettle();
      await tap(tester, '游客开始');
      expect(find.text('使用与隐私'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
    },
  );
}
