# Sweep 디자인 명세 v3 — 초점 스택(Focus Stack)

> 진실의 원천: **사용자가 준 핸드오프**
> `~/Downloads/design_handoff_sweep_focus_stack/` (README.md + `Sweep 초점 스택.dc.html`)
>
> 프로토타입을 브라우저로 **직접 열어 봤다**(2026-09-16). 레퍼런스와 잰 값은
> `.design-bounce/ref/*/intent.md`에 있다.
>
> v2(Raycast·Linear 계열)를 대체한다. 외부 앵커는 그대로:
> `knowledge/design-standards.md`, `anti-slop.md`, `review-process.md`.

## 무엇을 바꾸는가

핸드오프가 푸는 문제는 "기계적이고 투박하다"이다. 다섯 가지를 바꾼다.

1. 투명 재질(`NSVisualEffectView`) 사이드바 + 툴바 통합 — 검색·전역 액션을 타이틀바로
2. 우측 선택 독 252pt — 하단 액션 바를 없애고 선택 요약·안전도 분포·주 동작을 한곳에
3. 안전도 표현 교체 — 색 알약 3종 → 아이콘 + 톤다운 색 (안전은 **아무 색도 쓰지 않는다**)
4. 삭제 확인 시트 — 목록에서 바로 지우지 않고 개수·용량·제외된 보호 항목을 다시 보여줌
5. 목록 행 56pt, 섹션 헤더 sticky 34pt 접기/펼치기

---

## ⚠️ 핸드오프 수정 — 신규 색 두 개가 자체 기준에 미달한다

README가 직접 적어 둔 규칙:

> 새로 넣은 `#B4894E` / `#B2685A`는 `surface #2A2C2E` 위 4.5:1을 만족해야 합니다.
> 구현 후 실측 확인. (…) 같은 색으로 보조 문구도 칠하므로 4.5:1로 봅니다.

**실측하니 둘 다 미달이다.**

| 색 | surface `#2A2C2E` | surfaceRaised `#34363A` | 선택 행 `#273141` |
|---|---|---|---|
| caution `#B4894E` | **4.42:1** ❌ | **3.82:1** ❌ | 4.14:1 ❌ |
| danger `#B2685A` | **3.35:1** ❌ | **2.89:1** ❌ | 3.13:1 ❌ |

`surfaceRaised`가 가장 불리하다 — 카드와 **선택된 행**이 그 위에 그려지고,
행 설명글(`caption`)이 바로 이 색으로 칠해진다.

### 보정값 — 색상각·채도를 지키고 명도만 올렸다

| 토큰 | 핸드오프 | **명세 v3** | surface | surfaceRaised | 선택 행 |
|---|---|---|---|---|---|
| `cautionText` | `#B4894E` | **`#BE9965`** | 5.30:1 ✅ | 4.57:1 ✅ | 4.95:1 ✅ |
| `dangerText` | `#B2685A` | **`#C79187`** | 5.23:1 ✅ | 4.51:1 ✅ | 4.89:1 ✅ |

HSL에서 hue·saturation을 고정하고 lightness만 올려 최소 통과점을 찾았다.
"톤 다운" 의도(기존 `.orange`/`.red`의 형광기를 뺀다)는 유지된다 —
채도가 낮은 흙빛이라는 성격은 그대로고 밝기만 읽히는 수준으로 올렸다.

> `textTertiary #8A8C8E`도 surface 위 4.15:1로 미달이지만 **기존 값이고 이번 범위가 아니다.**
> 보조 중의 보조(경로·날짜)에만 쓰이므로 이번엔 건드리지 않고 기록만 남긴다.

---

## 토큰 — `Theme`에만 추가한다

화면 코드에서 hex를 직접 쓰지 않는다. 아래는 `Theme.swift`에 들어갈 신규 항목이다.

```swift
// 안전도 — 배지(면 채움)를 버리고 아이콘·글씨 색으로만 쓴다.
// 핸드오프 원안(#B4894E/#B2685A)은 surfaceRaised 위 3.82:1·2.89:1로 미달이었다.
// 색상각과 채도는 그대로 두고 명도만 올려 4.5:1을 넘긴 값이다.
static let cautionText = adaptive(dark: 0xBE9965, light: 0x8A5F1E)
static let dangerText  = adaptive(dark: 0xC79187, light: 0x9A3B2A)

// 선택된 행. 면을 accent로 채우지 않고 9%만 얹는다 —
// 목록 전체가 파랗게 덮이면 정작 무엇을 골랐는지가 안 보인다.
static let rowSelected = accent.opacity(0.09)

// 치수
static let dockWidth: CGFloat = 252        // 우측 선택 독
static let rowHeightComfortable: CGFloat = 56
static let rowHeightCompact: CGFloat = 46
static let sectionHeaderHeight: CGFloat = 34
static let toolbarHeight: CGFloat = 52
static let sidebarWidth: CGFloat = 212     // 기존 220 → 212
static let windowWidth: CGFloat = 1180     // 기존 1160 → 1180 (독 폭 확보)
```

기존 토큰은 그대로 쓴다: `surface`·`surfaceRaised`·`surfaceSunken`·`border`·
`textPrimary`·`textSecondary`·`textTertiary`·`accent`·`accentText`·
`rowCornerRadius`(6)·`cardRadius`(10)·서체 6단계.

## 안전도 아이콘 매핑

| 등급 | SF Symbol | 색 | 크기 |
|---|---|---|---|
| safe | `circle` | `textTertiary` | 11pt 슬롯, 도형 7pt |
| caution | `exclamationmark.triangle` | `cautionText` | 11pt |
| danger | `lock.fill` | `dangerText` | 11pt |

**`SafetyBadge`(알약)는 삭제한다.** 안전 항목에 초록 알약을 붙이면 목록 대부분이
색으로 덮여 정작 위험한 것이 묻힌다. 안전은 **기본값이므로 칠하지 않는다.**

## 검토 목록 행 (`ItemRow` 개편)

높이 56, padding 좌우 24, 요소 간격 14.

```
[체크박스 16] [안전도 11] [이름 bodyText / 설명 caption] ......... [용량 bodyMono]
```

- 체크박스: radius 4. 선택 시 `accent` 채움 + 흰 체크. **danger는 비활성** (외곽선만)
- 설명 색: 등급에 따라 `cautionText`/`dangerText`, safe면 `textTertiary`
- 용량: 선택 시 `textPrimary`, 미선택 `textTertiary`
- 행 배경: 선택 시 `rowSelected`, 아니면 투명
- 행 어디를 눌러도 선택 토글. **danger는 무반응** — 실수로 지울 여지를 남기지 않는다

## 섹션 헤더

높이 34, sticky, 재질 배경.
`[caret 5pt] [묶음명 caption semibold, 자간 0.4] [개수 caption] ... [합계 caption mono]`
클릭으로 접기/펼치기. 상태는 `ScanModel.collapsedGroups`가 소유한다.

## 우측 선택 독

폭 252, padding 22/20, 재질 `.sidebar`, 좌측 0.5pt 구분선. **검토 목록에서만** 보인다.

```
선택                          ← eyebrow, caption
16.83 GB                     ← 30pt medium mono
4개 · 전체 7개 중              ← caption

○ 다시 만들 수 있음      4개
▲ 확인 필요             3개
🔒 보호됨 · 선택 불가     0개

          (Spacer)

휴지통으로 옮기며 30일간 되돌릴 수 있습니다.
[  16.83 GB 정리  ]          ← primary, 높이 34
```

선택 0건이면 버튼 비활성 + "선택한 항목 없음". **완료 화면에서는 독을 내린다.**

## anti-slop 금지 (명세에 박아 둔다)

- ❌ 균일한 카드 3열 나열 — 개요는 히어로 + 목록이지 카드 그리드가 아니다
- ❌ 강조색을 넓은 면적에 칠하기 — `accent`는 선택 행 9%, 주 버튼, 1위 숫자에만
- ❌ 이모지 아이콘 — 전부 SF Symbols
- ❌ 무의미한 그라디언트 — 프로토타입의 창 배경 방사형 그라디언트는 **구현하지 않는다**
  (재질이 그 역할을 대신한다. README도 그렇게 적었다)
- ❌ CSS `backdrop-filter` 흉내 — `NSVisualEffectView` 실물 재질을 쓴다

## 판정 기준

- **트랙 A(명세 준수)**: 이 문서의 토큰·치수·구조
- **트랙 B(외부표준)**: 대비 4.5:1, 8px 그리드, 시각 위계
- **트랙 C(이름 대기)**: 화면UI라 "무엇으로 보이나"보다 **"어느 화면인지 / 무엇을 하는 곳인지"**
  를 명세 없이 맞히는지로 변형해 적용
- **트랙 D(대조)**: `.design-bounce/ref/review-list/prototype.jpg`와 나란히 놓고 다른 점 3개
