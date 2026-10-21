## 구현 목표
- 변경 대상: plan.md 참고
- 핵심 변경: plan.md 참고
- 참고: plan.md

## 테스트 기준

| TC-ID | 유형 | 시나리오 | 기대 결과 | 실제 결과 |
|-------|------|----------|-----------|-----------|
| TC-1  | happy | 1.0.6 (10601) 검사 실행 | 통과, 어긋난 번호는 멈춤 | ✅ |

검증 명령어: `bash scripts/make-archive.sh --check-only`

## 실행출력
```
스킬·APPSTORE.md·메모리에 새 규칙 기록, grep 10601 세 곳 확인
bash scripts/make-archive.sh --check-only 로 확인
```
