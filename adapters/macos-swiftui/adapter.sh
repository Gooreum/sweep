#!/bin/bash
# design-bounce macOS SwiftUI 어댑터.
#
# SwiftUI 씬은 런타임 딥링크 라우팅이 없다. 대신 이 앱이 이미 갖고 있는
# `--stage <id>` 하니스로 화면 단계를 재현한다 — `navigate`가 그 인자로 재기동한다.
set -uo pipefail

CFG="${DESIGN_BOUNCE_CONFIG:-design-bounce.config.json}"
BIN=".build/debug/SweepApp"
PROC_PATTERN='\.build/debug/SweepApp'

cfg() { python3 -c "import json,sys; print(json.load(open('$CFG'))$1)" 2>/dev/null; }

capture_dir() { cfg "['captureDir']" || echo ".design-bounce/shots"; }
deeplink()    { cfg "['screens']['$1']['deeplink']"; }
settle_ms()   { cfg "['screens']['$1'].get('settleMs', 0)" || echo 0; }

dry() { [ "${2:-}" = "--dry-run" ] || [ "${3:-}" = "--dry-run" ]; }

kill_app() {
  pkill -f "$PROC_PATTERN" 2>/dev/null || true
  python3 -c "import time; time.sleep(1)"
}

# 앱을 앞으로 부른다. 창은 활성화 전에는 CGWindowList에서 onscreen=false로 나오고
# AX에서도 잡히지 않는다 — 캡처 전에 반드시 필요하다.
activate() {
  for name in Sweep SweepApp; do
    if osascript -e "tell application \"System Events\" to set frontmost of process \"$name\" to true" \
       >/dev/null 2>&1; then
      PROC_NAME="$name"; return 0
    fi
  done
  return 1
}

# 본 창의 CGWindowID. 영역 캡처는 그 자리에 뜬 알림 배너까지 찍히므로
# 창 단위로 캡처한다. 헬퍼는 처음 한 번만 컴파일해 캐시한다.
# 창이 실제로 잡힐 때까지 기다린다. 고정 sleep은 기계·부하에 따라 모자란다 —
# 실측에서 4.5초로는 실패하고 8초면 됐다. 시간이 아니라 **상태**를 기다린다.
wait_for_window() {
  local deadline=$((SECONDS + 20))
  while [ "$SECONDS" -lt "$deadline" ]; do
    activate 2>/dev/null
    local id
    id=$(window_id 2>/dev/null) && [ -n "$id" ] && { echo "$id"; return 0; }
    python3 -c "import time; time.sleep(0.5)"
  done
  return 1
}

HELPER_SRC="$(dirname "$0")/helper/winid.swift"
HELPER_BIN=".design-bounce/bin/winid"

window_id() {
  if [ ! -x "$HELPER_BIN" ] || [ "$HELPER_SRC" -nt "$HELPER_BIN" ]; then
    mkdir -p "$(dirname "$HELPER_BIN")"
    swiftc -O -o "$HELPER_BIN" "$HELPER_SRC" >&2 || return 1
  fi
  "$HELPER_BIN"
}

case "${1:-}" in
  build)
    if dry "$@"; then echo "swift build"; exit 0; fi
    swift build >&2 || exit 1
    echo OK
    ;;

  launch)
    if dry "$@"; then echo "$BIN &"; exit 0; fi
    kill_app
    "$BIN" >/dev/null 2>&1 &
    wait_for_window >/dev/null || { echo "창이 뜨지 않았다" >&2; exit 1; }
    echo OK
    ;;

  navigate)
    SCREEN="${2:?screen_id 필요}"
    LINK=$(deeplink "$SCREEN") || { echo "알 수 없는 화면: $SCREEN" >&2; exit 1; }
    if dry "$@"; then echo "$BIN $LINK &"; exit 0; fi
    kill_app
    # shellcheck disable=SC2086
    "$BIN" $LINK >/dev/null 2>&1 &
    wait_for_window >/dev/null || { echo "창이 뜨지 않았다: $SCREEN" >&2; exit 1; }
    echo OK
    ;;

  capture)
    SCREEN="${2:?screen_id 필요}"
    DIR=$(capture_dir); MS=$(settle_ms "$SCREEN")
    OUT="$DIR/$SCREEN.png"
    if dry "$@"; then echo "SLEEP ${MS}ms; screencapture -x -o -l <windowid> \"$OUT\""; exit 0; fi
    mkdir -p "$DIR"
    WID=$(wait_for_window) || { echo "창을 찾을 수 없다" >&2; exit 1; }
    # 창이 뜬 뒤에도 애니메이션이 남아 있다. settleMs만큼 더 기다린다.
    python3 -c "import time; time.sleep($MS/1000)"
    rm -f "$OUT"
    # -o: 창 그림자 제외. 판정에 그림자는 잡음이다.
    screencapture -x -o -l "$WID" "$OUT" 2>/dev/null
    [ -s "$OUT" ] || { echo "캡처 실패 (window $WID)" >&2; exit 1; }
    echo "$OUT"
    ;;

  *)
    echo "사용법: adapter.sh {build|launch|navigate <id>|capture <id>} [--dry-run]" >&2
    exit 2
    ;;
esac
