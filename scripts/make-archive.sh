#!/bin/bash
#
# App Store 제출용 `.xcarchive`를 만든다.
#
# 직접 배포(`make-app.sh` → `sign-app.sh` → `notarize.sh`)와는 다른 트랙이다.
# 그쪽은 ZIP을 링크로 나눠주는 것이고, 이쪽은 Xcode Organizer가 읽어
# App Store Connect로 올릴 아카이브를 만든다.
#
# 제출은 사람이 한다 — `docs/APPSTORE.md` 참고.
#
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHIVE="dist/Sweep.xcarchive"
PLIST="Sources/SweepApp/Info.plist"
CATALOG="Resources/Assets.xcassets"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")

# 준비물이 없으면 무엇이 없고 어떻게 만드는지 말하고 멈춘다.
# 조용히 대체하면 Organizer에 올리고 나서야 막힌 것을 알게 된다.
if ! command -v tuist >/dev/null 2>&1; then
  echo "tuist가 없다. Xcode 프로젝트를 생성할 수 없다."
  echo "  brew install tuist"
  exit 1
fi

# App Store 업로드는 자산 카탈로그 안의 아이콘을 요구한다. .icns만으로는 막힌다.
if [ ! -d "$CATALOG" ]; then
  echo "아이콘 자산이 없어 먼저 만든다"
  swift scripts/make-icon.swift --appiconset
fi

echo "── 프로젝트 생성 ──"
tuist generate --no-open

echo "── 아카이브 (버전 $VERSION 빌드 $BUILD) ──"
rm -rf "$ARCHIVE"

# 자동 서명을 먼저 시도한다. Apple Distribution 인증서가 있고 Xcode에 계정이
# 들어가 있으면 번들 ID 등록·프로파일 발급까지 여기서 끝난다.
#
# 실패해도 멈추지 않는다: Organizer의 "Distribute App"이 App Store 배포용으로
# 어차피 다시 서명하므로, 서명 없는 아카이브로도 제출은 된다.
if ! xcodebuild -workspace Sweep.xcworkspace -scheme Sweep \
     -configuration Release -archivePath "$ARCHIVE" \
     -allowProvisioningUpdates archive 2>&1 | tail -5; then
  echo
  echo "자동 서명이 막혔다. 서명 없이 아카이브한다 —"
  echo "Organizer가 Distribute App 단계에서 App Store용으로 다시 서명한다."
  rm -rf "$ARCHIVE"
  xcodebuild -workspace Sweep.xcworkspace -scheme Sweep \
    -configuration Release -archivePath "$ARCHIVE" \
    CODE_SIGNING_ALLOWED=NO archive 2>&1 | tail -5
fi

APP="$ARCHIVE/Products/Applications/Sweep.app"
[ -d "$APP" ] || { echo "아카이브에 앱이 없다: $APP"; exit 1; }

echo
echo "── 검증 ──"
printf '  버전 %s\n' "$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")"

# 샌드박스가 빠지면 업로드 검증에서 막힌다. 여기서 잡아야 Organizer까지 안 간다.
if codesign -d --entitlements - "$APP" 2>&1 | grep -q "app-sandbox"; then
  echo "  OK   App Sandbox"
else
  echo "  경고 App Sandbox가 안 보인다 — 서명 없이 아카이브된 경우 정상이다."
  echo "       Organizer가 Distribute App에서 entitlements를 붙여 다시 서명한다."
fi

echo
echo "아카이브: $ARCHIVE"
echo "제출: open $ARCHIVE  → Organizer → Distribute App → App Store Connect"
