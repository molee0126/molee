#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS 构建需要 macOS 与 Xcode。" >&2
  exit 1
fi
command -v flutter >/dev/null || { echo "请安装 .flutter-version 指定的 Flutter。" >&2; exit 1; }
command -v pod >/dev/null || { echo "请先安装 CocoaPods。" >&2; exit 1; }
flutter --version
flutter pub get
flutter analyze
flutter test
flutter build ios --no-codesign
printf '\n未签名 iOS 构建完成。真机安装请在 Xcode 设置开发团队和签名。\n'
