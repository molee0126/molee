import 'package:flutter/material.dart';
import '../application/assessment_controller.dart';
import '../domain/assessment.dart';
import '../domain/landmarks.dart';
import 'app.dart';

class LandmarkPage extends StatefulWidget {
  const LandmarkPage({
    super.key,
    required this.controller,
    required this.engine,
  });
  final AssessmentController controller;
  final LandmarkEngine engine;
  @override
  State<LandmarkPage> createState() => _LandmarkPageState();
}

class _LandmarkPageState extends State<LandmarkPage> {
  bool busy = false;
  LandmarkResult? result;
  @override
  Widget build(BuildContext context) {
    final record = widget.controller.current;
    final photo = record?.photos[FaceAngle.front];
    return AppFrame(
      title: '本机关键点检测',
      stage: '实验功能 · 待真机验证',
      children: [
        heading(
          context,
          '先定位，再逐步验证',
          '本轮仅处理已保存的正面照片。照片在本机交给检测器处理，不上传；检测结果不用于判断美丑或医疗建议。',
        ),
        const InfoCard(
          title: '这个模块能做什么',
          body: '返回人脸与面部关键点的检测状态。多人、未检测到面部、信息不足或原生模块不可用时会明确说明。几何测量与美学报告尚未启用。',
        ),
        if (photo == null || record == null)
          const Text('请先完成一张正面照片的采集。')
        else ...[
          SizedBox(
            height: 260,
            child: Image.file(
              widget.controller.repository.photoFile(record, photo),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Center(child: Text('照片无法读取，请返回重拍')),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      result = null;
                    });
                    LandmarkResult detected;
                    try {
                      detected = await widget.engine.detect(
                        widget.controller.repository.photoFile(record, photo),
                        photo,
                      );
                    } on Object {
                      detected = LandmarkResult(
                        photoId: photo.id,
                        state: LandmarkState.unavailable,
                        message: '检测未完成，未生成结果，请稍后重试。',
                      );
                    }
                    if (!mounted) return;
                    setState(() {
                      busy = false;
                      result = detected.photoId == photo.id
                          ? detected
                          : LandmarkResult(
                              photoId: photo.id,
                              state: LandmarkState.unavailable,
                              message: '照片已变化，请重新检测。',
                            );
                    });
                  },
            child: Text(busy ? '正在本机检测…' : '在本机检测正面关键点'),
          ),
          const SizedBox(height: 20),
          if (result case final response?)
            InfoCard(
              title: response.hasUsablePoints ? '已返回定位结果' : '本次未获得可用关键点',
              body: response.message,
              icon: response.hasUsablePoints
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
            ),
          const Text(
            '定位结果仅在本页临时显示，不保存为报告。重拍后请重新检测。',
            style: TextStyle(height: 1.6),
          ),
        ],
      ],
    );
  }
}
