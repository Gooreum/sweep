# 안전 칩 한글화 · 새 기능 문구 쉽게 · CPU·공간 보기 아이콘

## Context
설치해서 써 본 사용자가 세 가지를 짚었어요.
1. 한국어 화면인데 안전도 칩이 "SAFE", "REVIEW", "DANGER"로 영문이에요.
2. 설명이 있는데 쉽게 이해가 안 돼요.
3. CPU와 공간 보기 아이콘을 바꿔 달래요. 코덱스에게 시키라고 했어요.

**원인**
1. `SafetyChip`이 글자를 `"SAFE"`처럼 고정해 둬요(`Retro95Controls.swift:195`). 앞서 문구를 다시 쓸 때 "SAFE·REVIEW·DANGER는 그대로 둔다"는 규칙(`style.md`, `glossary.md`)을 만들어서 이대로 남았어요. 용어집에는 "안전, 주의, 위험"이 이미 있고 영어 번역(Safe/Caution/Danger)도 카탈로그에 있어요.
2. 이번 세션에 PR #25·#26·#28로 들어간 새 문구 48개가 **문구 다시 쓰기를 거치지 않았어요**. 개발 프로젝트 탭의 설명 줄("package.json 짝 · npm install로 다시 설치해요"), 빈 화면 안내, 거절 사유, 디스크 부족 알림 설정이에요. 전문용어와 `·` 기호가 그대로 있어요.
3. CPU는 앱 로고와 같은 `.computer`, 공간 보기는 `.pieChart`를 써요. 둘 다 기능을 말해 주는 그림이 아니에요.

브랜치는 `feat/project-artifact-kinds`(PR #28) 위에서 `fix/safety-chip-copy-icons`로 따요. 문구가 #28에 있는 것이라 거기서 이어야 충돌이 없어요.

## 1. 안전 칩 한글화 (내가 직접)
`Sources/SweepApp/Retro95/Retro95Controls.swift`
```swift
// Before
private var label: String {
    switch level { case .safe: "SAFE"; case .caution: "REVIEW"; case .danger: "DANGER" }
}
// After — 용어집의 "안전, 주의, 위험"(영어는 Safe, Caution, Danger)
private var label: String { level.displayName }
```
- 칩 폭: 한글 두 글자라 "REVIEW"보다 좁아서 안 잘려요. 확인은 캡처로 해요.
- `.design-bounce/copy/style.md`·`glossary.md`의 "SAFE, REVIEW, DANGER는 그대로 둔다" 문장을 지워서 규칙과 코드가 어긋나지 않게 해요.

## 2. 새 문구 쉽게 다시 쓰기 (코덱스)
**대상**: 아래 38개. `코드/탭 이름` 같은 짧은 라벨 10개(`알림`, `켜기`, `괜찮아요`, `%lldGB`, `폴더 추가…`, `프로그램 %lld개`, `실시간으로 보는 중`, `개발 프로젝트`, `보는 폴더`, `프로젝트 설치·빌드 폴더`)는 건드리지 않아요.
- 개발 프로젝트 탭: 설명 줄 3개(`%@ 짝 · %@`, `최근 %lld일 안에…`, `lock 파일이 없어…`), 다시 만드는 법 16개, 탭 설명, 빈 화면 안내 2개, 거절 사유 3개, 표 위 설명, `다시 열어 주세요`
- 디스크 부족 알림: 알림 제목·본문, 설정 스위치·기준 문구·5분 안내, 권한 꺼짐 안내, 동의 줄
- `원본도 정리 목록에 있어요…`(이슈 #21 수정에서 들어온 문구)

**코덱스에게 주는 것**: `.design-bounce/copy/style.md`·`glossary.md`, 위 문구와 각 문구가 화면 어디에 뜨는지, 해당 Swift 파일 경로. 지켜야 할 것은 이래요.
- 컴퓨터를 모르는 사람도 알아듣는 해요체. `npm install` 같은 명령어는 괄호 안 예시로만 쓰고 앞에 풀어 쓴 말을 먼저 둬요.
- 가운데점(`·`)으로 이은 문장은 쓰지 않아요(style.md). 사실만 가져오고 문장은 새로 써요.
- `%@`, `%lld`의 개수와 뜻을 그대로 둬요. 순서는 바꿔도 돼요.
- 안전 정보(휴지통으로 옮겨요, 다시 생겨요, 최근에 고쳤어요, 버전이 달라질 수 있어요)를 빼지 않아요.
- Swift 소스의 `String(localized:)` 문구와 `Resources/Localizable.xcstrings`의 키·영어 번역을 같이 고쳐요. 영어도 쉬운 말로 다시 써요.
- 소스 구조·식별자·테스트 코드는 건드리지 않아요. `swift build`는 코덱스 샌드박스에서 안 돼요.

**내가 확인하는 것**: `scripts/l10n.sh check`(번역 없음 0, 소스에 없음 0), `swift build`, 보간값 개수, 설명 줄이 좁은 칸에서 두 줄 안에 들어가는지, 낡은 키가 카탈로그에 안 남았는지. 코덱스가 쓴 것은 그대로 복붙하지 않고 읽어서 어색하거나 사실이 바뀐 곳을 고쳐요.
**깨질 테스트**: `ProjectArtifactTests`가 설명 줄에 "package.json", "최근 14일", "lock"이 들어 있는지 문자열로 확인해요. 문구가 바뀌면 말 대신 **어떤 사유인지**를 확인하도록 고쳐요(`SafetyLevel`과 설명 줄이 비어 있지 않은지).

## 3. 아이콘 (코덱스)
새 그림 둘을 `Sources/SweepApp/Retro95/PixelIcon.swift`에 더해요. 16×16 문자 그림이고 팔레트 글자(`k w g d D n b c y Y r R G e`)만 써요.
- `chip` (CPU): 핀이 달린 프로세서 칩. 가운데에 작은 사각형, 네 변에 핀.
- `spaceView` (공간 보기): 폴더 크기를 사각형 블록으로 나눠 보여 주는 모양(트리맵). 크기가 다른 사각형이 한 판에 들어 있어요.
```swift
// Feature.pixelArt
case .diskMap: .pieChart   →   .spaceView
case .cpu:     .computer   →   .chip
```
- 아이콘이 쓰이는 곳 중 CPU 화면 안의 큰 그림(`CPUView.swift:111,128,383` `.computer` 32pt)은 `.chip`으로, 공간 보기 화면의 그림(`DiskMapView.swift:142,309,557` `.pieChart`)은 `.spaceView`로 바꿔요. **사이드바 맨 위 앱 로고(`.computer`)와 `.pieChart`·`.computer` 자체는 남겨요** — 다른 곳에서 쓰여요.
- 코덱스에게: 16×16, 칸마다 한 글자, 외곽선 `k`, 사이드바(24pt)와 32pt에서 알아볼 수 있게. Python(Pillow)으로 확대 미리보기 PNG를 만들어 눈으로 확인한 뒤 결과 그림과 근거를 보고해요.
- 내가 확인: 빌드, 샌드박스 캡처(CPU·공간 보기·정리 목록)로 사이드바와 큰 그림이 또렷한지.

## 개발 Phase 계획

### Phase 1: 안전 칩
**목표**: 한국어 화면의 안전도 칩이 한글이다.
- Step 1: `SafetyChip` 라벨과 style·glossary 정리 — `swift build` 통과, 캡처에서 "안전·주의·위험"이 칩 안에 들어감

### Phase 2: 문구와 아이콘(코덱스 위임)
**목표**: 새 기능 문구가 쉬운 말이고, CPU·공간 보기 아이콘이 기능을 말한다.
- Step 1: 코덱스 문구 다시 쓰기 → 내가 검증하고 `l10n.sh check`·깨진 테스트 수정
- Step 2: 코덱스 아이콘 → 내가 빌드와 캡처로 검증

### Phase 3: 마무리
**목표**: 전체 테스트와 설치.
- Step 1: `swift test` 전체, PR 생성, 샌드박스 빌드를 `/Applications`에 설치

## 검증
- `swift test` 전체. CPU 실측 테스트는 부하가 높을 때 가끔 실패해서 단독 재실행해요.
- `scripts/l10n.sh check`: 번역 없음 0.
- 샌드박스 캡처: 한국어 정리 목록(칩), CPU, 공간 보기. 영어도 한 번 봐요.
- 개발 프로젝트 탭 문구는 캡처 장면이 없어서 눈으로 못 봐요. 읽어서 확인하고 설치한 앱에서 사용자가 보게 해요.

## E2E 영향
GUI e2e 없음. 단위 테스트, `l10n.sh check`, 샌드박스 캡처.
