# PR #22 수정: 완료 화면을 띄운 탭에도 되돌린 항목을 돌려준다

## Context
PR #22(이슈 #14, 브랜치 `fix/issue-14`)의 자동 리뷰에 🔴 지적이 1건 있어요. `ScanModel.reinstate`가 `guard phase == .results`라서, 완료 화면(`.cleaned`/`.restored`)을 띄운 탭은 건너뛰어요. 짝인 `forget`은 phase와 상관없이 `items`에서 빼고, 사이드바 배지(`AppModel.badges`)는 phase와 상관없이 `smartScan.items`로 계산해요.
재현: 한번에 찾기에서 정리 → 정리할 파일 탭에서 다른 항목 정리 → 정리할 파일 탭에서 되돌림 → 한번에 찾기 목록과 배지에 그 항목이 안 돌아와요. 이슈 #14가 고치려던 증상이 그대로 남아요.
`items`에 넣는 것만으로는 완료 화면이 덮이지 않아요. 화면은 `phase`/`report`가 정하고, `undoLastCleanup`도 `.cleaned`에서 `items`에 append해요.

## 변경

### `Sources/SweepKit/Presentation/ScanModel.swift` (`reinstate`)
```swift
// Before
        removedDuringScan.subtract(restored.map(\.url))
        guard phase == .results else { return }
// After
        removedDuringScan.subtract(restored.map(\.url))
        // 목록이 없는 시작 화면과, 다음 스냅샷이 실어 올 스캔 중만 건너뛴다.
        // 완료 화면은 phase·report가 그리므로 items에 넣어도 덮이지 않는다.
        switch phase {
        case .idle, .scanning: return
        case .results, .cleaned, .restored: break
        }
```
doc 주석의 "결과 목록을 띄운 탭만 받는다 … 완료 화면을 띄운 탭은 덮으면 안 된다"도 위 설명으로 바꿔요.

### `Tests/SweepKitTests/AppModelTests.swift`
- `undoSkipsTabShowingOutcome`: 이름을 `undoKeepsOutcomeScreen`으로 바꿔요. 기존 단언(`big.phase == .cleaned`, `big.canUndo`)은 유지해요. 추가로 `target`이 큰 파일 몫이 아니면(`Feature.largeFile.items(from: [target]).isEmpty`) `big.items`에 끼어들지 않았는지 확인해요.
- 새 테스트 `undoReachesSmartScanShowingOutcome`을 추가해요.
  1. 한번에 찾기 스캔 → 항목 하나 정리 → `smart.phase == .cleaned`
  2. 정리할 파일 탭에서 다른 항목 `target` 정리 → `smart.items`에서 빠짐, 배지 값 기록
  3. 정리할 파일 탭 `undoLastCleanup()` → `smart.items`에 `target`이 돌아오고, `smart.phase == .cleaned`가 유지되고, `app.badges[.junk]`가 정리 전 값과 같아요.

## 개발 Phase 계획

### Phase 1: 수정
**목표**: 완료 화면 탭도 되돌린 항목을 받는다. 화면은 그대로다.
- Step 1: `fix/issue-14` 체크아웃 후 `reinstate` 수정 + 테스트 2개 — `swift test --filter AppModelTests` 통과, 전체 `swift test` 통과

## 검증
- `swift test --filter AppModelTests` → 새 테스트를 포함해 전부 통과
- `swift test` → 전체 통과. 실시간 커널을 읽는 `SystemCPULoadTests`는 부하가 높을 때 가끔 실패해요. 그러면 단독으로 다시 돌려요.
- 커밋해서 `fix/issue-14`에 푸시하면 PR #22에 반영돼요. 머지는 하지 않아요.

## E2E 영향
- GUI e2e 없음. AppModel 통합 테스트가 탭 사이 흐름을 검증해요.
