## 목표
새 종류가 짝·`.gitignore` 조건대로만 잡히고, 관문과 큰 파일 탐색도 같은 판정을 쓴다.

## 기술 접근
- `GitIgnore.swift`: 없음 → 폴더 이름이 .gitignore에 적혀 있는지 판독(위로 8단계, .git에서 멈춤)
- `ProjectArtifactRule`: 파일 옆 짝 검사만 → manifestsInside, requiresIgnore 성질과 새 규칙 10줄

## Steps
- Step 1: GitIgnore + 단위 테스트
- Step 2: 규칙 구조와 새 규칙 + 매칭·스캐너·관문 테스트
