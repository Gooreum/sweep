# CPU 탭·사이드바 잔손질 4건

## Context
이전에 관찰만 하고 이슈로 안 올린 네 가지를 고쳐요. 사용자가 "그냥 고쳐"라고 했어요. 전부 `main`에서 새 브랜치 `fix/cpu-polish`로 작업하고 PR로 올려요.

| # | 증상 | 원인 |
|---|---|---|
| 1 | CPU 탭 아래 상태 줄이 "시작 전" | `AppModel.statusLine`이 CPU 탭도 스캔 모델(`currentModel`=nil) 기준으로 그림 |
| 2 | CPU 목록에서 claude가 "2.1.304"로 보임 | 이름을 실행 파일 경로의 마지막 조각으로 정하는데, claude는 `.../claude/versions/2.1.304`가 실제 파일 |
| 3 | 영어에서 "Files to Clean" 옆 용량이 "26.88…"로 잘림 | 이름이 먼저(layoutPriority 1)라 배지가 줄어들고, 배지 글자가 "26.88 GB"로 길다. 사이드바 폭 184 고정 |
| 4 | 클릭하려는 순간 행이 움직임 | 2초마다 사용률순으로 다시 정렬 |

## 변경

### 1. CPU 탭 상태 줄 — `AppModel.swift`
```swift
// StatusLine 에 추가
static func cpu(model: CPUModel?) -> StatusLine {
    guard let model else { return StatusLine(status: String(localized: "측정 중…"), count: empty, size: empty) }
    if model.isWarmingUp { return StatusLine(status: String(localized: "측정 중…"), count: empty, size: empty) }
    return StatusLine(status: String(localized: "실시간으로 보는 중"),
                      count: String(localized: "프로그램 \(model.usage.count)개"), size: empty)
}
// statusLine
case .cpu: StatusLine.cpu(model: cpuModel)     // cpuModel 은 body 에서 만들지 않는다(기존 diskMap 과 같은 이유)
```
새 문구 3개는 `Localizable.xcstrings`에 영어를 같이 넣어요("Measuring…", "Live", "\(n) programs"). "측정 중…"은 이미 있어요.

### 2. 버전 번호 이름 — `ProcessCPUSampler.swift`, `ProcessDetails.swift`
```swift
/// 실행 파일 경로에서 사람이 알아볼 이름. 마지막 조각이 버전 번호(2.1.304)면
/// 그 위로 올라간다. `versions`·`bin` 같은 껍데기 폴더도 건너뛴다.
static func displayName(forPath path: String) -> String? {
    var parts = URL(filePath: path).pathComponents.filter { $0 != "/" }
    guard var last = parts.popLast(), !last.isEmpty else { return nil }
    let shells: Set<String> = ["versions", "version", "bin", "current", "latest"]
    while isVersion(last) || shells.contains(last.lowercased()) {
        guard let next = parts.popLast() else { return last }
        last = next
    }
    return last
}
static func isVersion(_ s: String) -> Bool { s.range(of: #"^v?\d+(\.\d+)+$"#, options: .regularExpression) != nil }
```
`displayName(of:path:)`과 `ProcessDetailsReader.name`이 이 함수를 써요. `/Users/x/.local/share/claude/versions/2.1.304` → `claude`. `/usr/bin/zsh`는 `zsh` 그대로, `bin`으로 끝나는 경로만 올라가요(`/usr/bin`은 실행 파일이 아니라 폴더라 해당 없음).

### 3. 배지 잘림 — `AppModel.swift`, `Sidebar.swift`
```swift
// 배지 문자열: 10 이상이면 소수 첫째 자리까지. "26.88 GB" → "26.9 GB"
static func compactSize(_ bytes: Int64) -> String
```
`ByteCountFormatter`로 단위를 정한 뒤, 숫자 부분이 10 이상이면 소수점 이하를 한 자리로 줄여요(숫자 형식은 `NumberFormatter`로 로캘을 따라요).
```swift
// Sidebar.row — 배지가 줄어들지 않게
Text(badge).font(R95.mono(11)).lineLimit(1).fixedSize(horizontal: true, vertical: false)
Text(feature.displayName).font(R95.ui(13)).lineLimit(1).minimumScaleFactor(0.85).layoutPriority(1)
```
그래도 영어 "Files to Clean"이 잘리면 `sidebarWidth`를 184 → 192로 키워요(스크린샷으로 확인해서 결정).

### 4. 클릭 순간 행이 움직이는 문제 — `CPUModel.swift`, `CPUView.swift`
표 위에 마우스가 있는 동안은 순서를 고정하고, 값은 계속 갱신해요.
```swift
// CPUModel
private var heldOrder: [String]?          // CPURow.id 순서
public func holdOrder(_ hold: Bool) { heldOrder = hold ? rows.map(\.id) : nil }
public var rows: [CPURow] {
    let base = CPURow.rows(usage: usage, unlisted: unlistedPercent)
    guard let heldOrder else { return base }
    let position = Dictionary(uniqueKeysWithValues: heldOrder.enumerated().map { ($1, $0) })
    return base.enumerated().sorted {            // 새로 생긴 줄은 끝으로, 나머지는 잡아 둔 순서 그대로
        (position[$0.element.id] ?? Int.max, $0.offset) < (position[$1.element.id] ?? Int.max, $1.offset)
    }.map(\.element)
}
```
```swift
// CPUView.processTable
.onHover { model.holdOrder($0) }
```
잡아 둔 동안 사라진 프로세스는 `base`에 없으니 자연히 빠져요. 마우스가 나가면 다시 사용률순으로 돌아가요.

## 개발 Phase 계획

### Phase 1: 이름·상태 줄
**목표**: 목록 이름이 버전 번호가 아니고, CPU 탭 상태 줄이 "시작 전"이 아니다.
- Step 1: `displayName(forPath:)` + 테스트 — `swift test --filter ProcessCPUSampler|ProcessDetails` 통과
- Step 2: `StatusLine.cpu` + 영어 번역 + 테스트 — `swift test --filter StatusLine|AppModel` 통과

### Phase 2: 사이드바·정렬
**목표**: 영어 배지가 안 잘리고, 마우스를 올린 동안 행이 안 움직인다.
- Step 1: 배지 형식·레이아웃 — 영어 캡처에서 "Files to Clean" 옆 용량이 끝까지 보인다
- Step 2: `holdOrder` + 테스트 — `swift test --filter CPUModel` 통과, 전체 `swift test` 통과

## 검증
- `swift test` 전체. 실시간 커널을 읽는 `SystemCPULoadTests`·`ProcessCPUSamplerTests`는 부하가 높을 때 가끔 실패해서 단독 재실행해요.
- 새 테스트는 수정을 빼면 실패하는지 확인해요.
- 샌드박스 빌드(`scripts/make-app.sh` + Developer ID 서명)로 설치해, 영어 사이드바 배지와 CPU 목록 이름을 눈으로 확인해요. 마우스 올린 상태의 정렬 고정은 직접 눌러 봐요.
- `fix/cpu-polish` 브랜치로 PR을 열어요. 머지는 하지 않아요.

## E2E 영향
GUI e2e 없음. 단위 테스트 + 샌드박스 빌드 눈 확인.
