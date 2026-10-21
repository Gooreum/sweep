# 개발 프로젝트 탭: 찾는 종류 넓히기와 안내 문구 고치기

## Context
개발 프로젝트 탭이 규칙표 6줄(`node_modules`, `target`×2, `Pods`, `build`(Gradle), `.build`)만 찾아서, 이 컴퓨터의 `~/Code`에서는 `node_modules`만 나와요. 같은 폴더에 `.next` 5개, `.venv` 6개, `dist` 10개, `build`(JS) 17개, `.expo` 3개가 있어요. 그리고 탭 설명 문장이 "node_modules·빌드 폴더"라고 예시 하나만 고정으로 적혀 있어서 더 좁게 읽혀요. 사용자가 "할 수 있는 건 다 해"라고 했어요.

**넣지 않는 것**: `__pycache__`(46개가 전부 몇 KB라 목록만 길어짐), `DerivedData`(정리할 파일 탭이 이미 다룸).

## 규칙표 확장 — `Sources/SweepKit/Safety/ProjectArtifactRule.swift`

규칙에 두 가지 성질을 더해요. 판정은 계속 이 표 하나로만 해서 스캐너·관문·큰 파일 탐색이 어긋나지 않아요.

| 성질 | 뜻 | 쓰는 곳 |
|---|---|---|
| `manifestsInside` | 짝 파일이 폴더 **안**에 있어야 한다 | `.venv`·`venv`의 `pyvenv.cfg` |
| `requiresIgnore` | 프로젝트의 `.gitignore`에 그 폴더가 적혀 있어야 한다 | `dist`, JS `build`, `vendor` |

```swift
// Before: 파일 옆에만 본다
if let manifest = rule.manifests.first(where: { isKind(project.appending(path: $0), S_IFREG) }) {
    return Match(rule: rule, manifest: manifest)
}
// After
let base = rule.manifestsInside ? url : project
if let manifest = rule.manifests.first(where: { isKind(base.appending(path: $0), S_IFREG) }),
   !rule.requiresIgnore || GitIgnore.lists(name, from: project) {
    return Match(rule: rule, manifest: manifest)
}
```

새 규칙(기존 6줄 뒤에 추가):

| 폴더 | 짝 파일 | 성질 | lock 파일(없으면 확인 필요) | 다시 만드는 법 |
|---|---|---|---|---|
| `.next` | `package.json` | | 없음 | `next build`로 다시 만들어요 |
| `.nuxt` | `package.json` | | 없음 | `nuxt build`로 다시 만들어요 |
| `.svelte-kit` | `package.json` | | 없음 | `vite dev`로 다시 만들어요 |
| `.expo` | `package.json` | | 없음 | `expo start`로 다시 만들어요 |
| `.gradle` | `build.gradle`·`build.gradle.kts`·`settings.gradle`·`settings.gradle.kts` | | 없음 | `gradle build`로 다시 만들어요 |
| `.dart_tool` | `pubspec.yaml` | | 없음 | `flutter pub get`으로 다시 만들어요 |
| `.venv`, `venv` | `pyvenv.cfg` | `manifestsInside` | `requirements.txt`·`poetry.lock`·`Pipfile.lock`·`uv.lock` | `python -m venv`로 만들고 패키지를 다시 설치해요 |
| `dist`, `build` | `package.json` | `requiresIgnore` | node와 같은 lock 4종 | `npm run build`로 다시 만들어요 |
| `vendor` | `composer.json` | `requiresIgnore` | `composer.lock` | `composer install`로 다시 설치해요 |
| `vendor` | `go.mod` | `requiresIgnore` | 없음 | `go mod vendor`로 다시 만들어요 |

`build`는 같은 이름의 규칙이 둘이 돼요(Gradle, JS). 먼저 맞는 쪽이 이겨요.

## `.gitignore` 판독 — 새 파일 `Sources/SweepKit/Safety/GitIgnore.swift`
```swift
enum GitIgnore {
    /// `name` 폴더가 프로젝트 쪽 `.gitignore`에 적혀 있는가.
    /// project부터 위로 최대 8단계, `.git`이 있는 폴더(저장소 루트)에서 멈춘다. 모노레포의
    /// 하위 패키지는 루트의 `.gitignore`가 정하기 때문이다.
    static func lists(_ name: String, from project: URL) -> Bool
    /// 한 파일의 줄들로 판정. 순수 함수라 파일 없이 테스트한다.
    static func matches(name: String, lines: [String], anchoredHere: Bool) -> Bool
}
```
규칙:
- 빈 줄·`#` 주석은 건너뛰어요.
- `name`, `name/`, `**/name`, `**/name/`은 어디서나 맞아요.
- `/name`, `/name/`은 그 `.gitignore`가 있는 폴더 바로 아래일 때만 맞아요.
- `!name`(부정)이 뒤에 나오면 마지막 줄이 이겨서 안 맞아요.
- 와일드카드(`dist*` 등)나 하위 경로(`dist/foo`)는 판단하지 않고 "적혀 있지 않음"으로 봐요. 모르면 안 잡아요.
- 256KB가 넘는 파일은 읽지 않아요.

## 안내 문구 — `Feature.swift`, `Localizable.xcstrings`
```swift
// Before
case .projects: String(localized: "코드 폴더에서 다시 설치하면 되살아나는 node_modules·빌드 폴더를 찾아요.")
// After
case .projects: String(localized: "코드 폴더에서 다시 설치하거나 다시 빌드하면 되살아나는 폴더(node_modules, target, Pods, .venv 등)를 찾아요.")
```
새 문구(탭 설명, 규칙 10줄의 다시 만드는 법)의 영어 번역을 같이 넣어요. README의 개발 프로젝트 줄도 맞춰요.

## 개발 Phase 계획

### Phase 1: 규칙 엔진
**목표**: 새 종류가 짝·`.gitignore` 조건대로만 잡히고, 관문과 큰 파일 탐색도 같은 판정을 쓴다.
- Step 1: `GitIgnore` + 단위 테스트 — `swift test --filter GitIgnore` 통과
- Step 2: 규칙 구조(`manifestsInside`, `requiresIgnore`)와 새 규칙 10줄 + 매칭·스캐너·관문 테스트 — `swift test --filter ProjectArtifact` 통과

### Phase 2: 문구·검증
**목표**: 안내 문구가 실제 범위를 말하고, 이 컴퓨터의 `~/Code`에서 종류별로 잡힌다.
- Step 1: 탭 설명·다시 만드는 법·README·영어 번역 — 번역 키 누락 0
- Step 2: 임시 스캔 테스트로 `~/Code` 결과를 종류별로 세어 눈으로 확인(커밋하지 않음), 전체 `swift test` 통과

## 검증
- 새 테스트는 수정을 빼면 실패하는지 확인해요(`.gitignore` 없는 `dist`는 안 잡힘, 있으면 잡힘).
- 임시 스캔 테스트로 `~/Code`를 훑어서 종류별 개수가 `find` 결과와 맞는지 대조해요. `dist`·`build`는 `.gitignore`에 적힌 것만 나와야 해요.
- 샌드박스 빌드를 `/Applications`에 설치해 탭을 직접 열어 봐요.
- 브랜치 `feat/project-artifact-kinds`로 PR을 열어요. 머지는 하지 않아요.

## 위험과 대응
- **`dist`·`build`**: 커밋된 결과물이거나 직접 만든 파일일 수 있어 `.gitignore`에 적힌 것만 잡아요. lock 파일이 없으면 "확인 필요"예요.
- **`.venv`**: 지우면 패키지를 다시 깔아야 하고 버전이 달라질 수 있어, lock 파일이 없으면 "확인 필요"예요. 폴더 안에 `pyvenv.cfg`가 없으면 가상환경이 아니라서 안 잡아요.
- **`vendor`**: Go는 커밋하는 경우가 많아 `.gitignore` 조건을 걸어요.
- **목록 길이**: 종류가 늘면 줄이 많아져요. 크기순이라 큰 것이 위에 와요.
- **스캔 시간**: 폴더 이름이 규칙표에 걸릴 때만 `.gitignore`를 읽어서 늘어나는 비용은 작아요.

## E2E 영향
GUI e2e 없음. 단위 테스트, `~/Code` 실측, 샌드박스 빌드 눈 확인.
