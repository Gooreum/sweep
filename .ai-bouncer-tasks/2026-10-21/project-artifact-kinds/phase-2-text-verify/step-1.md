## 구현 목표
- 변경 대상: plan.md 해당 Step 참고
- 핵심 변경: plan.md의 Before/After
- 참고: plan.md

## 테스트 기준

| TC-ID | 유형 | 시나리오 | 기대 결과 | 실제 결과 |
|-------|------|----------|-----------|-----------|
| TC-1  | regression | plan.md 검증 항목 실행 | 새 테스트 통과, 수정 전엔 실패 | ✅ |

검증 명령어: `swift test`

## 실행출력
```
scripts/l10n.sh check → 키 530개 · 번역 없음 0개 · 소스에 없음 0개
swift test → 844건 전부 통과
```
