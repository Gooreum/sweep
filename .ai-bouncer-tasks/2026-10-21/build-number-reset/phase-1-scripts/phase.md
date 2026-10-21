## 목표
1.0.5(1) 같은 릴리스를 스크립트가 막지도 놓치지도 않는다.

## 기술 접근
- `scripts/release-diff.sh`: 빌드 번호만 비교 → 버전·빌드 쌍 비교
- `scripts/make-archive.sh`: 버전 무관 최고 빌드와 비교 → 같은 버전 안에서만 비교
- `~/.claude/skills/app-store-release/scripts/release-diff.sh`: Sweep과 같은 수정

## Steps
- Step 1: release-diff.sh 두 개 수정 — 1.0.5(1)→1.0.6(1)이 build=true
- Step 2: make-archive.sh 수정 — 1.0.5(1) --check-only OK
