# 在 iPhone 上验证 FaceAI（Windows 用户）

你不需要自己购买 Mac，但原生 iOS 编译必须在 macOS/Xcode 环境执行。本工程已提供手动触发的云端 macOS 编译配置：`.github/workflows/ios.yml`。

**已成功生成 FaceAI-unsigned.ipa，并通过 SHA-256、ZIP 完整性和 arm64 架构检查。尚未完成 Apple 签名、iPhone 安装或真机验收。**

- 已在本地保存：`dist/iphone/FaceAI-unsigned.ipa`（约 24.2 MB）。
- [本次成功构建](https://github.com/molee0126/molee/actions/runs/40279964404) · [下载本次云端文件](https://github.com/molee0126/molee/actions/runs/40279964404/artifacts/12631558748)；云端保留至 2026-11-02，本地文件不受该期限影响。
- 最低 iOS 15.5，版本 1.0.0，Bundle Identifier `com.faceai.faceAi`。
- SHA-256：`8488b59ec58fc0ad083c55f58c6fcf9a5af933578eb25bfc18050c7f170cd26d`。

你现在可以直接从下面第 4 步开始：将 IPA 导入 Windows 上的签名安装工具。未签名 IPA 无法直接在手机上点击安装。

## 路径 A：云端编译，再用 Windows 安装

1. 将本工程提交到你控制的 GitHub 仓库，建议私有。不要提交 `.tooling`、照片、密码、证书或其他个人数据。当前代码包没有用户照片。
2. 在仓库的 Actions 页，选择 **Build FaceAI for iPhone**，点击 **Run workflow**。流程使用云端 macOS 和 Xcode，安装锁定版本 Flutter，先分析、测试，再编译 iPhone release 应用。是否有可用 macOS runner、可用额度及执行权限由你的 GitHub 账户设置决定。
3. 运行成功后，在 Artifacts 中下载 **FaceAI-iPhone-unsigned**，解压得到 `FaceAI-unsigned.ipa` 和校验文件。该包没有 Apple 签名，不能直接点击安装。
4. 在 Windows 上使用 [Sideloadly 官方下载与说明](https://sideloadly.io/)中的本地签名安装流程：连接 iPhone、在手机上信任电脑、导入 IPA，并在安装工具中使用你自己的 Apple ID 完成签名。Apple ID、密码和双重认证码只在你电脑上的工具内输入，不要发到聊天或仓库中。工具有其自身的账户和隐私条款，由你选择是否使用。
5. 根据系统提示在 iPhone 的“设置 → 隐私与安全性”中打开开发者模式并重启；必要时在“设置 → 通用 → VPN 与设备管理”信任你的开发者签名，然后打开 FaceAI。

[Sideloadly 官方 FAQ](https://sideloadly.io/)说明其支持 Windows 和免费/付费 Apple ID，免费账户安装的 App 通常需每 7 天重新签名。官方页面还列出了 Windows 的 iTunes/iCloud 组件要求；以工具当前指引为准。

本流程编译 **release** 应用，避免 Flutter debug/JIT 对脱离调试器独立运行的限制。不要用侧载工具降低本 App 的最低 iOS 版本；本工程需要 iOS 15.5 或以上。

## 路径 B：以后可以借用 Mac

安装 Xcode、Flutter 3.47.8 和 CocoaPods，在项目目录执行：

```bash
bash scripts/build_ios.sh
open ios/Runner.xcworkspace
```

在 Xcode 的 Runner → Signing & Capabilities 中选择你自己的开发团队，必要时修改唯一 Bundle Identifier，连接并选择 iPhone，点击 Run。完整工程包括 Flutter 源码与 iOS 宿主，不能只复制 `ios` 文件夹。

## 首轮真机验证

- 首次启动：中文页面、游客和本机模式、不同意授权无法开始。
- 相机权限：拒绝后可退出；去系统设置允许后能重试；不请求麦克风、相册或定位权限。
- 正面、左右 45°、左右 90°：逐张拍摄，确认后保存；左右以本人为准，检查前置镜像与保存照片是否一致。
- 未确认的照片不进入档案；确认后的照片即使退出也能继续；任意一张重拍后只有对应角度更新。
- 切到后台、锁屏、返回前台，检查相机正常恢复；退出采集页后相机指示灯关闭。
- 完成五张、确认完成、关闭再打开，记录和照片存在；删除一份记录后其影像全部清除。
- 在影像确认页手动运行“本机关键点检测（实验）”，确认无脸/多人/不清晰等情况有明确提示；验证正面照片的方向与 EXIF，不将检测结果视为医学诊断。
- 飞行模式下重复流程，确认采集和本地保存可用；照片不出现在系统公共相册。
- 验证 iOS 私有目录的备份排除与数据保护；目前尚未做真机恢复或备份实测。

记录手机型号、iOS 版本、安装方式、每一步是否通过；反馈问题时先描述操作和错误文案，无需上传自拍。

## 当前限制

Windows 本机已进行的检查见 `VALIDATION.md`。本地 Flutter 自动测试中的假相机不代表已验证真实 iPhone 相机。云端已通过静态分析、24 项测试及 Xcode 原生编译，生成 56.2 MB 的 Runner.app 并打包为 IPA。构建成功不代表已通过 iPhone 运行时验证，尤其还需检查权限、镜像、后台恢复、本地保存和关键点效果。

开发者模式只允许开发签名应用运行，并不会替代签名，依据 [Apple 官方说明](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)。云构建产物的获取方式见 [GitHub 官方 artifact 说明](https://docs.github.com/en/actions/tutorials/store-and-share-data)。
