## 목표
영어 배지가 안 잘리고, 마우스를 올린 동안 행이 안 움직인다.

## 기술 접근
- `AppModel.badges`/`Sidebar.row`: 긴 용량 문자열·배지 축소 → 한 자리 소수, 배지 고정 폭
- `CPUModel.rows`: 항상 사용률순 → 마우스가 표 위에 있는 동안 순서 고정(holdOrder)

## Steps
- Step 1: 배지 형식·레이아웃
- Step 2: holdOrder + 테스트
