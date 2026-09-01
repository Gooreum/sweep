#!/bin/bash
#
# `dist/Sweep.app`에 Developer ID 서명을 붙인다.
#
# 공증(notarization)은 Hardened Runtime으로 서명된 것만 받는다.
# 엔타이틀먼트는 넣지 않는다 — 이 앱은 JIT도, 서명 안 된 라이브러리 로드도,
# DYLD 주입도 하지 않는다. 엔타이틀먼트는 Hardened Runtime을 *푸는* 물건이라
# 필요 없는 것을 넣으면 공격면만 넓어진다.
#
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

APP="dist/Sweep.app"

if [ ! -d "$APP" ]; then
  echo "FAIL: $APP 이 없다. 먼저: bash scripts/make-app.sh"
  exit 1
fi

# 인증서가 없으면 **여기서 멈춘다.** ad-hoc으로 대체하지 않는다 —
# 조용히 서명되면 다른 Mac에서 열어 보고 나서야 막힌 것을 안다.
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
           | grep "Developer ID Application" | head -1 \
           | sed 's/.*"\(.*\)"/\1/')

if [ -z "$IDENTITY" ]; then
  echo "FAIL: Developer ID Application 인증서가 키체인에 없습니다."
  echo
  echo "  지금 있는 것:"
  security find-identity -v -p codesigning 2>/dev/null | sed 's/^/  /'
  echo
  echo "  Apple Development·Apple Distribution으로는 공증을 받을 수 없습니다."
  echo "  developer.apple.com → Certificates, IDs & Profiles → Certificates → +"
  echo "  → Developer ID Application 을 만들어 내려받은 .cer를 더블클릭하세요."
  exit 1
fi

echo "서명 주체: $IDENTITY"
codesign --force --timestamp --options runtime --sign "$IDENTITY" "$APP" || exit 1

echo
echo "── 검증 ──"
fail=0
if codesign --verify --strict --verbose=2 "$APP" 2>&1 | sed 's/^/  /'; then
  echo "  OK   codesign --verify --strict"
else
  echo "  FAIL codesign --verify --strict"
  fail=$((fail + 1))
fi

# `flags`에 runtime이 없으면 공증이 거부된다. 서명 자체는 성공해도 그렇다.
INFO=$(codesign -dv --verbose=4 "$APP" 2>&1)
echo "$INFO" | grep -E "^Authority|^TeamIdentifier|^Timestamp|flags=" | sed 's/^/  /'
# `| grep -q`를 쓰지 않는다 — grep이 매치 즉시 파이프를 닫아 앞 명령이
# SIGPIPE(141)로 죽고, `pipefail`이 그것을 결과로 삼아 조건이 거짓이 된다.
case "$INFO" in
  *"flags="*"runtime"*) HAS_RUNTIME=1 ;;
  *) HAS_RUNTIME=0 ;;
esac
if [ "$HAS_RUNTIME" -eq 1 ]; then
  echo "  OK   Hardened Runtime"
else
  echo "  FAIL Hardened Runtime 플래그가 없다 — 공증이 거부된다"
  fail=$((fail + 1))
fi

echo
[ "$fail" -eq 0 ] || exit 1
echo "서명 완료: $APP"
