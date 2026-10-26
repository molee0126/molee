import 'package:flutter/material.dart';
import '../application/assessment_controller.dart';
import '../domain/assessment.dart';
import 'app.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller});
  final AssessmentController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => AppFrame(
      title: 'FaceAI',
      homeAction: false,
      children: [
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE7EDE6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('V1.0 · 个人面部影像记录'),
          ),
        ),
        const SizedBox(height: 24),
        heading(
          context,
          '从不同角度，\n认识自己的面部特征',
          '用五张静态自拍，建立属于你的面部影像档案。保持自然，无需追求标准答案。',
        ),
        const InfoCard(
          title: '照片留在你的手机',
          body: '不需要注册，不上传影像。你可以随时在本机查看、继续或删除记录。',
          icon: Icons.shield_outlined,
        ),
        FilledButton(
          onPressed: controller.busy
              ? null
              : () => Navigator.pushNamed(
                  context,
                  Routes.consent,
                  arguments: EntryMode.guest,
                ),
          child: const Text('游客开始'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: controller.busy
              ? null
              : () => Navigator.pushNamed(
                  context,
                  Routes.consent,
                  arguments: EntryMode.local,
                ),
          child: const Text('使用本机档案模式'),
        ),
        const Text(
          '两种模式都只在本机保存；游客记录也会保留，直到你主动删除。',
          style: TextStyle(color: Color(0xFF596760), height: 1.5),
        ),
        const SizedBox(height: 24),
        const Text(
          '我的本地记录',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (controller.unreadableCount > 0)
          const InfoCard(
            title: '有记录需要检查',
            body: '部分文件无法读取或已缺失。已保留原文件，可恢复的草稿仍可继续拍摄。',
          ),
        if (controller.records.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('还没有记录。一次采集，五个角度。'),
          ),
        for (final record in controller.records)
          Card(
            elevation: 0,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                record.status == AssessmentStatus.captured
                    ? '五角度影像已采集'
                    : '拍摄草稿',
              ),
              subtitle: Text(
                '${_date(record.createdAt)} · ${record.photos.length}/5 张 · ${record.consent.entryMode == EntryMode.guest ? '游客' : '本机档案'}',
              ),
              onTap: controller.busy
                  ? null
                  : () {
                      controller.resume(record);
                      Navigator.pushNamed(
                        context,
                        record.goals.isEmpty
                            ? Routes.goals
                            : record.hasAllAngles
                            ? Routes.review
                            : Routes.prepare,
                      );
                    },
              trailing: IconButton(
                tooltip: '删除这份本地记录',
                icon: const Icon(Icons.delete_outline),
                onPressed: controller.busy
                    ? null
                    : () => _delete(context, record),
              ),
            ),
          ),
        const SizedBox(height: 24),
        const Text(
          '当前版本完成影像采集，不生成美学评分或医疗建议。\n动态表情、几何测量、报告与科普将在后续迭代加入。',
          style: TextStyle(height: 1.6, color: Color(0xFF596760)),
        ),
      ],
    ),
  );
  Future<void> _delete(BuildContext context, Assessment record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这份记录？'),
        content: const Text('将删除此记录的全部本地照片和数据，删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await perform(context, () => controller.delete(record));
    }
  }
}

String _date(DateTime date) {
  final d = date.toLocal();
  return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

class ConsentPage extends StatefulWidget {
  const ConsentPage({super.key, required this.controller, required this.mode});
  final AssessmentController controller;
  final EntryMode mode;
  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  bool adult = false;
  bool consent = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => AppFrame(
      title: '使用与隐私',
      stage: '开始之前',
      children: [
        heading(context, '由你决定，\n如何记录自己', '本阶段使用手机前置相机采集静态照片，仅保存在应用的本机私有目录。'),
        const InfoCard(
          title: '本地保存授权',
          body: '照片与诉求会留在本机。卸载应用可能清除记录，当前不提供云同步。你可以在首页逐份删除记录。',
        ),
        const InfoCard(
          title: '关于评估边界',
          body: '不提供颜值总分、自动医学诊断或注射处方。当前没有生成评估结果。未来演示结果会明确标注“演示”。',
        ),
        const InfoCard(
          title: '相机权限按需申请',
          body: '只有进入拍摄时才会请求相机权限。不申请相册、定位或录音权限，不用于身份识别。未来若需上传，必须另行征得你的授权。',
          icon: Icons.camera_alt_outlined,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: adult,
          onChanged: (v) => setState(() => adult = v ?? false),
          title: const Text('我已年满 18 周岁，拍摄对象是我本人'),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: consent,
          onChanged: (v) => setState(() => consent = v ?? false),
          title: const Text('我了解上述说明，同意在本机保存本次照片与诉求'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: adult && consent && !widget.controller.busy
              ? () async {
                  final ok = await perform(
                    context,
                    () => widget.controller.start(widget.mode),
                  );
                  if (ok && context.mounted) {
                    Navigator.pushReplacementNamed(context, Routes.goals);
                  }
                }
              : null,
          child: Text(widget.controller.busy ? '正在创建本地记录…' : '同意并继续'),
        ),
        TextButton(
          onPressed: widget.controller.busy
              ? null
              : () => Navigator.pop(context),
          child: const Text('暂不使用'),
        ),
      ],
    ),
  );
}

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key, required this.controller});
  final AssessmentController controller;
  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  late final Set<AestheticGoal> selected = {
    ...widget.controller.current!.goals,
  };
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => AppFrame(
      title: '美学诉求',
      stage: '01 / 04 · 选择关注点',
      children: [
        heading(context, '你想了解哪些方面？', '可多选，用于记录你的关注点。照片不会用于判断美丑。'),
        for (final goal in AestheticGoal.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CheckboxListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: selected.contains(goal)
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFFD9DED7),
                ),
              ),
              contentPadding: const EdgeInsets.all(12),
              title: Text(goal.label),
              value: selected.contains(goal),
              onChanged: widget.controller.busy
                  ? null
                  : (v) => setState(() {
                      v == true ? selected.add(goal) : selected.remove(goal);
                    }),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: selected.isEmpty || widget.controller.busy
              ? null
              : () async {
                  final ok = await perform(
                    context,
                    () => widget.controller.setGoals(selected),
                  );
                  if (ok && context.mounted) {
                    Navigator.pushNamed(context, Routes.prepare);
                  }
                },
          child: const Text('保存诉求，进入准备'),
        ),
      ],
    ),
  );
}

class PreparePage extends StatefulWidget {
  const PreparePage({super.key, required this.controller});
  final AssessmentController controller;
  @override
  State<PreparePage> createState() => _PreparePageState();
}

class _PreparePageState extends State<PreparePage> {
  bool checked = false;
  @override
  Widget build(BuildContext context) => AppFrame(
    title: '拍摄准备',
    stage: '02 / 04 · 自然状态',
    children: [
      heading(context, '给自己一点好光线', '约需 2–3 分钟。角度由你按指引调整，目前不会自动判断姿势是否合格。'),
      const InfoCard(
        title: '均匀光线，干净背景',
        body: '面向窗户或均匀灯光，避免逆光和强烈侧影。关闭系统美颜及滤镜。',
        icon: Icons.wb_sunny_outlined,
      ),
      const InfoCard(
        title: '完整露出面部',
        body: '移开遮脸的头发，摘下眼镜和口罩。保持自然表情，嘴唇放松。',
        icon: Icons.face_outlined,
      ),
      const InfoCard(
        title: '镜头与眼睛大致同高',
        body: '尽量固定距离，避免广角贴脸。可将手机放在支架上，必要时请他人协助侧脸拍摄。',
        icon: Icons.phone_iphone,
      ),
      const Text(
        '五个角度',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final angle in FaceAngle.values)
            Chip(
              avatar: Icon(
                widget.controller.current!.photos.containsKey(angle)
                    ? Icons.check_circle_outline
                    : Icons.panorama_outlined,
                size: 18,
              ),
              label: Text(angle.label),
            ),
        ],
      ),
      const SizedBox(height: 16),
      const Text(
        '左右均指你自己的左右脸，不以屏幕镜像为准。前置预览可能呈镜像，保存照片以相机原始输出为准。',
        style: TextStyle(height: 1.6),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: checked,
        onChanged: (v) => setState(() => checked = v ?? false),
        title: const Text('我已做好拍摄准备'),
      ),
      FilledButton(
        onPressed: checked
            ? () => Navigator.pushReplacementNamed(context, Routes.capture)
            : null,
        child: Text(
          widget.controller.current!.photos.isEmpty ? '开启相机，开始采集' : '开启相机，继续采集',
        ),
      ),
    ],
  );
}

class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key, required this.controller});
  final AssessmentController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final record = controller.current;
      if (record == null) {
        return const Scaffold(body: Center(child: Text('请返回首页选择记录')));
      }
      return AppFrame(
        title: '影像确认',
        stage: '04 / 04 · 仅保存在本机',
        children: [
          heading(
            context,
            record.status == AssessmentStatus.captured
                ? '影像已保存在本机'
                : '五个角度，逐一确认',
            '请检查清晰度、遮挡及角度。你可以重拍任何一张。当前没有生成美学评估报告。',
          ),
          for (final angle in FaceAngle.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (record.photos[angle] case final photo?)
                      SizedBox(
                        height: 230,
                        width: double.infinity,
                        child: Image.file(
                          controller.repository.photoFile(record, photo),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Center(child: Text('照片无法读取，请重拍')),
                        ),
                      )
                    else
                      const SizedBox(
                        height: 100,
                        child: Center(child: Text('尚未拍摄')),
                      ),
                    ListTile(
                      title: Text(angle.label),
                      subtitle: Text(
                        record.photos.containsKey(angle)
                            ? '已本地保存 · 待你确认'
                            : '需要补拍',
                      ),
                      trailing: TextButton(
                        onPressed: controller.busy
                            ? null
                            : () => Navigator.pushNamed(
                                context,
                                Routes.capture,
                                arguments: CaptureRequest(
                                  angle: angle,
                                  retake: true,
                                ),
                              ),
                        child: Text(
                          record.photos.containsKey(angle) ? '重拍' : '补拍',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const InfoCard(
            title: '本机关键点检测已接入',
            body: '几何测量、动态表情、报告与科普尚未启用。影像采集完成不代表已经完成 AI 美学评估。',
          ),
          OutlinedButton.icon(
            onPressed:
                record.photos.containsKey(FaceAngle.front) && !controller.busy
                ? () => Navigator.pushNamed(context, Routes.landmarks)
                : null,
            icon: const Icon(Icons.face_retouching_natural),
            label: const Text('本机关键点检测（实验）'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: !record.hasAllAngles || controller.busy
                ? null
                : () async {
                    final ok = await perform(context, controller.finish);
                    if (ok && context.mounted) goHome(context);
                  },
            child: const Text('确认采集完成，返回首页'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: controller.busy ? null : () => goHome(context),
            child: const Text('保留草稿，稍后确认'),
          ),
        ],
      );
    },
  );
}
