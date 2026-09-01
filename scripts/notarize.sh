#!/bin/bash
#
# 서명된 `dist/Sweep.app`을 Apple에 공증 제출하고, 티켓을 박아 배포 ZIP을 만든다.
#
# 공증을 받아야 다른 Mac에서 "확인되지 않은 개발자" 경고 없이 열린다.
# staple까지 해야 인터넷이 없는 환경에서도 Gatekeeper가 통과시킨다.
#
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

APP="dist/Sweep.app"
PLIST="Sources/SweepApp/Info.plist"
PROFILE="sweep"

if [ ! -d "$APP" ]; then
  echo "FAIL: $APP 이 없다. 먼저: bash scripts/make-app.sh && bash scripts/sign-app.sh"
  exit 1
fi

# ad-hoc 서명은 공증이 거부한다. 제출하기 전에 잡는다 —
# 제출은 몇 분이 걸리므로 여기서 걸러야 시간을 버리지 않는다.
# `... | grep -q` 는 쓰지 않는다. grep이 매치 즉시 파이프를 닫아 codesign이
# SIGPIPE(141)로 죽고, `pipefail`이 그 141을 파이프라인 결과로 삼아 **조건이
# 거짓이 된다.** 실제로 이 가드가 그렇게 무력화돼 있었다.
SIGN_INFO=$(codesign -dv "$APP" 2>&1)
case "$SIGN_INFO" in *"Signature=adhoc"*) IS_ADHOC=1 ;; *) IS_ADHOC=0 ;; esac
if [ "$IS_ADHOC" -eq 1 ]; then
  echo "FAIL: ad-hoc 서명 상태다. 공증은 Developer ID 서명만 받는다."
  echo "  bash scripts/sign-app.sh 를 먼저 통과시켜야 한다."
  exit 1
fi

if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
  echo "FAIL: 공증 자격 프로필 '$PROFILE'이 없습니다. 한 번만 등록하면 됩니다:"
  echo
  echo "  xcrun notarytool store-credentials $PROFILE \\"
  echo "    --apple-id <Apple ID> \\"
  echo "    --team-id <Team ID> \\"
  echo "    --password <앱 전용 암호>"
  echo
  echo "  · Team ID는 developer.apple.com → Membership 에서 봅니다."
  echo "  · 앱 전용 암호는 appleid.apple.com → 로그인 및 보안 → 앱 암호 에서 만듭니다."
  echo "    (Apple ID 본 암호가 아닙니다)"
  exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
ZIP="dist/Sweep-$VERSION.zip"

# `notarytool`은 `.app` 디렉터리를 그대로 받지 못한다.
# `zip` 명령은 심볼릭 링크와 확장 속성을 잃어 **서명이 깨진다** — `ditto`라야 한다.
echo "── 압축 ──"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP" || exit 1
echo "  $ZIP"

echo "── 제출 (몇 분 걸린다) ──"
if ! xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait; then
  echo
  echo "FAIL: 공증이 거부됐다. 사유를 보려면:"
  echo "  xcrun notarytool log <submission-id> --keychain-profile $PROFILE"
  exit 1
fi

# 티켓을 앱에 박는다. 이걸 해야 오프라인에서도 Gatekeeper가 통과시킨다.
echo "── staple ──"
xcrun stapler staple "$APP" || exit 1
xcrun stapler validate "$APP" || exit 1

# staple된 앱으로 다시 감싼다. 앞서 제출한 ZIP에는 티켓이 없다.
echo "── 배포본 재압축 ──"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP" || exit 1

echo "── 받는 사람 시점 확인 ──"
spctl -a -vv -t install "$APP" 2>&1 | sed 's/^/  /'

echo
echo "배포본: $ZIP"
