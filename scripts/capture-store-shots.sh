#!/bin/bash
#
# App Store 스크린샷용 창 캡처 원본을 찍는다. 합성은 `scripts/store-compose.py`(Codex 아트디렉션).
#
#   bash scripts/capture-store-shots.sh                       6장면 전부, ko·en
#   bash scripts/capture-store-shots.sh store-summary store-xcode   고른 장면만
#
# 결과: .build/store-captures/{ko,en}/<장면>.png — 창 1100×688 @2x = 2200×1376, 그림자 없음.
#
# 주의 (실측):
# - Stage Manager가 켜져 있으면 포커스 없는 창은 썸네일로 찍힌다. `open -n`으로 앞에 띄운다.
#   캡처하는 동안 Sweep 창이 잠깐씩 앞으로 나온다.
# - 창 크기는 저장된 프레임(`NSWindow Frame main`)과 창 복원을 따른다. 실행 인자로 덮어써서
#   사용자 설정은 건드리지 않는다.
# - 사용자의 Sweep(/Applications)이 떠 있을 수 있다. 창은 우리가 띄운 PID로만 고른다.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="${APP:-dist/Sweep.app}"
OUT="${OUT:-.build/store-captures}"
ALL=(store-summary store-cpu store-xcode store-projects store-large store-duplicate store-diskmap store-cleaned)
STAGES=("$@"); [ ${#STAGES[@]} -eq 0 ] && STAGES=("${ALL[@]}")

for s in "${STAGES[@]}"; do
  [[ " ${ALL[*]} " == *" $s "* ]] || { echo "모르는 장면: $s — 가능한 장면: ${ALL[*]}" >&2; exit 1; }
done
[ -d "$APP" ] || { echo "앱이 없다: $APP — 먼저 bash scripts/make-app.sh" >&2; exit 1; }

# PID의 일반 창 id와 크기. 창 목록은 CoreGraphics에서만 볼 수 있다.
WINID="$(mktemp -d)/winid"
cat > "$WINID.swift" <<'SWIFT'
import CoreGraphics
let pid = Int32(CommandLine.arguments[1])!
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in list where (w[kCGWindowOwnerPID as String] as? Int32) == pid && (w[kCGWindowLayer as String] as? Int) == 0 {
    let b = w[kCGWindowBounds as String] as! [String: Any]
    print(w[kCGWindowNumber as String]!, b["Width"]!, b["Height"]!)
}
SWIFT
swiftc -O "$WINID.swift" -o "$WINID" 2>/dev/null

for lang in ko en; do
  mkdir -p "$OUT/$lang"
  for stage in "${STAGES[@]}"; do
    before=$(pgrep -x Sweep | sort || true)
    open -n "$APP" --args --stage "$stage" -AppleLanguages "($lang)" \
      -ApplePersistenceIgnoreState YES "-NSWindow Frame main" "209 90 1100 688 0 0 1680 1020 "
    pid=""
    for _ in $(seq 1 40); do
      pid=$(comm -13 <(echo "$before") <(pgrep -x Sweep | sort) | head -1)
      [ -n "$pid" ] && break; sleep 0.25
    done
    [ -n "$pid" ] || { echo "앱이 뜨지 않았다: $stage $lang" >&2; exit 1; }
    win=""
    for _ in $(seq 1 40); do
      win=$("$WINID" "$pid" | head -1); [ -n "$win" ] && break; sleep 0.25
    done
    sleep 3   # 데모 데이터가 다 그려질 때까지
    # CPU는 2초 주기를 두 번 돌아야 표가 찬다. 처음 측정은 '측정 중…'이다.
    [ "$stage" = store-cpu ] && sleep 5
    win=$("$WINID" "$pid" | head -1)
    screencapture -x -o -l "${win%% *}" "$OUT/$lang/$stage.png"
    kill "$pid"; sleep 0.5
    size=$(sips -g pixelWidth -g pixelHeight "$OUT/$lang/$stage.png" | awk '/pixel/ {printf "%s%s", sep, $2; sep="×"}')
    echo "$lang $stage $size"
    [ "$size" = "2200×1376" ] || { echo "크기가 다르다 — 창 ${win#* }" >&2; exit 1; }
  done
done
