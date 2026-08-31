# Sweep 디자인 명세 v2

> 진실의 원천: **Raycast · Linear 계열** (사용자 선택).
>
> **v2 정정**: v1은 소스만 보고 **라이트 모드를 가정**해 대비를 쟀다.
> 앱은 **다크 모드로 돈다**. 실제 캡처의 픽셀을 재서 아래를 전부 고쳤다.
> 판정 근거는 `.design-bounce/steps/step-0/verdict.md`.
> 외부 앵커: `knowledge/design-standards.md`, `knowledge/anti-slop.md`, `knowledge/review-process.md`.
> 이 명세가 트랙 A(명세 준수) 판정 기준이다.

## 왜 고치는가 — 실측한 결함

"세련되게"를 취향으로 두지 않기 위해, 현재 코드를 표준에 대고 **직접 쟀다.**
아래는 추측이 아니라 계산·추출한 값이다.

### 대비 (WCAG AA 4.5:1) — **실제 렌더 픽셀 실측**

앱은 다크 모드로 돈다. 본문 배경은 `#222424`, 사이드바는 `#1E1E1E`.
아래는 캡처한 PNG에서 픽셀을 직접 뽑아 계산한 값이다.

**통과 — 건드리지 않는다:**

| 조합 | 실측 | |
|---|---|---|
| 사이드바 선택 글씨 / `#0A5FFF` | 5.23:1 | ✅ |
| 사이드바 미선택 글씨 / 배경 | 12.27:1 | ✅ |
| 목록 보조 글씨(`.secondary`) / 배경 | **5.67:1** | ✅ |
| 하단 캡션 / 배경 | 5.92:1 | ✅ |

> **v1은 `.secondary`가 3.95:1로 미달이라고 적었다. 틀렸다.**
> 그건 흰 배경 기준이고, 이 앱에 흰 배경은 없다.

**미달 — 고칠 대상:**

| 조합 | 실측 | 원인 |
|---|---|---|
| 선택 행 · 안전 배지 | **1.54:1** | 선택 띠가 탁한 회색 |
| 선택 행 · 설명 | **2.05:1** | 〃 |
| 선택 행 · 이름 | **2.85:1** | 〃 |
| 선택 행 · 크기 | **2.85:1** | 〃 |
| 섹션 헤더 · 개수(`.tertiary`) | **2.25:1** | 다크에서 너무 어두움 |

**단일 원인**: `selectionTint`(`#D7E6F6`)를 55% 불투명도로 다크 배경 위에 깔면
`#878E97`이 된다. 밝은 파랑이 **탁한 중간 회색**으로 변한다.
소스만 봐서는 `#D7E6F6`이 안전해 보인다 — 렌더를 봐야 보인다.

### 컴포넌트 상태

`PrimaryButtonStyle`은 5개 상태 중 **1개만** 처리한다:

| 상태 | 현재 |
|---|---|
| default | ✅ |
| active(press) | ✅ `isPressed` |
| **disabled** | ❌ **없음** |
| focus | ❌ 없음 |
| hover | ❌ 없음 |

`.disabled()`는 `\.isEnabled` 환경값만 바꾼다 — 커스텀 `ButtonStyle`이 읽지 않으면
**비활성 버튼이 활성과 똑같이 진한 파란색으로 보인다.**
지금 "정리"(선택 0건일 때)와 메뉴 막대 "검색"(스캔 중)이 그렇다.
누를 수 없는 주 동작이 누를 수 있어 보인다.

### 타이포 스케일

하드코딩된 크기가 **12종**이다: `10 11 13 15 17 22 28 34 36 48 56 64`.
표준은 모듈러 스케일에서 고르라고 한다. 12종은 스케일이 아니라 그때그때 고른 값이다.

### 8px 그리드

| 상수 | 값 | 판정 |
|---|---|---|
| `sidebarRowHeight` | **45** | ❌ 4의 배수 아님 |
| `rowCornerRadius` | **6** | ❌ |
| `panelPadding` | **14** | ❌ |

45와 6은 Cleaner One nib 실측값이다. **저쪽의 값일 뿐 그리드 체계가 아니다.**

### anti-slop 대조

| 패턴 | 현재 |
|---|---|
| 이모지를 아이콘으로 | ✅ 없음 (SF Symbols) |
| 무의미한 그라디언트 | ✅ 없음 |
| 탁한 저채도 | ⚠️ 위 대비 미달 3건 |
| **균일 카드 3열 나열** | ❌ **정확히 해당** |
| 근거 없는 디폴트 폰트 | ✅ 시스템 폰트 = macOS 네이티브 근거 있음 |

`SmartScanView.summary`가 `HStack { ForEach(Feature.summaryCards) { card($0) } }`로
**160×150 동일 카드 3장을 한 줄에** 놓는다. anti-slop 목록의
"3-identical-cards row" 그 자체다. 정크 6.9GB와 중복 100MB가 같은 크기 카드를 받는다 —
**정보 위계가 없다.**

---

## 토큰 (트랙 A 판정 기준)

### 색 — 다크·라이트 양쪽 정의

지금 `Theme`은 `accent`/`selectionTint`를 **고정 sRGB**로 박아 두고
배경·구분선만 시맨틱을 쓴다. 그래서 다크에서 틴트가 무너진다.
**두 모드 각각의 값**을 정의한다.

**표면 (surface)**

| 토큰 | 다크 | 라이트 | 용도 |
|---|---|---|---|
| `surface` | `#222424` | `#FFFFFF` | 본문 배경 |
| `surfaceSunken` | `#1A1A1A` | `#F7F7F8` | 사이드바·패널 |
| `surfaceRaised` | `#2E3033` | `#F0F0F2` | **선택 행·카드** |
| `border` | `#3A3C3F` | `#DCDCE0` | 구분선 |

> `surfaceRaised`가 `selectionTint@55%`를 대체한다. **불투명 값**이라
> 배경과 합성되지 않는다 — 이게 Blocker B1의 해결점이다.
> 다크 `#2E3033` 위에서 흰 글씨는 **11.9:1**, `.secondary`는 **4.6:1**로 통과한다.

**텍스트**

| 토큰 | 다크 | 라이트 | 대비(자기 표면 위) |
|---|---|---|---|
| `textPrimary` | `#EDEEEF` | `#1D1D1F` | 14:1+ |
| `textSecondary` | 시스템 `.secondary` 유지 | 〃 | 5.67:1 ✅ |
| `textTertiary` | `#8A8C8E` | `#6E6E73` | **4.6:1** (현재 2.25:1) |

> `.secondary`는 **그대로 둔다** — 통과하는 것을 건드리지 않는다.
> `.tertiary`만 교체한다.

**강조**

`accent #0A5FFF` / `accentPressed #0956F2` 유지 (흰 글씨와 5.23:1 실측).
다만 **쓰는 면적을 줄인다**: 버튼 / 진행 링·막대 / 선택 행 좌측 4pt 인디케이터.
**사이드바 선택 행 전체 채움은 폐지** — 다크에서 밝은 파란 판이 화면을 지배한다.

**Semantic 유지**: 안전 green / 주의 amber / 위험 red.
단, 배지는 `surfaceRaised` 위에서도 4.5:1을 넘도록 채도를 올린다
(현재 안전 배지 1.54:1).

### 타이포 — 6단계로 축소

| 토큰 | 크기 / 굵기 | 용도 |
|---|---|---|
| `display` | 32 / medium | 회수 가능 총량, 링 게이지 퍼센트 |
| `title` | 20 / regular | 화면 제목 |
| `headline` | 16 / medium | 섹션 제목, 강조 숫자 |
| `body` | 13 / regular | 목록·본문 (macOS 기본 본문) |
| `caption` | 11 / regular | 보조 설명 |
| `mono` | body/caption + `monospacedDigit` | 모든 숫자 |

- 12종 → **6종**. `15 17 22 28 34 36 48 56 64`는 전부 위 6개로 흡수한다.
- 아이콘 크기는 폰트가 아니라 `iconSize` 토큰으로 분리: `16 / 24 / 48`.
- weight는 `regular` / `medium` **2종만**.
- 폰트 패밀리는 **시스템 폰트 1종**. 근거: macOS 네이티브 앱이고 한글·숫자 혼용이
  많아 SF의 한글 폴백이 가장 안정적이다 (anti-slop #5의 "근거 명시" 요건).

### 간격 — 8px 그리드

`4 / 8 / 12 / 16 / 24 / 32`만 쓴다.

| 상수 | 현재 → 명세 | 근거 |
|---|---|---|
| `sidebarRowHeight` | 45 → **32** | 조밀한 리스트(Raycast 계열). 8의 배수 |
| `rowCornerRadius` | 6 → **6** (유지) | 버튼/행 radius 표준 4~6px |
| `panelPadding` | 14 → **16** | 8의 배수 |
| `sidebarIconSize` | 28 → **16** | 아이콘은 글자와 같은 급. 28은 과대 |
| `sidebarIconLeading` | 20 → **12** | 8의 배수, 행 높이 축소에 맞춤 |
| `cardRadius` | 10 → **10** (유지) | 카드 radius 표준 8~12px |

> **행 높이 32의 근거**: macOS 사이드바는 포인터 조작이라 iOS의 44pt 터치타겟
> 규칙이 적용되지 않는다 (`standards-mobile.md`는 모바일 전용).
> Finder·Xcode·Raycast의 사이드바 행이 모두 28~32 구간이다.

### Radius — 2종만

버튼·행 `6`, 카드·패널 `10`. 지금 섞여 있는 `Capsule()`은 **폐지**한다 —
Raycast·Linear 계열은 알약 버튼을 쓰지 않고, 6pt radius 사각 버튼이 밀도와 맞는다.
`ItemRow`의 위험 바 `cornerRadius: 1.5`는 3pt 폭 인디케이터라 예외로 둔다.

### 컴포넌트 상태 — 5개 전부

`PrimaryButtonStyle` / `SecondaryButtonStyle`은 아래를 **모두** 정의한다:

| 상태 | 표현 |
|---|---|
| default | `accent` 배경 + 흰 글씨 |
| hover | `accentPressed` (`onHover`) |
| active | `accentPressed` + 스케일 0.98 |
| **focus** | 2pt `accent` 링, 2pt 오프셋 |
| **disabled** | `surfaceRaised` 배경 + `textTertiary` 글씨 (누를 수 없음이 보인다) |

트랜지션 **150ms ease-in-out** (표준 150~300ms).

---

## 화면별 변경

### 사이드바
- 선택 표시: 강조색 **전체 채움 → `surfaceRaised` + 좌측 4pt `accent` 바**.
  강조색 면적이 줄고 스캔 중·결과 있음 같은 상태를 얹을 여지가 생긴다.
- 행 45 → 32, 아이콘 28 → 16, leading 20 → 12.
- 글씨: 선택 시에도 `textPrimary` 유지 — 배경이 파란 판이 아니라 표면이므로
  흰색으로 뒤집을 이유가 없다.

### 스마트 스캔 요약 — **anti-slop 해소**
동일 카드 3장 나열을 폐지하고 **발견량 순 위계 목록**으로 바꾼다:
- 1위 항목은 `headline` + 강조색 숫자, 나머지는 `body` + `.secondary`.
- 카드 대신 행. 값이 큰 것이 먼저·크게 보인다.
- 0건 기능은 이미 빠져 있다 (유지).

### 빈 공간 (H3) — 밀도 올리기
실측: `main`에서 사이드바 항목이 상단 360px를 쓰고 **아래 840px가 빈 공간**이다.
- 행 45 → 32로 줄면 5항목이 160px에 들어간다. 남는 자리에 **디스크 게이지를
  사이드바 하단이 아니라 항목 바로 아래**로 올려 늘 보이게 한다 (H4).
- 결과 목록은 `List`가 남은 높이를 채우도록 두되, 빈 아래쪽에
  회색 판만 남지 않게 `surface`로 통일한다.

### 결과 목록 (`ItemRow`)
- 선택 배경 `selectionTint@55%` → **`surfaceRaised`(불투명)**. Blocker B1 해결.
- 크기 열은 `mono` 유지.
- 안전도 배지·위험 바는 **그대로** — 신호를 흐리지 않는다.

### 메뉴 막대 패널
- 폭 400 유지 (Cleaner One 실측값, 사용자 승인 이력 있음).
- 카드 배경도 `surfaceRaised`로 — 지금은 같은 탁한 회색이다.
- padding 14 → 16, 게이지 높이 8 유지.
- 버튼 Capsule → radius 6.

---

## 금지 (anti-slop — 명세에 명시)

1. **이모지를 아이콘·아바타로 쓰지 않는다.** SF Symbols만.
2. **무의미한 그라디언트 금지.** 특히 보라→파랑, 무지개. 단색만.
3. **균일 카드 3열 나열 금지.** 위계 있는 목록으로.
4. **탁한 저채도 금지.** 모든 텍스트 조합 **4.5:1 이상**(큰 텍스트 3:1).
5. **근거 없는 폰트 교체 금지.** 시스템 폰트를 쓰되 위 근거를 유지.
6. 여기에 더해 — **강조색을 넓은 면적에 칠하지 않는다.** 버튼·인디케이터·진행 표시에만.

---

## 검증 (2트랙)

### 트랙 A — 명세 준수
- 표면 4단계가 다크·라이트 양쪽 값으로 `Theme`에 있고, `selectionTint` 반투명
  사용처가 0건인가 (`grep -c "selectionTint"`)
- `.tertiary` 사용처가 `textTertiary` 토큰으로 교체됐는가
  (`.secondary`는 통과하므로 **그대로 둔다**)
- 폰트 크기가 6종 이내인가 (`grep -rhoE "\.system\(size: \d+"`)
- 간격 상수가 전부 4의 배수인가
- radius가 6·10 두 종(+ 위험 바 예외)인가
- `PrimaryButtonStyle`이 `isEnabled`·`isFocused`·hover를 읽는가

### 트랙 B — 외부표준 크리틱 (스크린샷)
`knowledge/review-process.md` 8단계로 캡처를 크리틱한다.
화면 기록 권한 부여 완료 — **캡처 동작 확인됨**.
매 step마다 `before` 대비 실측 픽셀 대비를 다시 계산해 4.5:1을 확인한다.

## 어댑터 (구현 완료)

`design-bounce.config.json` + `adapters/macos-swiftui/adapter.sh`.
`navigate`는 **이미 있는 `--stage` 하니스**를 그대로 쓴다.

| 함수 | 구현 | 상태 |
|---|---|---|
| `build` | `swift build` | ✅ |
| `launch` | 바이너리 실행 + 앱 활성화 | ✅ |
| `navigate` | `--stage <id>`로 재기동 (SwiftUI 씬은 런타임 딥링크가 없다) | ✅ |
| `capture` | AX로 창 좌표 → `screencapture -x -R<x,y,w,h>` | ✅ |

> **창은 활성화 전에는 `CGWindowList`에서 `onscreen=false`로 나오고 AX에서도
> 잡히지 않는다.** `capture`가 매번 `activate`를 먼저 부른다.
> `CGWindowID` 방식은 PyObjC(`Quartz`)가 없어 영역 캡처로 갔다.

## 개발 Step 계획

- **Step 1** — 토큰: 표면 4단계(다크·라이트) + 타이포 6단계 + 간격/radius + 버튼 5상태
  → **Blocker B1·B2와 High H2 해결**
- **Step 2** — 사이드바: 선택 표시를 `surfaceRaised` + 좌측 바, 행 32/아이콘 16,
  디스크 게이지를 항목 바로 아래로 → **H3·H4 해결**
- **Step 3** — 스마트 스캔: 균일 카드 3열 → 위계 목록 (anti-slop 해소)
- **Step 4** — 결과 목록·메뉴 막대 패널: 틴트 교체, padding·radius 정리
