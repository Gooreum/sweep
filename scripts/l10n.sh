#!/bin/bash
#
# 화면 문자열 현지화 도구. 키는 지금의 한국어 문장이고, 영어 번역만
# `Resources/Localizable.xcstrings`에 둔다.
#
#   extract        소스에서 키를 뽑아 카탈로그에 맞춘다
#   check          영어 번역이 빠졌거나 소스에서 사라진 키가 있으면 실패한다
#   compile <dir>  카탈로그를 `<dir>/<언어>.lproj`로 컴파일한다
#
# 키를 손으로 적지 않는다. `"\(days)일 전"`은 컴파일러가 `%lld일 전`으로 바꾸는데,
# 손으로 쓰면 %lld와 %@가 어긋나 번역이 조용히 무시된다.
#
set -euo pipefail
cd "$(dirname "$0")/.."

CATALOG="Resources/Localizable.xcstrings"
OUT=".build/l10n"
# 별도 빌드 경로를 쓴다. 플래그가 달라 같은 경로면 평소 빌드가 매번 전부 다시 컴파일된다.
SCRATCH=".build/l10n-build"
# 화면 확인용 가짜 데이터다. 번역 대상이 아니다.
DEMO_SOURCES="StageHarness|StoreDemo"

extract() {
  # 지우지 않는다. 증분 빌드는 바뀐 파일만 다시 컴파일해서, 지우면 나머지 파일의
  # .stringsdata가 다시 생기지 않는다. 대신 소스가 사라진 것은 아래에서 거른다.
  mkdir -p "$OUT"
  # 추출물이 없는데 빌드가 최신이면 아무것도 다시 나오지 않는다. 처음부터 빌드한다.
  compgen -G "$OUT/*.stringsdata" > /dev/null || rm -rf "$SCRATCH"
  swift build --scratch-path "$SCRATCH" \
    -Xswiftc -emit-localized-strings \
    -Xswiftc -emit-localized-strings-path -Xswiftc "$OUT" >&2
  local data=()
  while IFS= read -r f; do data+=(--stringsdata "$f"); done < <(python3 - "$OUT" "$DEMO_SOURCES" <<'PY'
import glob, json, os, re, sys
out, demo = sys.argv[1], re.compile(rf"/({sys.argv[2]})\.swift$")
for f in sorted(glob.glob(f"{out}/*.stringsdata")):
    source = json.load(open(f))["source"]
    if os.path.exists(source) and not demo.search(source):
        print(f)
PY
)
  [ ${#data[@]} -gt 0 ] || { echo "추출된 문자열이 없다" >&2; exit 1; }
  [ -f "$CATALOG" ] || echo '{"sourceLanguage":"ko","strings":{},"version":"1.0"}' > "$CATALOG"
  xcrun xcstringstool sync "$CATALOG" "${data[@]}"
}

check() {
  extract
  python3 - "$CATALOG" <<'PY'
import json, sys
strings = json.load(open(sys.argv[1]))["strings"]
def translated(entry):
    en = entry.get("localizations", {}).get("en", {})
    if "variations" in en:
        return all(v["stringUnit"].get("state") == "translated"
                   for forms in en["variations"].values() for v in forms.values())
    return en.get("stringUnit", {}).get("state") == "translated"
stale = [k for k, e in strings.items() if e.get("extractionState") == "stale"]
missing = [k for k, e in strings.items()
           if k not in stale and e.get("shouldTranslate", True) and not translated(e)]
for k in missing: print(f"번역 없음: {k}")
for k in stale: print(f"소스에 없음: {k}")
print(f"키 {len(strings)}개 · 번역 없음 {len(missing)}개 · 소스에 없음 {len(stale)}개")
sys.exit(1 if missing or stale else 0)
PY
}

compile() {
  local dir="${1:?compile <dir>}"
  mkdir -p "$dir"
  xcrun xcstringstool compile "$CATALOG" --output-directory "$dir"
  # 권한 요청 문구. Info.plist 기본값은 영어이고 한국어는 ko.lproj에 있다.
  for lproj in Resources/*.lproj; do
    [ -d "$lproj" ] || continue
    mkdir -p "$dir/$(basename "$lproj")"
    cp "$lproj"/* "$dir/$(basename "$lproj")/"
  done
}

case "${1:-}" in
  extract) extract ;;
  check) check ;;
  compile) compile "${2:-}" ;;
  *) echo "사용법: l10n.sh {extract|check|compile <dir>}" >&2; exit 2 ;;
esac
