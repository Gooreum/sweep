## 구현 목표
- 변경 대상: plan.md 해당 Step 참고
- 핵심 변경: plan.md ## 변경 섹션의 Before/After
- 참고: plan.md

## 테스트 기준

| TC-ID | 유형 | 시나리오 | 기대 결과 | 실제 결과 |
|-------|------|----------|-----------|-----------|
| TC-1  | happy | 버전이 바뀌고 빌드가 1로 돌아간 경우 실행 | 새 규칙대로 통과하거나 build=true | ✅ |

검증 명령어: `plan.md 검증 섹션 참고`

## 실행출력
```
build=true(1.0.5(1)→1.0.6(1)), build=false(동일), build=true(1.0.6(1)→(2))
실제 실행 결과: 위와 같음 (release-diff.sh, make-archive.sh --check-only)
```
