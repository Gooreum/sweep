# PR #25·#26 자동 리뷰 지적 반영

## Context
pm이 올린 두 PR의 자동 리뷰에 고칠 점이 있어요. 머지 전에 두 브랜치에서 각각 고치고 푸시해요. 머지는 하지 않아요.

- **#26** (`feature/issue-18`, 개발 프로젝트 탭): 🟡 2건 + ⚪ 1건
- **#25** (`feature/issue-17`, 디스크 부족 알림): 🟡 3건 중 **전송 실패 처리만** 실결함이라 고치고, ⚪ 1건(감시 Task 종료)도 같이 고쳐요. 폭주 임시 파일 알림은 샌드박스에서 못 읽어 뺀 의도된 범위이고(기획서에 명시), 알림 종류 구분 표시는 알림이 하나뿐이라 지금은 불필요해요. 두 건은 PR 본문에 범위를 밝히는 것으로 처리해요.

## Phase 1: `feature/issue-18` (PR #26)

### 1-1. 폴더 빼기가 다른 탭의 접근을 닫는 문제 — `FolderAccess.swift`, `AppModel.swift`
`revoke`는 키와 상관없이 같은 경로의 열린 접근(`grantedURLs`)을 전부 닫아요.
```swift
// FolderAccess.Registry 에 추가 — 북마크 키만 지우고 열린 접근은 그대로 둔다
public func forgetBookmark(_ grantable: Grantable) {
    defaults.removeObject(forKey: grantable.key)
}
```
```swift
// AppModel.removeProjectFolder
// Before
if requiresFolderAccess { folderAccess.revoke(ProjectFolders.grantable(for: url)) }
// After
if requiresFolderAccess {
    let grantable = ProjectFolders.grantable(for: url)
    if isFolderOpenedElsewhere(url) { folderAccess.forgetBookmark(grantable) }
    else { folderAccess.revoke(grantable) }
}

/// 같은 폴더를 큰 파일 탭(UserFolders)이나 고정 허락(FolderAccess.grantables)으로도 열어 두었는가.
private func isFolderOpenedElsewhere(_ url: URL) -> Bool {
    let target = FolderAccess.components(of: url)
    let others = FolderAccess.grantables.map(\.folder) + userFolders.custom
    return others.contains { FolderAccess.components(of: $0) == target }
}
```
`FolderAccess.components(of:)`가 `static`(internal)이라 AppModel에서 쓸 수 있어요.

### 1-2. 등록하지 않은 폴더의 `target` 안 큰 파일이 안 보이는 문제 — `UserFileWalker.swift`, `ProjectFolders.swift`
```swift
// ProjectFolders 에 추가
/// 등록한 프로젝트 폴더 안(자기 포함)인가. 관문 캐시를 재사용한다.
static func contains(_ url: URL) -> Bool {
    let parts = ProtectedPaths.canonical(url).standardizedFileURL.pathComponents
    return cachedRootComponents().contains { root in
        parts.count >= root.count && Array(parts.prefix(root.count)) == root
    }
}
```
```swift
// UserFileWalker.files — Before
if UserFolders.skippedDirectoryNames.contains(url.lastPathComponent)
    || ProjectArtifactRule.match(url) != nil { walker.skipDescendants() }
// After: 짝이 맞는 산출물은 등록한 프로젝트 폴더 안일 때만 건너뛴다(그 탭이 이미 보여주므로)
if UserFolders.skippedDirectoryNames.contains(url.lastPathComponent)
    || (ProjectArtifactRule.match(url) != nil && ProjectFolders.contains(url)) {
    walker.skipDescendants()
}
```
주석도 "등록한 프로젝트 폴더 안일 때만"으로 고쳐요.

### 1-3. 최근 작업 판정이 부정확한 문제 — `ProjectArtifactScanner.swift`
```swift
// Before: 프로젝트 바로 아래 항목의 mtime만 본다
static func lastActivity(of project: URL) -> Date?
// After: 하위를 깊이 3까지 훑되, 기준일보다 새 파일이 나오면 즉시 멈춘다. .git/index·HEAD도 본다.
static let activityDepth = 3
static func lastActivity(of project: URL, since cutoff: Date) -> Date? {
    var newest: Date?
    func consider(_ date: Date?) -> Bool {   // 기준일보다 새로우면 true(중단)
        guard let date else { return false }
        if newest == nil || date > newest! { newest = date }
        return date > cutoff
    }
    for name in [".git/index", ".git/HEAD"] {
        if consider(modified(project.appending(path: name))) { return newest }
    }
    guard let walker = FileManager.default.enumerator(
        at: project, includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
        options: [.skipsPackageDescendants]) else { return newest }
    for case let url as URL in walker {
        let name = url.lastPathComponent
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        if isDir && (ProjectArtifactRule.names.contains(name) || name.hasPrefix(".")
                     || walker.level >= activityDepth) { walker.skipDescendants() }
        if name == ".DS_Store" || (isDir && ProjectArtifactRule.names.contains(name)) { continue }
        if consider(modified(url)) { return newest }
    }
    return newest
}
```
`assess`는 `lastActivity(of: project, since: cutoff)`로 부르고 `touched > cutoff`를 그대로 써요. 기존 테스트(`ProjectArtifactTests.swift:166`)는 새 시그니처에 맞춰 고쳐요.

### 1-4. 테스트
- `FolderAccessTests` 또는 `AppModelTests`: 같은 폴더를 프로젝트 폴더와 큰 파일 폴더 둘 다에 등록한 뒤 프로젝트 쪽만 빼면 `folderAccess.urls`에 그 폴더가 남는다. 하나만 등록했을 때는 닫힌다.
- `UserFileWalkerTests`: 등록하지 않은 경로의 `proj/target/big.bin`은 잡히고, 등록한 프로젝트 폴더 안의 것은 안 잡힌다.
- `ProjectArtifactTests`: `src/a/b.ts`만 최근에 고친 프로젝트가 caution이다. 오래된 프로젝트는 safe다. `.git/index`만 최근이어도 caution이다.

## Phase 2: `feature/issue-17` (PR #25)

### 2-1. 전송 실패해도 "보냈다"고 기록하는 문제 — `DiskWatcher.swift`, `DiskAlertNotifier.swift`
`tick()`이 `notify`를 부른 직후 장전을 풀어 둬서, 실제로 알림이 안 갔어도 다시 시도하지 않아요. 판정 구조(동기 `tick`)는 그대로 두고 실패 신고 길을 하나 열어요. 테스트 변경을 최소로 해요.
```swift
// DiskWatcher
/// 알림 센터가 전송을 거부했다. 장전을 되돌려 다음 회차에 다시 시도하게 한다.
public func deliveryFailed() { settings.armed = true }
```
```swift
// DiskAlertNotifier.post — Before
center.add(request) { _ in }
// After
center.add(request) { [weak self] error in
    guard error != nil else { return }
    Task { @MainActor in self?.watcher.deliveryFailed() }
}
```
또 `post` 직전에 권한이 꺼졌는지 보려고 `refreshAuthorization()`을 `tick` 전에 부르지는 않아요. 앱이 활성화될 때마다 이미 다시 묻고 있어서 충분해요.

### 2-2. 감시기가 사라져도 Task가 안 끝나는 문제(⚪) — `DiskWatcher.swift`
```swift
// Before
while !Task.isCancelled { self?.tick(); try? await Task.sleep(for: interval) }
// After
while !Task.isCancelled {
    guard let self else { return }
    self.tick()
    try? await Task.sleep(for: interval)   // sleep 동안은 self를 붙잡지 않도록 아래 한 줄로 분리
}
```
`guard let self`는 반복마다 새로 잡으므로, sleep 직전 `self`를 놓기 위해 `tick`만 짧은 스코프로 감싸요:
```swift
while !Task.isCancelled {
    guard let alive = self else { return }
    alive.tick()
    try? await Task.sleep(for: interval)
}
```
(Swift 6 엄격 동시성에서 컴파일되는 쪽을 쓰고, 안 되면 `[weak self]` 유지 + `guard self != nil` 로 바꿔요.)

### 2-3. 테스트 — `DiskWatcherTests.swift`
- 알림이 가고 `deliveryFailed()`가 불리면 다음 `tick()`에서 같은 상황이라도 다시 알린다.
- 성공하면(신고 없음) 다시 알리지 않는다(기존 테스트 유지).

### 2-4. PR 본문
`gh pr edit 25`로 본문에 범위를 적어요: "이번 PR은 디스크 부족 알림만 다룬다. 폭주 임시 파일 알림은 샌드박스에서 `/private/tmp`를 읽을 수 없어 제외했고, #17은 이 PR로 닫지 않는다." 본문 첫 줄의 `Closes #17`이 있으면 `Refs #17`로 바꿔요.

## 개발 Phase 계획

### Phase 1: PR #26 수정
**목표**: 폴더 빼기가 다른 접근을 안 닫고, 큰 파일 탐색 범위가 의도대로이고, 최근 작업 판정이 하위 파일을 본다.
- Step 1: 1-1 폴더 빼기 + 테스트 — `swift test --filter AppModelTests`/`FolderAccessTests` 통과
- Step 2: 1-2 UserFileWalker + 테스트 — `swift test --filter UserFileWalkerTests` 통과
- Step 3: 1-3 lastActivity + 테스트 — `swift test --filter ProjectArtifactTests` 통과, 전체 `swift test` 통과

### Phase 2: PR #25 수정
**목표**: 전송이 실패하면 다음 회차에 다시 알리고, 감시 Task가 감시기와 함께 끝난다.
- Step 1: 2-1·2-2 + 테스트 — `swift test --filter DiskWatcherTests` 통과, 전체 `swift test` 통과
- Step 2: 2-4 PR 본문 수정 — `gh pr view 25`에 범위 문구

## 검증
- 각 브랜치에서 `swift test` 전체. 실시간 커널을 읽는 `SystemCPULoadTests`·`ProcessCPUSamplerTests`는 부하가 높을 때 가끔 실패해서 단독 재실행해요.
- 새 테스트는 수정 전 코드에서 실패하는지 한 번 확인해요(1-1, 1-2, 2-1).
- 두 브랜치에 각각 푸시해 PR에 반영돼요. 머지는 하지 않아요.

## E2E 영향
- GUI e2e 없음. 단위·통합 테스트로 검증해요. 알림 권한·실제 알림 전송은 샌드박스 빌드에서 사람이 눌러 봐야 확인할 수 있어서 이번 범위에서는 하지 않아요.
