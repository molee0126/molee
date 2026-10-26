# FaceAI 实际验证记录

日期：2026-10-26（Asia/Shanghai）。本机为 Windows，未发现原有工程或 Git 仓库。已创建真实 Flutter 工程与 Android/iOS 平台目录。

## 已执行并通过

| 检查 | 实际结果 |
|---|---|
| 官方 Flutter SDK 下载与校验 | Flutter 3.47.8 / Dart 3.13.7；SHA-256 与官方发布元数据一致 |
| 依赖解析 | camera 0.12.1、path_provider 2.1.6、google_mlkit_face_detection 0.15.1；具体版本保存在 pubspec.lock |
| Dart 格式化 | 15 个 Dart 文件完成格式化 |
| Flutter 静态分析 | No issues found |
| Flutter 自动测试 | **24 项通过，0 项失败** |
| 原生配置静态检查 | iOS plist/XML 可解析、最低部署版本 15.5、CocoaPods 配置引用；Android 隐私配置存在；录音关闭；应用层没有上传客户端 |
| UI 实际渲染 | Flutter 测试渲染器导出首页图，已目视检查中文排版；不代表 iPhone 截图 |
| 验证副本一致性 | 最终 lib/test 以源码主目录复制到英文路径后进行分析和测试 |

测试覆盖：模型与授权往返、集合不可变、路径越界拒绝、草稿恢复、五角度完成约束、重拍与失败保护、损坏元数据回退、影像缺失回退至草稿、删除、系统时间回拨后的版本排序、授权前不启动相机、完整页面采集与确认、权限拒绝、前后台生命周期、小屏滚动，以及正面关键点检测的无脸/多人/侧脸未支持/信息不足/坐标异常/姿态异常/桌面不可用状态。

原始分析和测试输出见 [flutter-checks.log](validation/flutter-checks.log)。测试内的照片和检测坐标是明确的测试夹具，没有进入生产界面或伪造任何用户评估。

## 已执行但受环境限制

- `flutter doctor`：缺少 Android SDK、JDK / Android 工具链；未连接可用于 Flutter 的移动设备。Windows 桌面目标不在本次范围内。
- `flutter build apk --debug`：失败，报告找不到 Android SDK；用户已指定优先 iOS，因此未继续安装 Android 工具链。
- `flutter build ios`：Windows Flutter 未提供该构建子命令；本机没有 Xcode、CocoaPods 或 Swift 编译器。没有生成 `.app` 或 `.ipa`，也未验证原生 Swift/CocoaPods 编译。
- 原中文工作区曾触发 Flutter 分析协议的非 ASCII 路径通信错误，SDK 中文路径曾触发着色器 include 失败。已将工具与缓存放到任务允许的英文路径，使用 `scripts/verify_windows.ps1` 在英文副本成功验证；主源码保留在原目录。没有修改 Flutter SDK 源码来绕过错误。
- Windows 渲染器可能保持图片内存映射至测试进程退出，测试清理仅对系统错误 32 延后删除临时夹具；业务断言没有跳过。临时文件位于忽略提交的工具目录，进程结束后可清理。

## iOS 云构建已完成

- [GitHub Actions run #1](https://github.com/molee0126/molee/actions/runs/40279964404)：成功。
- 构建源码提交：`ccb37ad3eeb7745bc578971ed6ae7200f4075858`。
- macOS 云端静态分析无问题，24 项自动测试通过。
- CocoaPods 安装完成；Xcode 原生编译成功（93.9 秒），产出 `Runner.app`（56.2 MB）。
- IPA 已下载至本地，外层 artifact 与 IPA SHA-256 均校验通过，ZIP 完整性通过，确认为 arm64/iOS 15.5。
- 原生依赖锁文件已保存到 `ios/Podfile.lock`；构建信息和文件校验见 `dist/iphone/BUILDINFO.txt` 与 `VERIFICATION.json`。
- 未签名；没有 Apple 证书或描述文件，没有安装到手机。

## iOS 尚未完成的验收

1. 云端工作流已成功运行；尚未完成手机安装和真机验收。
2. 原生相机权限、真实拍照尺寸、EXIF/镜像方向、锁屏及后台恢复尚未在 iPhone 上测试。
3. iOS 备份排除、Data Protection 设置、照片删除与系统缓存行为尚未真机实测。
4. ML Kit 原生推理、机型与光照覆盖未验证。当前仅接入本机适配和实验规则，不能视为有效的美学算法。
5. 尚未完成 Apple 签名及安装。已生成供 Windows 本地签名的未签名 release IPA；安装途径见 [iPhone 安装说明](IPHONE_SETUP.md)。

动态表情、几何测量、报告、科普、皮肤维度、VISIA、医生后台和品牌推荐均未实现。没有颜值总分、医学诊断或注射处方功能。
