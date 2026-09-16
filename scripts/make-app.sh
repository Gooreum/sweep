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

# 서명을 붙인다. **권한 허용 팝업이 매번 다시 뜨는 것을 막는 유일한 방법이다.**
#
# 서명하지 않으면 링커가 붙인 ad-hoc 서명이 남는다(`flags=adhoc,linker-signed`).
# 그 상태에서 사용자가 "허용"을 누르면 macOS는 그 허용을 **바이너리 해시 하나**에
# 못박아 기록한다. 이 기계의 TCC 데이터베이스에서 실제로 꺼내 해독한 값이다:
#
#     cdhash H"07d9cc838fb075c725fc08ee4067759ce6a1489d"
#
# 코드를 한 줄만 고쳐 다시 빌드하면 해시가 달라지고, macOS는 "모르는 앱"으로 보고
# 처음부터 다시 묻는다. 제대로 서명된 앱은 팀 ID와 번들 ID로 기록되어 유지된다
# (같은 데이터베이스의 Chrome: `certificate leaf[subject.OU] = EQHXZ8M8AV`).
#
# 타임스탬프는 붙이지 않는다 — 네트워크가 필요해 개발 루프가 느려진다.
# 공증용 정식 서명은 `sign-app.sh`가 따로 한다.
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
           | grep "Developer ID Application" | head -1 \
           | sed 's/.*"\(.*\)"/\1/')

if [ -n "$IDENTITY" ]; then
  codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$APP"
  echo "서명: $IDENTITY"
else
  # 인증서가 없는 기계에서도 번들은 나와야 한다. 다만 대가를 분명히 알린다.
  echo "⚠️  Developer ID 인증서가 없어 서명하지 않았다."
  echo "    빌드할 때마다 권한 허용 팝업이 다시 뜬다."
fi

echo "만듦: $APP  (버전 $VERSION 빌드 $BUILD)"
