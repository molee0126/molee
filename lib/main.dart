import 'package:flutter/material.dart';
import 'application/assessment_controller.dart';
import 'platform/local_storage.dart';
import 'ui/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Startup());
}

class Startup extends StatefulWidget {
  const Startup({super.key});
  @override
  State<Startup> createState() => _StartupState();
}

class _StartupState extends State<Startup> {
  AssessmentController? _controller;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    AssessmentController? candidate;
    try {
      candidate = AssessmentController(await openLocalRepository());
      await candidate.initialize();
      if (mounted) {
        setState(() => _controller = candidate);
      } else {
        candidate.dispose();
      }
    } on Object {
      candidate?.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller != null) return FaceAiApp(controller: _controller!);
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: _failed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('无法打开本地存储，记录未被清除。'),
                    TextButton(onPressed: _load, child: const Text('重新打开')),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
