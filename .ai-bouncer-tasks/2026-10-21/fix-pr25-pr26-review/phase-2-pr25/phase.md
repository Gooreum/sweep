## 목표
전송이 실패하면 다음 회차에 다시 알리고, 감시 Task가 감시기와 함께 끝난다.

## 기술 접근
- `DiskWatcher`: 장전 즉시 해제 → deliveryFailed()로 장전 복구, Task 루프 weak 정리
- `DiskAlertNotifier.post`: add 결과 무시 → 오류 시 deliveryFailed 호출

## Steps
- Step 1: 전송 실패 재시도 + Task 종료 + 테스트
- Step 2: PR 본문 범위 문구
