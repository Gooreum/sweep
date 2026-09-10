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
#   bash scripts/make-archive.sh               버전 검사 → 아카이브 → 결과물 검사
#   bash scripts/make-archive.sh --check-only  버전 검사만 (올리기 전에 번호 확인)
#   bash scripts/make-archive.sh --verify-only 이미 만든 아카이브가 소스와 같은지만
#
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-}"
ARCHIVE="${ARCHIVE:-dist/Sweep.xcarchive}"
PLIST="${PLIST:-Sources/SweepApp/Info.plist}"
CATALOG="Resources/Assets.xcassets"
# Organizer가 업로드 기록을 남기는 곳. 여기 없는 업로드(다른 Mac, Transporter)는 모른다.
ORGANIZER_ARCHIVES="${ORGANIZER_ARCHIVES:-$HOME/Library/Developer/Xcode/Archives}"

fail() { echo "  멈춤 $*" >&2; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$PLIST")

# 점으로 나눈 정수끼리 비교한다. 문자열로 비교하면 "10" < "9"가 된다.
version_gt() {
  python3 -c 'import sys; t = lambda s: tuple(map(int, s.split(".")))
sys.exit(0 if t(sys.argv[1]) > t(sys.argv[2]) else 1)' "$1" "$2"
}

# 아카이브의 앱 번들과 메타데이터(Organizer가 목록에 보여주는 값)가 소스와 같은지 본다.
# 빌드 설정이 Info.plist를 덮어쓰거나, 예전 아카이브가 남아 있으면 여기서 갈린다.
verify_archive() {
  local app="$ARCHIVE/Products/Applications/Sweep.app"
  [ -d "$app" ] || fail "아카이브에 앱이 없다: $app"

  local entry label plist prefix v b
  for entry in "앱 번들|$app/Contents/Info.plist|" \
               "아카이브|$ARCHIVE/Info.plist|ApplicationProperties:"; do
    IFS='|' read -r label plist prefix <<< "$entry"
    v=$(/usr/libexec/PlistBuddy -c "Print :${prefix}CFBundleShortVersionString" "$plist" 2>/dev/null || echo "?")
    b=$(/usr/libexec/PlistBuddy -c "Print :${prefix}CFBundleVersion" "$plist" 2>/dev/null || echo "?")
    [ "$v" = "$VERSION" ] && [ "$b" = "$BUILD" ] \
      || fail "$label 버전이 소스와 다르다: $v ($b) ≠ 소스 $VERSION ($BUILD) — $ARCHIVE"
  done
  echo "  OK   결과물 버전 $VERSION ($BUILD) — 소스와 같음"
}

if [ "$MODE" = "--verify-only" ]; then
  echo "── 결과물 검사 ──"
  verify_archive
  exit 0
fi

echo "── 버전 검사 ──"

# App Store Connect가 받는 형식: 점으로 나눈 정수 1~3개. "1.0.0-beta"나 "2a"는 업로드에서 막힌다.
is_version() { [[ "$1" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; }
is_version "$VERSION" \
  || fail "CFBundleShortVersionString '$VERSION' — 정수 1~3개를 점으로 이은 형식이어야 한다 (예: 1.0.1)"
is_version "$BUILD" \
  || fail "CFBundleVersion '$BUILD' — 정수 1~3개를 점으로 이은 형식이어야 한다 (예: 3)"

# Organizer 업로드 기록에서 이 번들의 업로드 성공 건을 모은다.
# 아카이브의 CFBundleVersion이 아니라 uploadedBuildNumber를 본다 —
# Organizer가 번호를 자동으로 올려서 올리면 둘이 다르다(실제로 1 → 2였다).
UPLOADED=$(python3 - "$ORGANIZER_ARCHIVES" "$BUNDLE_ID" <<'PY'
import glob, plistlib, re, sys
root, bundle = sys.argv[1], sys.argv[2]
for path in glob.glob(f"{root}/*/*.xcarchive/Info.plist"):
    try:
        info = plistlib.load(open(path, "rb"))
    except Exception:
        continue
    app = info.get("ApplicationProperties", {})
    if app.get("CFBundleIdentifier") != bundle:
        continue
    for d in info.get("Distributions", []):
        event = d.get("uploadEvent", {})
        if d.get("destination") != "upload" or event.get("state") != "success":
            continue
        number = str(d.get("uploadedBuildNumber") or app.get("CFBundleVersion", ""))
        # 기록에 따라 날짜가 문자열이기도, plist date이기도 하다. 같은 모양으로 맞춘다.
        date = event.get("date", "")
        if hasattr(date, "strftime"):
            date = date.strftime("%Y-%m-%dT%H:%M:%SZ")
        if re.fullmatch(r"\d+(\.\d+){0,2}", number):
            print(number, date)
PY
)

HIGHEST=""; HIGHEST_DATE=""
while read -r number date; do
  [ -z "$number" ] && continue
  if [ -z "$HIGHEST" ] || version_gt "$number" "$HIGHEST"; then
    HIGHEST=$number; HIGHEST_DATE=$date
  fi
done <<< "$UPLOADED"

if [ -n "$HIGHEST" ] && ! version_gt "$BUILD" "$HIGHEST"; then
  NEXT=$(( ${HIGHEST%%.*} + 1 ))
  # 고치는 법으로 PlistBuddy Set을 권하지 않는다 — 파일을 다시 써서 주석을 지우고
  # 키 순서를 바꾼다(실제로 43줄이 바뀌었다). 값 한 줄만 바꾼다.
  fail "빌드 ${BUILD} — 이미 빌드 ${HIGHEST}까지 올라갔다 (${HIGHEST_DATE}).
       Mac 앱은 이전에 올린 빌드보다 큰 번호여야 한다. 올리고 다시 돌린다:
         sed -i '' '/<key>CFBundleVersion<\/key>/{n;s|<string>[^<]*</string>|<string>${NEXT}</string>|;}' ${PLIST}"
fi
echo "  OK   버전 $VERSION 빌드 $BUILD (올라간 최고 빌드: ${HIGHEST:-없음})"

[ "$MODE" = "--check-only" ] && exit 0

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

echo
echo "── 검증 ──"
verify_archive

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
echo "      Distribute App의 'Manage Version and Build Number'는 끈다 — 켜 두면 Organizer가"
echo "      번호를 바꿔 올려 소스와 어긋난다. 번호는 이 스크립트가 이미 확인했다."
