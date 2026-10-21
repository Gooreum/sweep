# 버전을 올리면 빌드 번호를 1부터 다시 시작한다

## Context
지금 릴리스 규칙은 "빌드 번호는 늘 현재 값 + 1이고, 버전을 올려도 1로 되돌리지 않는다"예요. 그래서 1.0.3(9) 다음이 1.0.4(10)이 됐어요. 사용자 요구는 **버전을 올리면 빌드는 (1)**이에요. 같은 버전을 다시 올릴 때만 +1이에요.
이 규칙은 스킬 문서 두 곳, 문서 하나, 메모리, 그리고 스크립트 두 개에 박혀 있어요. 문서만 고치면 아래 두 곳이 1.0.5(1)을 막거나 놓쳐요.
- `scripts/release-diff.sh`: 빌드 번호만 비교해요. 1.0.5(1) → 1.0.6(1)이면 번호가 같아 `build=false`가 되고, **업로드를 건너뛰어요**.
- `scripts/make-archive.sh`: Organizer 업로드 기록의 최고 빌드(버전 무관)보다 커야 통과해요. 1.0.5(1)은 "이미 빌드 10까지 올라갔다"로 **멈춰요**.

## 변경

### 1. `scripts/release-diff.sh` (Sweep) — 버전·빌드 쌍으로 비교
```bash
# Before
old_build=$(read_key "$BASE" CFBundleVersion)
new_build=$(read_key "$HEAD" CFBundleVersion)
echo "build=$([ "$old_build" != "$new_build" ] && echo true || echo false)"
# After
old_release="$(read_key "$BASE" CFBundleShortVersionString) $(read_key "$BASE" CFBundleVersion)"
new_version=$(read_key "$HEAD" CFBundleShortVersionString)
new_build=$(read_key "$HEAD" CFBundleVersion)
echo "build=$([ "$old_release" != "$new_version $new_build" ] && echo true || echo false)"
```
위 주석도 바꿔요: "버전을 올리면 빌드는 1부터, 같은 버전이면 빌드를 올린다. 둘 중 하나라도 바뀌면 새 업로드다."

### 2. `scripts/make-archive.sh` — 같은 버전 안에서만 번호 비교
- Python 블록이 `number date`를 출력하던 것을 `version number date`로 바꿔요. 버전은 `app.get("CFBundleShortVersionString")`에서 읽어요.
- `while read -r version number date`에서 `version != $VERSION`이면 건너뛰어요. 그 결과 `HIGHEST`는 "이 버전으로 올린 최고 빌드"가 돼요.
- 멈춤 문구는 "버전 ${VERSION}으로 이미 빌드 ${HIGHEST}까지 올라갔다. 같은 버전이면 빌드 번호를 올린다"로 바꿔요.
- OK 문구는 `(이 버전으로 올라간 최고 빌드: …)`로 바꿔요.

### 3. 범용 스킬 `~/.claude/skills/app-store-release/scripts/release-diff.sh` — 같은 수정
```bash
# Before
read -r _ old_build < <(bash "$HERE/version.sh" get "$BASE" 2>/dev/null || echo "? ?")
echo "build=$([ "$old_build" != "$new_build" ] && echo true || echo false)"
# After
old_release=$(bash "$HERE/version.sh" get "$BASE" 2>/dev/null || echo "? ?")
echo "build=$([ "$old_release" != "$new_version $new_build" ] && echo true || echo false)"
```

### 4. 문서
- `.claude/skills/sweep-release/SKILL.md` §3 버전: "빌드 번호는 묻지 않는다. **버전을 올리면 1**, 같은 버전을 다시 올리면 현재 값 + 1"로 바꿔요. 1.0.2 거부 문구는 지워요.
- `~/.claude/skills/app-store-release/SKILL.md` §3: 같은 문구로 바꿔요.
- `docs/APPSTORE.md` 111행 인용: "같은 버전 안에서 같은 빌드 번호는 두 번 못 올린다. 버전을 올리면 1부터 시작한다"로 바꿔요.
- 메모리 `version-bump-patch.md`: "1로 되돌리지 않는다"를 "버전을 올리면 빌드 1"로 고쳐요. 사용자가 여러 번 배포해 본 경험으로 정한 규칙이라고 적어요.

## 개발 Phase 계획

### Phase 1: 스크립트
**목표**: 1.0.5(1) 같은 릴리스를 스크립트가 막지도 놓치지도 않는다.
- Step 1: `release-diff.sh` 두 개(Sweep, 범용)를 버전·빌드 쌍으로 비교 — 임시 커밋 두 개 사이에서 1.0.5(1) → 1.0.6(1)이 `build=true`
- Step 2: `make-archive.sh`를 같은 버전 안에서만 비교 — 1.0.5(1)로 `--check-only`가 OK

### Phase 2: 문서·메모리
**목표**: 릴리스 스킬이 다음부터 버전을 올리면 빌드 1을 쓴다.
- Step 1: Sweep 스킬, 범용 스킬, `docs/APPSTORE.md`, 메모리 갱신 — grep으로 "1로 되돌리지" 0건

## 검증
- `bash scripts/release-diff.sh <1.0.4(10) 커밋> <임시 1.0.5(1) 작업 트리 커밋>` → `build=true`. 같은 버전·같은 빌드면 `false`.
  임시 커밋은 `git stash`/브랜치를 쓰지 않고 `git commit-tree`로 만든 떨어진 커밋을 써요. main은 건드리지 않아요.
- `PLIST=<임시 plist(1.0.5/1)> bash scripts/make-archive.sh --check-only` → OK. `PLIST=<1.0.4/1>`이면 Organizer에 1.0.4 기록이 있을 때만 멈춰요.
- 범용 `release-diff.sh`: 같은 방식으로 확인해요.
- `grep -rn "1로 되돌리지"` → 0건

## E2E 영향
- 자동 테스트 없음. 스크립트를 직접 실행해서 확인해요.
- 지금 심사 중인 1.0.4(10)은 건드리지 않아요. 새 규칙은 다음 버전부터 적용해요.
- 커밋: Sweep 저장소(스크립트·문서), Gooreum/app-store-release(범용 스킬) 각각 푸시해요.
