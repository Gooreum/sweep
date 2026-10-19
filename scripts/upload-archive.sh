#!/bin/bash
#
# `make-archive.sh`가 만든 아카이브를 App Store Connect에 올린다.
# Organizer의 Distribute App → App Store Connect → Upload와 같은 일이다.
#
#   bash scripts/upload-archive.sh
#
# 로컬에서는 Xcode에 로그인된 계정으로 서명한다. CI처럼 계정이 없으면 API 키를 준다 —
# 그 키로 배포 인증서·프로파일을 받는다(클라우드 서명, 키 권한이 관리자여야 한다):
#
#   ASC_KEY_ID=<키 ID> ASC_ISSUER_ID=<Issuer ID> ASC_KEY_PATH=<AuthKey_*.p8> bash scripts/upload-archive.sh
#
# DESTINATION=export면 올리지 않고 서명된 .pkg만 만든다 — 서명이 되는지만 볼 때.
#
# 업로드 후 App Store Connect가 처리를 마쳐야 빌드가 보인다. 심사 제출은 사람이 한다.
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHIVE="${ARCHIVE:-dist/Sweep.xcarchive}"
EXPORT="${EXPORT:-build/export}"
[ -d "$ARCHIVE" ] || { echo "아카이브가 없다: $ARCHIVE — 먼저 bash scripts/make-archive.sh" >&2; exit 1; }

AUTH=()
if [ -n "${ASC_KEY_PATH:-}" ]; then
  AUTH=(-authenticationKeyPath "$ASC_KEY_PATH"
        -authenticationKeyID "${ASC_KEY_ID:?ASC_KEY_ID}"
        -authenticationKeyIssuerID "${ASC_ISSUER_ID:?ASC_ISSUER_ID}")
fi

bash scripts/make-archive.sh --verify-only

echo "── 내보내기 (${DESTINATION:-upload}) ──"
rm -rf "$EXPORT"
OPTIONS=scripts/ExportOptions.plist
if [ "${DESTINATION:-upload}" != upload ]; then
  OPTIONS="$(mktemp -d)/ExportOptions.plist"
  cp scripts/ExportOptions.plist "$OPTIONS"
  plutil -replace destination -string "$DESTINATION" "$OPTIONS"
fi

LOG="$EXPORT.log"
mkdir -p "$(dirname "$LOG")"
if ! xcodebuild -exportArchive -archivePath "$ARCHIVE" \
     -exportOptionsPlist "$OPTIONS" -exportPath "$EXPORT" \
     -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"} > "$LOG" 2>&1; then
  tail -30 "$LOG" >&2
  echo "업로드 실패 — 전체 로그: $LOG" >&2
  exit 1
fi
grep -E "Upload succeeded|EXPORT SUCCEEDED" "$LOG"
