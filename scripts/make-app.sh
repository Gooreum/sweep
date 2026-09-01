#!/bin/bash
#
# `swift build` 산출물을 `.app` 번들로 감싼다.
#
# SPM은 앱 번들을 만들지 못한다. Finder에서 열리고 Dock에 뜨고 남에게 줄 수
# 있으려면 `Contents/{MacOS,Info.plist,Resources}` 구조가 있어야 한다.
#
# 서명은 `sign-app.sh`, 공증은 `notarize.sh`가 맡는다. 여기서는 껍데기만 만든다.
#
set -euo pipefail
cd "$(dirname "$0")/.."

APP="dist/Sweep.app"
PLIST="Sources/SweepApp/Info.plist"
ICON="dist/AppIcon.icns"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")

# 아이콘이 없으면 만든다. 없는 채로 번들을 내면 Dock에 기본 회색이 뜬다.
if [ ! -f "$ICON" ]; then
  echo "아이콘이 없어 먼저 만든다"
  swift scripts/make-icon.swift
fi

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 번들 안에서는 이름이 Sweep이다 — Info.plist의 CFBundleExecutable과 맞춰야 한다.
# 어긋나면 LaunchServices가 실행 파일을 못 찾아 "앱을 열 수 없습니다"로 끝난다.
cp .build/release/SweepApp "$APP/Contents/MacOS/Sweep"
cp "$PLIST" "$APP/Contents/Info.plist"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

echo "만듦: $APP  (버전 $VERSION 빌드 $BUILD)"
