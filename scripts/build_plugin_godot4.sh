#!/bin/zsh
set -euo pipefail

# Godot 4.x 向け iOS プラグインビルド自動化スクリプト
# 目的: 指定プラグインの release / release_debug xcframework を生成し、
#       例のディレクトリ構成・ファイル名に合わせて配置する。
#
# 使い方:
#   ./scripts/build_plugin_godot4.sh <plugin_name> [godot_tag]
#
# 例:
#   ./scripts/build_plugin_godot4.sh inappstore 4.6-stable
#
# 前提:
# - Xcode / Command Line Tools がインストール済み
# - scons が利用可能
# - godot サブモジュールが初期化済み

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN="${1:-}"
GODOT_TAG="${2:-4.6-stable}"

if [[ -z "${PLUGIN}" ]]; then
  echo "使い方: $0 <plugin_name> [godot_tag]"
  exit 1
fi

if [[ ! -d "${ROOT_DIR}/plugins/${PLUGIN}" ]]; then
  echo "ERROR: plugins/${PLUGIN} が見つかりません。"
  exit 1
fi

cd "${ROOT_DIR}"

echo "==> godot サブモジュールを ${GODOT_TAG} に切り替え"
git -C godot fetch --tags
git -C godot checkout "${GODOT_TAG}"

# Godot 4.x の SCons 仕様では version=4.0 が 4.x 系を指す
GODOT_VERSION_FLAG="4.0"

echo "==> Godot 4.x ヘッダ生成 (template_debug)"
# ヘッダ生成が目的なので、ビルドが始まったら自動で終了して良いが、
# ここでは完走させる。時間短縮したい場合は Ctrl+C で中断してもOK。
(
  cd godot
  scons platform=ios target=template_debug
)

echo "==> ${PLUGIN} release xcframework を生成"
./scripts/generate_xcframework.sh "${PLUGIN}" release "${GODOT_VERSION_FLAG}"

echo "==> ${PLUGIN} release_debug xcframework を生成"
./scripts/generate_xcframework.sh "${PLUGIN}" release_debug "${GODOT_VERSION_FLAG}"

# release_debug を debug 名に変更
mv "bin/${PLUGIN}.release_debug.xcframework" "bin/${PLUGIN}.debug.xcframework"

# 出力先を用意
OUT_DIR="bin/release/${PLUGIN}"
A_BINARY_NAME="inappstore.a"
rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"

# xcframework を移動し、gdip をコピー
mv "bin/${PLUGIN}.release.xcframework" "bin/${PLUGIN}.debug.xcframework" "${OUT_DIR}"
cp "plugins/${PLUGIN}/${PLUGIN}.gdip" "${OUT_DIR}"

echo "==> xcframework 内のファイル名を例の形式に合わせて変更"
# release
mv "${OUT_DIR}/${PLUGIN}.release.xcframework/ios-arm64/lib${PLUGIN}.arm64-ios.release.a" \
   "${OUT_DIR}/${PLUGIN}.release.xcframework/ios-arm64/${A_BINARY_NAME}"
mv "${OUT_DIR}/${PLUGIN}.release.xcframework/ios-arm64_x86_64-simulator/lib${PLUGIN}-simulator.release.a" \
   "${OUT_DIR}/${PLUGIN}.release.xcframework/ios-arm64_x86_64-simulator/${A_BINARY_NAME}"

/usr/libexec/PlistBuddy -c "Set :AvailableLibraries:0:BinaryPath ${A_BINARY_NAME}" \
  "${OUT_DIR}/${PLUGIN}.release.xcframework/Info.plist"
/usr/libexec/PlistBuddy -c "Set :AvailableLibraries:0:LibraryPath ${A_BINARY_NAME}" \
  "${OUT_DIR}/${PLUGIN}.release.xcframework/Info.plist"
/usr/libexec/PlistBuddy -c "Set :AvailableLibraries:1:BinaryPath ${A_BINARY_NAME}" \
  "${OUT_DIR}/${PLUGIN}.release.xcframework/Info.plist"
/usr/libexec/PlistBuddy -c "Set :AvailableLibraries:1:LibraryPath ${A_BINARY_NAME}" \
  "${OUT_DIR}/${PLUGIN}.release.xcframework/Info.plist"

# debug (release_debug)
mv "${OUT_DIR}/${PLUGIN}.debug.xcframework/ios-arm64/lib${PLUGIN}.arm64-ios.release_debug.a" \
   "${OUT_DIR}/${PLUGIN}.debug.xcframework/ios-arm64/${A_BINARY_NAME}"
mv "${OUT_DIR}/${PLUGIN}.debug.xcframework/ios-arm64_x86_64-simulator/lib${PLUGIN}-simulator.release_debug.a" \
   "${OUT_DIR}/${PLUGIN}.debug.xcframework/ios-arm64_x86_64-simulator/${A_BINARY_NAME}"

/usr/libexec/PlistBuddy -c "Set :AvailableLibraries:0:BinaryPath ${A_BINARY_NAME}" \
  "${OUT_DIR}/${PLUGIN}.debug.xcframework/Info.plist"
/usr/libexec/PlistBuddy -c "Set :AvailableLibraries:0:LibraryPath ${A_BINARY_NAME}" \
  "${OUT_DIR}/${PLUGIN}.debug.xcframework/Info.plist"
/usr/libexec/PlistBuddy -c "Set :AvailableLibraries:1:BinaryPath ${A_BINARY_NAME}" \
  "${OUT_DIR}/${PLUGIN}.debug.xcframework/Info.plist"
/usr/libexec/PlistBuddy -c "Set :AvailableLibraries:1:LibraryPath ${A_BINARY_NAME}" \
  "${OUT_DIR}/${PLUGIN}.debug.xcframework/Info.plist"

echo "==> 完了: ${OUT_DIR}"
echo "    - ${PLUGIN}.release.xcframework"
echo "    - ${PLUGIN}.debug.xcframework"
echo "    - ${PLUGIN}.gdip"
