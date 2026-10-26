# FaceAI V1.0

消费者自拍面部美学 APP 的实际 Flutter 工程，中文 UI，iOS / Android，本地优先。已实现阶段 0/1 的五角度静态影像采集，并接入第一轮本机正面关键点检测实验模块；不产生美学评估结果。

只有 Windows 与 iPhone 的安装路径已准备：**云端 Mac 编译 → 下载 IPA → Windows 本地签名安装**，详见 [iPhone 安装说明](docs/IPHONE_SETUP.md)。已完成 macOS/Xcode 云构建并生成未签名 IPA：[成功构建](https://github.com/molee0126/molee/actions/runs/40279964404) · [构建文件](https://github.com/molee0126/molee/actions/runs/40279964404/artifacts/12631558748)。安装时仍需在 Windows 本地签名；iPhone 真机验收尚未执行。

## 当前功能

- 路由及 Material 3 主题；游客 / 本机档案模式，无账号服务。
- 年龄与本人拍摄确认、本机影像保存授权、相机按需授权。
- 美学诉求多选、拍摄准备检查、五角度文字和构图示意。
- 前置相机预览、拍摄后确认、单张重拍、未保存照片丢弃。
- 每张照片保存后即形成可恢复草稿，退出或重启后继续。
- 本地影像确认、采集完成状态、逐份删除照片与记录。
- 分层数据模型、双代元数据恢复、照片缺失时回退至草稿。
- 正面照片本机 ML Kit 人脸/关键点适配：主动触发、单人检查、信息不足/侧脸未支持/原生模块不可用的明确状态。尚未做原生真机推理验证。
- 单元测试及使用可注入相机的页面流程测试。测试中的相机和照片是测试夹具，不代表真机效果或 AI 结果。

左右以被拍摄者自身为准：左侧角度展示左脸，鼻尖转向自身右侧。前置相机预览可能镜像；保存相机原始照片，保留传感器朝向和预览镜像元数据。当前角度手动确认，没有自动角度合格判定。

## 运行

本项目锁定 Flutter 3.47.8 / Dart 3.13.7（`.flutter-version`），依赖具体版本见 `pubspec.lock`。

Windows 已下载并校验官方 SDK。为避开 Windows 对中文 SDK 路径的兼容问题，当前 SDK/缓存位于同一任务获准使用的英文路径，`.tooling/tooling-root.txt` 记录位置（忽略提交）。工具脚本不会修改系统全局 PATH。新工作区可使用英文目录安装 SDK：

```powershell
# 新工作区没有 SDK 时运行，需要网络及约数 GB 磁盘空间
.\scripts\bootstrap.ps1
.\scripts\flutter.ps1 pub get
.\scripts\flutter.ps1 doctor --verbose
.\scripts\flutter.ps1 devices
.\scripts\flutter.ps1 run -d <设备编号>
```

也可使用已安装的 Flutter：`flutter pub get`、`flutter run`。Android 需要 Android SDK、JDK 17 或兼容的 Android Studio JDK 以及设备。iOS 需要 macOS、Xcode 和 iOS 设备/模拟器，Windows 无法执行 iOS 构建。

```powershell
.\scripts\verify_windows.ps1
# 全英文源码目录可直接使用 flutter analyze / flutter test
.\scripts\flutter.ps1 build apk --debug
```

Mac：`flutter build ios --no-codesign`。正式上架前需要独立设置签名、正式 applicationId / bundle identifier、图标及商店隐私声明，当前 Android applicationId 为 `com.faceai.face_ai`，iOS Bundle Identifier 为 `com.faceai.faceAi`。

iOS 最低版本为 15.5，采用 CocoaPods；Android minSdk 为 24。iOS 构建配置和 Windows 侧载说明见 `docs/IPHONE_SETUP.md`。在当前中文目录请优先使用 `verify_windows.ps1`，该脚本复制到英文验证目录，不改变主源码。

## 代码地图

- `lib/main.dart`：本机存储初始化、错误重试。
- `lib/ui/`：路由、主题、授权、诉求、准备、相机向导、影像确认。
- `lib/domain/assessment.dart`：诉求、角度、版本化授权、影像与测评记录。
- `lib/application/assessment_controller.dart`：先持久化后发布状态的应用流程。
- `lib/data/local_repository.dart`：应用私有目录、双代元数据、恢复、影像替换、删除。
- `lib/platform/`：相机、本地目录与 ML Kit 的原生适配。
- `lib/domain/landmarks.dart`：与原生检测器分离的关键点结果及实验拍摄提示。
- `.github/workflows/ios.yml`：手动触发的 macOS release 构建，产出供本地签名的未签名 IPA。
- `test/`：模型、持久化、数据恢复与完整页面流程测试。
- `docs/VALIDATION.md`：本次实际执行的检查及设备限制。

## 影像与隐私

影像在 `ApplicationSupport/faceai_private/<随机记录ID>/` 内保存，不写入公共相册。JSON 元数据仅存相对照片文件名，不接受任意路径或远程 URL。双代元数据采用临时文件写入并提交为新文件；保留最近两次提交用于恢复。重拍后旧图在不再被这两份提交引用时清理，删除记录会删除整个记录目录。拍摄预览临时文件在确认、取消或正常离开时清理；进程被强杀时，系统相机缓存可能暂留，需依赖系统缓存清理。

Android 禁用系统备份与设备迁移；iOS 原生通道将私有目录排除系统备份。授权版本和时间随每份记录保存，云上传授权固定为 false。没有云上传、登录、分析统计或广告功能，影像不发送到服务端。游客也持久化本地记录；卸载应用可能清除记录。

当前照片没有额外的应用层加密，依靠系统应用隔离和设备数据保护。上架前需要真机验证备份排除、权限和相机行为，补充符合发行区域的隐私文本与数据保护评审。

不输出颜值总分、自动医学诊断或注射处方。没有虚构评估数据；未来演示内容必须显式标记“演示”。

## 后续范围

已实现本机人脸关键点适配和可解释的检测状态。下一步在 iPhone 真机验证 EXIF 方向、镜像、原生检测可用性及不同光照表现，再推进关键点质量验证；当前检测阈值是实验工程规则，不是医学或审美标准，也不强制阻断影像保存。侧脸关键点与几何测量仍未启用。动态表情、几何测量、报告和科普是后续 V1.0 迭代。皮肤六维度、VISIA、医生后台、产品/品牌推荐暂缓。

## 技术依据

- [Flutter 官方 SDK archive](https://docs.flutter.dev/install/archive)
- [camera 官方包：权限、生命周期与拍照 API](https://pub.dev/packages/camera)
- [path_provider 官方包：Application Support](https://pub.dev/packages/path_provider)
- [Google 官方：设备端人脸检测](https://developers.google.com/ml-kit/vision/face-detection)
- [Flutter ML Kit 桥接包：API 和 iOS 15.5 要求](https://pub.dev/packages/google_mlkit_face_detection)（社区维护，并非 Google 官方 Flutter SDK）

前序聊天已检索，但其助手正文仅返回引用占位；本工程按本次请求中明确的范围实施，不推定未能读取的额外规格。

