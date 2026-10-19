#!/bin/bash
#
# 두 커밋 사이에 App Store로 올릴 것이 바뀌었는지 판정한다. GitHub Actions가 출력을
# 그대로 `$GITHUB_OUTPUT`에 붙인다.
#
#   bash scripts/release-diff.sh <이전 커밋> <새 커밋>
#
#   build=true|false        CFBundleVersion이 바뀌었다 → 아카이브·업로드
#   metadata=true|false     fastlane/metadata가 바뀌었다 → 앱 정보 반영
#   screenshots=true|false  fastlane/screenshots가 바뀌었다 → 스크린샷 교체
#   version=, build_number= 새 커밋의 버전 (태그 이름에 쓴다)
#
# 빌드 번호를 기준으로 삼는다. 릴리스 스킬은 버전을 바꾸든 안 바꾸든 빌드 번호를 늘
# 올리고, App Store Connect는 같은 번호를 두 번 받지 않는다.
set -euo pipefail
cd "$(dirname "$0")/.."

BASE="${1:?이전 커밋}"
HEAD="${2:?새 커밋}"
PLIST="Sources/SweepApp/Info.plist"

# 파일 내용에서 키 바로 다음 <string> 값을 읽는다. 커밋 안의 파일이라 PlistBuddy를 못 쓴다.
read_key() {
  git show "$1:$PLIST" 2>/dev/null \
    | awk -v key="<key>$2</key>" 'found { gsub(/.*<string>|<\/string>.*/, ""); print; exit } index($0, key) { found = 1 }'
}

changed() { git diff --quiet "$BASE" "$HEAD" -- "$1" && echo false || echo true; }

old_build=$(read_key "$BASE" CFBundleVersion)
new_build=$(read_key "$HEAD" CFBundleVersion)
[ -n "$new_build" ] || { echo "새 커밋에서 CFBundleVersion을 읽지 못했다: $HEAD" >&2; exit 1; }

echo "build=$([ "$old_build" != "$new_build" ] && echo true || echo false)"
echo "metadata=$(changed fastlane/metadata)"
echo "screenshots=$(changed fastlane/screenshots)"
echo "version=$(read_key "$HEAD" CFBundleShortVersionString)"
echo "build_number=$new_build"
