## 구현 목표
- 변경 대상: `Sources/SweepKit/Presentation/ScanModel.swift`, `Tests/SweepKitTests/AppModelTests.swift`
- 핵심 변경: reinstate의 phase 가드를 idle/scanning 제외로 완화, 테스트 추가
- 참고: plan.md

## 테스트 기준

| TC-ID | 유형 | 시나리오 | 기대 결과 | 실제 결과 |
|-------|------|----------|-----------|-----------|
| TC-1  | e2e | 스마트 스캔이 cleaned일 때 정크 탭에서 정리 후 되돌림 | smart.items에 항목 복귀, phase 유지, 배지 동일 | ✅ |
| TC-2  | regression | 큰 파일 탭 cleaned일 때 정크 탭 되돌림 | big.phase cleaned·canUndo 유지, 남의 몫 미삽입 | ✅ |

검증 명령어: `swift test --filter AppModelTests`

## 실행출력
```
swift test --filter AppModelTests → 43 tests passed
수정 제외 시 undoReachesSmartScanShowingOutcome 실패(0 == 1, 배지 불일치) 확인
swift test → 789건 중 CPU 측정 1건 부하로 흔들림, 단독 9건 통과
```
