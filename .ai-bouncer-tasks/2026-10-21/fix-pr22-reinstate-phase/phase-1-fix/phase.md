## 목표
완료 화면 탭도 되돌린 항목을 받는다. 화면은 그대로다.

## 기술 접근
- `ScanModel.reinstate`: `guard phase == .results` → idle/scanning만 건너뛰는 switch
- `AppModelTests`: 기존 테스트 이름·단언 보강 + 스마트 스캔 완료 화면 시나리오 테스트 추가

## Steps
- Step 1: reinstate 수정 + 테스트 2개 — swift test 통과
