## 목표
목록 이름이 버전 번호가 아니고, CPU 탭 상태 줄이 "시작 전"이 아니다.

## 기술 접근
- `ProcessCPUSampler.displayName`: 경로 마지막 조각 → 버전 번호·껍데기 폴더면 위로 올라가 사람이 아는 이름
- `AppModel.statusLine`: CPU 탭도 스캔 모델 기준 → .cpu 분기와 StatusLine.cpu 추가

## Steps
- Step 1: displayName(forPath:) + 테스트
- Step 2: StatusLine.cpu + 번역 + 테스트
