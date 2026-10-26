import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../application/assessment_controller.dart';
import '../domain/assessment.dart';
import '../platform/capture_camera.dart';
import '../domain/landmarks.dart';
import '../platform/mlkit_landmark_engine.dart';
import 'landmark_page.dart';
import 'capture_page.dart';
import 'pages.dart';

abstract final class Routes {
  static const home = '/';
  static const consent = '/consent';
  static const goals = '/goals';
  static const prepare = '/prepare';
  static const capture = '/capture';
  static const review = '/review';
  static const landmarks = '/landmarks';
}

class CaptureRequest {
  const CaptureRequest({this.angle, this.retake = false});
  final FaceAngle? angle;
  final bool retake;
}

typedef CameraFactory = CaptureCamera Function();

class FaceAiApp extends StatelessWidget {
  const FaceAiApp({
    super.key,
    required this.controller,
    this.cameraFactory = DeviceCaptureCamera.new,
    this.landmarkEngine = const MlKitLandmarkEngine(),
  });
  final AssessmentController controller;
  final CameraFactory cameraFactory;
  final LandmarkEngine landmarkEngine;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FaceAI',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF236B60),
        primary: const Color(0xFF236B60),
        surface: const Color(0xFFFAF9F5),
      ),
      scaffoldBackgroundColor: const Color(0xFFFAF9F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFAF9F5),
        centerTitle: false,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    ),
    onGenerateRoute: (settings) {
      final route = settings.name ?? Routes.home;
      final requiresSession = [
        Routes.goals,
        Routes.prepare,
        Routes.capture,
        Routes.review,
        Routes.landmarks,
      ].contains(route);
      final safe = requiresSession && controller.current == null
          ? Routes.home
          : route;
      final Widget page = switch (safe) {
        Routes.consent => ConsentPage(
          controller: controller,
          mode: settings.arguments is EntryMode
              ? settings.arguments! as EntryMode
              : EntryMode.guest,
        ),
        Routes.goals => GoalsPage(controller: controller),
        Routes.prepare => PreparePage(controller: controller),
        Routes.capture => CapturePage(
          controller: controller,
          camera: cameraFactory(),
          request: settings.arguments is CaptureRequest
              ? settings.arguments! as CaptureRequest
              : const CaptureRequest(),
        ),
        Routes.review => ReviewPage(controller: controller),
        Routes.landmarks => LandmarkPage(
          controller: controller,
          engine: landmarkEngine,
        ),
        _ => HomePage(controller: controller),
      };
      return MaterialPageRoute<void>(
        settings: RouteSettings(name: safe),
        builder: (_) => page,
      );
    },
  );
}

class AppFrame extends StatelessWidget {
  const AppFrame({
    super.key,
    required this.title,
    required this.children,
    this.stage,
    this.homeAction = true,
  });
  final String title;
  final List<Widget> children;
  final String? stage;
  final bool homeAction;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      actions: [
        if (homeAction)
          IconButton(
            tooltip: '回到首页，保留草稿',
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            icon: const Icon(Icons.home_outlined),
          ),
      ],
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              if (stage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    stage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.info_outline,
  });
  final String title;
  final String body;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Theme.of(
      context,
    ).colorScheme.primaryContainer.withValues(alpha: .38),
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(body, style: const TextStyle(height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget heading(BuildContext context, String title, String detail) => Padding(
  padding: const EdgeInsets.only(bottom: 24),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        detail,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          height: 1.6,
          color: const Color(0xFF596760),
        ),
      ),
    ],
  ),
);
Future<bool> perform(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作未完成。请检查设备存储空间并重试，已有记录会保留。')),
      );
    }
    return false;
  }
}

void goHome(BuildContext context) =>
    Navigator.of(context).popUntil((r) => r.isFirst);
