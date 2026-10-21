## 목표
폴더 빼기가 다른 접근을 안 닫고, 큰 파일 탐색 범위가 의도대로이고, 최근 작업 판정이 하위 파일을 본다.

## 기술 접근
- `FolderAccess.Registry`: revoke만 있음 → forgetBookmark 추가, AppModel이 다른 곳에서 열린 폴더면 북마크만 지움
- `UserFileWalker`: 짝 맞는 산출물을 항상 건너뜀 → 등록한 프로젝트 폴더 안일 때만 건너뜀
- `ProjectArtifactScanner.lastActivity`: 바로 아래 항목 mtime → 깊이 3 하위 + .git 파일, 기준일 이후 발견 시 중단

## Steps
- Step 1: 폴더 빼기 수정 — 공유 폴더면 접근 유지
- Step 2: UserFileWalker 범위 — 등록 밖 target 안 큰 파일 포함
- Step 3: lastActivity 개선 — 하위 파일만 고친 프로젝트가 caution
