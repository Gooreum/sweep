# App Store 제출

Mac App Store로 내보내는 절차. **직접 배포(`docs/RELEASE.md`)와는 다른 트랙이다** —
인증서도, 산출물도, 앱이 할 수 있는 일도 다르다.

---

## 먼저 읽을 것: 샌드박스에서는 폴더를 허락받아야 한다

App Store는 **App Sandbox가 필수**다. 끄면 업로드 검증에서 막힌다.
켜면 앱이 스스로 열 수 있는 곳은 `~/Downloads` 하나뿐이다 —
`files.downloads.read-write`가 여는 유일한 곳이다.

실측: 허락이 없으면 33.9GB 중 **384MB(1.1%)** 만 잡힌다.

```
$ APP_SANDBOX_CONTAINER_ID=test .build/release/SweepApp --scan-only
largeFile  caution  256.8 MB  ~/Downloads/coinness-ios-develop (1).zip
largeFile  caution  127.7 MB  ~/Downloads/coinness-ios-develop.zip
총 2개 · 384.5 MB
```

나머지는 **사용자가 열기 대화상자에서 고른 폴더**로 연다
(`files.user-selected.read-write` + `files.bookmarks.app-scope`).
남의 앱이 만든 파일을 앱이 알아서 여는 entitlement는 존재하지 않는다 —
`temporary-exception.files.absolute-path.*`는 형식상 있지만 요즘 심사에서
이 용도로는 승인되지 않고, 넣으면 반려 사유만 늘어난다.

CleanMyMac이 App Store에 없고 DaisyDisk는 있는 이유가 이것이다 — DaisyDisk는
"사용자가 고른 폴더를 시각화"로 제품을 샌드박스에 맞췄다.

### 허락 한 번이 무엇을 여는가

| 허락 폴더 | 켜지는 정리 루트 | 회수량(실측) |
|---|---|---:|
| `~` (홈 폴더) | 아래 전부 + `.Trash` · `.gradle/caches` · `.cargo/registry` · `.m2/repository` + 큰 파일·중복 파일용 홈의 보이는 폴더 | 미측정 |
| `~/Library` | `Library/Developer` · `Library/Caches` · `Library/Logs` + 앱 웹 캐시 + iOS 백업(`MobileSync/Backup`) · 메일 첨부 사본(`Mail Downloads`) | ~25 GB |
| `~/.npm` | `.npm` | ~7.7 GB |
| `~/.expo` | `.expo` | ~0.3 GB |
| 직접 추가한 폴더 | 그 폴더(큰 파일·중복 파일만, `RemovalScope.userFiles`) | — |

iOS 백업·메일 첨부·휴지통은 허락과 별개로 TCC가 막아 **전체 디스크 접근**이 있어야 읽힌다.

`~/Library`는 Finder에서 숨김이지만 `NSOpenPanel.directoryURL`로 지정하면 그 폴더가
선택된 채 열려서, 사용자는 "허용"만 누르면 된다. **맨 위 하나면 대부분 된다.**

### 허락받은 폴더를 루트로 쓰지 않는다

`~/Library`를 열어 줬다고 그것을 허용 루트에 넣으면 `~/Library/Safari`·`Mail`·
`Messages`가 전부 삭제 가능해진다. 그래서 루트 목록은 그대로 두고 **켜고 끄는 열쇠**로만
쓴다(`ProtectedPaths.roots(sandboxed:granted:)`).

- 허락 = "읽을 수 있는가" (`FolderAccess`)
- 루트 = "지워도 되는가" (`ProtectedPaths`)

두 축이 분리돼 있어 허락이 넓어져도 지울 수 있는 것은 넓어지지 않는다.

### 샌드박스에서 못 살리는 것

`/private/tmp`와 `/var/folders/*/C,T`(폭주 임시 파일)는 사용자가 열기 대화상자에서
고를 수 있는 경로가 아니다. 방법이 없다.

### 허락 흐름

- 정크 파일 탭은 허락이 하나도 없으면 **허락 화면**을 띄운다(`FolderAccessView`).
  폴더마다 한 줄이고, 이미 허락한 것은 체크로 표시한다
- 고른 폴더는 보안 범위 북마크로 저장해 다음 실행에서도 연다(`FolderAccess.Registry`)
- 접근은 프로세스 수명 동안 유지한다 — `stopAccessingSecurityScopedResource`를 부르지 않는다
- 빌드 3까지 쓰던 단일 키(`developerFolderBookmark`)는 새 키로 자동으로 옮겨진다.
  이미 허락한 사용자가 허락 화면을 다시 보지 않는다

> 샌드박스에서 `homeDirectoryForCurrentUser`는 컨테이너(`~/Library/Containers/<id>/Data`)다.
> SweepKit은 사용자 홈을 passwd 항목에서 읽는다(`Sandbox.userHome`). 그러지 않으면 허락한
> 폴더 대신 컨테이너를 훑고, 보호 목록(`denyList`)이 진짜 프로비저닝 프로파일을 지키지 못한다.

> 컨테이너 안의 `Downloads`는 진짜 폴더를 가리키는 **심볼릭 링크**라, 그 경로로 열거하면
> 0개가 된다(빌드 1의 버그). 지금은 진짜 홈을 써서 링크를 거치지 않고, `DownloadsFolder`가
> 링크를 푸는 방어로 남아 있다. 아카이브를 만들면
> `Sweep.app/Contents/MacOS/Sweep --scan-only`로 실제 결과를 확인한다.

---

## 아카이브 만들기

```bash
bash scripts/make-archive.sh
```

하는 일:

1. 아이콘 자산이 없으면 만든다 (`swift scripts/make-icon.swift --appiconset`).
   App Store는 **자산 카탈로그 안의 아이콘**을 요구한다 — `.icns`만으로는 막힌다
2. `tuist generate` → `Sweep.xcworkspace` (원본은 `Project.swift`, 프로젝트는 생성물이다)
3. `xcodebuild archive` → `dist/Sweep.xcarchive`
4. 결과물 번호가 소스와 같은지, App Sandbox가 붙었는지 확인한다

1~3 전에 **버전 검사**를 먼저 한다. 형식(정수 1~3개)이 틀리거나, 빌드 번호가 이미
올라간 번호 이하면 아카이브하지 않고 멈춘다.

아카이브는 **개발 서명**으로 만들어진다. 정상이다 — Apple Distribution 인증서는
Organizer의 Distribute App 단계에서 붙는다. 아카이브 단계에서 배포 인증서를 지정하면
`conflicting provisioning settings`로 실패한다.

버전을 올리려면 `Sources/SweepApp/Info.plist`의 `CFBundleShortVersionString`과
`CFBundleVersion`을 고친다. 직접 배포본과 같은 파일을 본다.

> **승인된 버전에는 더 못 올린다.** 1.0.0이 승인된 뒤 1.0.0 빌드 5를 올리자
> `CFBundleShortVersionString ... must contain a higher version`과
> `train version '1.0.0' is closed`로 막혔다. 기능을 바꿔 다시 낼 때는 버전부터 올린다.
>
> **같은 버전 안에서 같은 빌드 번호는 두 번 못 올린다.** App Store Connect는 이미 받은
> `CFBundleVersion`을 거부한다. 같은 버전을 다시 올릴 때는 빌드 번호를 올리고,
> 버전을 올리면 빌드는 1부터 다시 시작한다.

값은 파일을 직접 고친다. `PlistBuddy -c "Set ..."`은 파일을 다시 써서 주석을 지우고
키 순서를 바꾸므로 쓰지 않는다. 스크립트가 멈추면서 한 줄만 바꾸는 `sed` 명령을 알려준다.

```bash
bash scripts/make-archive.sh --check-only   # 번호만 확인 (아카이브 안 함)
bash scripts/make-archive.sh --verify-only  # 이미 만든 아카이브가 소스와 같은지만
```

**이미 올라간 번호는 Organizer 기록에서 읽는다.** Organizer는 업로드할 때마다
`~/Library/Developer/Xcode/Archives/*/*.xcarchive/Info.plist`의 `Distributions`에
`uploadedBuildNumber`를 남긴다. 이 Mac의 Organizer로 올린 것만 보이고, 다른 Mac이나
Transporter로 올린 번호는 모른다 — 그런 업로드를 했으면 App Store Connect에서 직접 확인한다.

**Distribute App의 "Manage Version and Build Number"는 끈다.** 켜 두면 번호가 겹칠 때
Organizer가 조용히 올려서 업로드한다. 실제로 소스 빌드 1이 빌드 2로 올라가 소스와 어긋났다.

### 올라간 빌드

| 빌드 | 날짜 | 비고 |
|---|---|---|
| 1.0.0 (1) | 2026-09-08 | **쓰지 않는다** — 샌드박스에서 다운로드 폴더를 못 읽어 결과가 0개 |
| 1.0.0 (2) | 2026-09-10 | `8bff69a`. 다운로드 폴더만 — 정크 파일 탭이 없다 |
| 1.0.0 (3) | 2026-09-14 | `40ce256`. 개발 폴더 허락으로 Xcode 정리 |
| 1.0.0 (4) | 2026-09-21 반려 | `58f76e6`. 정리 목록 행에 경로 표시(세 줄), 툴팁 제거, 행 재생성 비용 감소. 이름 `SweepMac` → 5.2.5 반려, 이름만 바꿔 같은 빌드로 재제출 |
| 1.0.1 (5) | 업로드 전 | 읽기 불가 파일 중복 오판 수정, 정리 기록·누적 확보 용량, 삭제 실패 시트·재시도 |
| 1.0.3 (9) | 2026-10-19 | `88c957a`. 휴지통 탭, 디스크 맵 삭제 판정, 정리 후 사용량 갱신 |

이후 빌드는 태그 `v<버전>-<빌드>`로 남는다(`git tag -l 'v*'`).

---

## 올리기 — GitHub Actions가 한다

PR을 main에 머지한 뒤 Claude가 `/sweep-release` 스킬(`.claude/skills/sweep-release/SKILL.md`)로
배포 여부·버전 / 업데이트 내용(확정 필수) / 앱 정보 / 스크린샷을 **탭 하나로 한 번에** 묻고,
답을 반영한 **릴리스 커밋**을 main에 푸시한다.
그 커밋을 `.github/workflows/appstore.yml`이 받아 올린다. **심사 제출은 사람이 한다.**

| 바뀐 것 | 워크플로가 하는 일 |
|---|---|
| `CFBundleVersion` (빌드 번호) | `make-archive.sh` → `upload-archive.sh` → 태그 `v<버전>-<빌드>` |
| `fastlane/metadata/**` | `fastlane mac metadata` — 이름·설명·키워드·업데이트 내용 등 |
| `fastlane/screenshots/**` | `fastlane mac metadata screenshots:true` — 스크린샷 교체 |

판정은 `scripts/release-diff.sh <이전> <새>`가 한다. 일반 머지는 이 경로를 건드리지 않아 워크플로가 돌지 않는다.

- **앱 정보 원본**은 `fastlane/metadata/{ko,en-US}`다. App Store Connect에서 고친 값은
  `fastlane mac pull_metadata`로 내려받아 커밋해야 다음 릴리스에서 덮어쓰이지 않는다.
  심사 담당자 연락처(`review_information/`)는 공개 저장소라 올리지 않는다.
- **스크린샷**은 `scripts/capture-store-shots.sh <장면...>`로 원본을 찍고
  `scripts/store-compose.py <장면...>`로 `fastlane/screenshots/{ko,en-US}/NN.png`를 만든다(합성은 Codex가 돌린다).

### 시크릿

| 이름 | 값 |
|---|---|
| `ASC_KEY_ID` | App Store Connect API 키 ID (`2V2Z827B4Q`, "GitHub Actions CI", 관리자) |
| `ASC_ISSUER_ID` | 같은 페이지 위쪽의 Issuer ID |
| `ASC_KEY_P8` | `base64 -i AuthKey_<ID>.p8` |

키는 **관리자 권한**이어야 한다. CI에는 Xcode 계정이 없어 이 키로 Apple Distribution·Mac Installer
인증서와 프로파일을 받는다(클라우드 서명). 서명만 확인: `gh workflow run appstore.yml -f build=true -f dry_run=true`.

### 손으로 올릴 때

```bash
bash scripts/make-archive.sh && bash scripts/upload-archive.sh   # Xcode 계정으로 서명
# 또는 open dist/Sweep.xcarchive → Organizer → Distribute App → App Store Connect → Upload
```

Organizer로 올리면 Xcode가 Apple Distribution으로 재서명하고, App Store 프로비저닝 프로파일을
발급·삽입한 뒤 `.pkg`로 감싸 업로드한다. 필요한 인증서(Mac Installer Distribution 포함)가 없으면 Xcode가 만들어 준다.

### 그 전에 준비돼 있어야 하는 것

1. **App Store Connect에 앱 레코드** — https://appstoreconnect.apple.com → 앱 → **+**
   - 플랫폼 **macOS**, 번들 ID `com.gooreum.sweep`, SKU 아무 값
   - 스토어 이름: **`Sweep: Disk Cleaner`**. 이름에 `Mac`·`macOS`·`iMac` 같은 Apple 상표를
     넣지 않는다 — `SweepMac`은 Guideline 5.2.5로 반려됐다(빌드 4, 2026-09-21).
     설명문 안의 "Mac용 앱"처럼 대상을 밝히는 표현은 된다
   - 번들 ID가 목록에 없으면
     https://developer.apple.com/account/resources/identifiers 에서 먼저 등록
2. **심사용 메타데이터** — 스크린샷(1280×800 이상), 설명, 키워드, 지원 URL,
   **개인정보 처리방침 URL**(필수), 연령 등급
   - 지원 URL: https://gooreum.github.io/sweep/
   - 개인정보 처리방침 URL: https://gooreum.github.io/sweep/privacy.html
   - 두 페이지의 원본은 `gh-pages` 브랜치다. 푸시하면 GitHub Pages가 다시 배포한다
3. **팀** — `LHW4ZX343L (MINGU SEO)`. 유료 멤버십이 붙은 팀이다

업로드 후 App Store Connect에서 빌드가 "처리 중"을 지나면 심사에 제출할 수 있다.
수출 규정 질문은 `Info.plist`의 `ITSAppUsesNonExemptEncryption=false`로 이미 답해 뒀다.

### 영어(미국) 등록 정보

해외 스토어용. 앱 화면 용어(`Resources/Localizable.xcstrings`)와 같은 이름을 쓴다 —
스크린샷과 설명의 기능 이름이 다르면 심사에서 "설명과 앱이 다르다"는 지적을 받는다.
App Store 판은 샌드박스라 **폴더를 허락받아야 찾는다**. 그 전제를 설명에서 숨기지 않는다.
키워드에는 이름에 이미 있는 낱말(developer·disk·cleaner)을 다시 넣지 않는다 — 이름도 검색에 잡혀서 칸만 버린다.

| 항목 | 제한 | 값 |
|---|---:|---|
| 이름 | 30 | `Sweep — Developer Disk Cleaner` |
| 부제 | 30 | `Clear Xcode & dev caches` |
| 키워드 | 100 | `xcode,deriveddata,simulator,cache,storage,space,npm,expo,cocoapods,duplicate,junk,free up,ssd` |

**프로모션 문구** (170자)

```
Reclaim gigabytes from Xcode DerivedData, simulators and developer caches. Every item is labeled by safety and goes to the Trash first, so you can undo.
```

**설명**

```
Sweep finds the space that development quietly eats up on your Mac — and shows you exactly what is safe to remove.

WHAT IT FINDS
• Junk Files — Xcode DerivedData, simulator caches, device support files, and developer tool caches such as npm, Expo, Swift Package Manager, CocoaPods, Homebrew, Yarn and pnpm
• Large Files — unusually large files in the folders you allow
• Duplicates — files with identical content; the original is always kept
• Disk Map — see what takes up space, sorted by size
• Smart Scan — check everything at once and see how much you can reclaim

SAFE BY DESIGN
• Every item is labeled Safe, Caution or Danger, with a short reason
• Items that can't be recreated, like App Store submission archives, are locked
• Sweep only works inside a fixed set of cleanup locations and never touches anything outside them
• Everything goes to the Trash first. Undo puts the last cleanup back where it was

HOW ACCESS WORKS
The App Store version runs in the macOS sandbox. Sweep can only look inside folders you allow once with the Open dialog — for example ~/Library for Xcode and app caches, or ~/.npm for npm. You can revoke access at any time.

Space is freed when you empty the Trash. Sweep tells you how much that will be.
```

**이번 버전의 새로운 기능**

```
• English localization
• Undo your last cleanup straight from the result screen
• Clearer guidance on emptying the Trash to actually free up space
```

---

## 확인

```bash
# 아카이브 안에 앱이 있고 버전이 맞는지
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
  dist/Sweep.xcarchive/Products/Applications/Sweep.app/Contents/Info.plist

# Organizer가 인식하는 아카이브인지 (ApplicationProperties가 있어야 한다)
plutil -p dist/Sweep.xcarchive/Info.plist

# 샌드박스가 실제로 붙었는지
codesign -d --entitlements - \
  dist/Sweep.xcarchive/Products/Applications/Sweep.app 2>&1 | grep app-sandbox
```

---

## 두 트랙의 관계

| | 직접 배포 | App Store |
|---|---|---|
| 문서 | `docs/RELEASE.md` | 이 문서 |
| 인증서 | Developer ID Application | Apple Distribution (+ Mac Installer) |
| 산출물 | `dist/Sweep-<버전>.zip` (공증·staple 완료) | `dist/Sweep.xcarchive` |
| 만드는 법 | `make-app.sh` → `sign-app.sh` → `notarize.sh` | `make-archive.sh` |
| 샌드박스 | 없음 (기능 온전) | 필수 (기능 제한) |
| 조회 | `xcrun notarytool history` | App Store Connect |

둘은 서로를 건드리지 않는다. `make-archive.sh`는 `dist/Sweep.app`과
`dist/Sweep-<버전>.zip`을 손대지 않고, `make-app.sh`는 아카이브를 손대지 않는다.
공증 제출 이력은 App Store Connect에 **뜨지 않는다** — 별개 서비스다.
