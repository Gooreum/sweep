# App Store 제출

Mac App Store로 내보내는 절차. **직접 배포(`docs/RELEASE.md`)와는 다른 트랙이다** —
인증서도, 산출물도, 앱이 할 수 있는 일도 다르다.

---

## 먼저 읽을 것: 샌드박스가 기능 대부분을 막는다

App Store는 **App Sandbox가 필수**다. 끄면 업로드 검증에서 막힌다.
켜면 Sweep이 들여다보는 곳(`ProtectedPaths.allowedRoots`) 6곳 중 5곳이 차단된다.

| 정리 루트 | 직접 배포 | App Store (샌드박스) |
|---|---|---|
| `~/Library/Caches` (남의 앱 캐시) | ✅ | ❌ **여는 entitlement가 없다** |
| `~/Library/Developer` (Xcode DerivedData) | ✅ | ❌ |
| `~/Library/Logs` | ✅ | ❌ |
| `/private/tmp` | ✅ | ❌ |
| `/var/folders/…/C`,`/T` (앱 임시) | ✅ | ❌ |
| `~/Downloads` | ✅ | ✅ `files.downloads.read-write` |
| 디스크 맵 홈 전체 순회 | ✅ (전체 디스크 접근 권한) | ⚠️ 사용자가 **직접 고른 폴더**만 |

설정으로 뚫는 문제가 아니다. 남의 앱이 만든 파일을 여는 entitlement가 존재하지 않는다.
`temporary-exception.files.absolute-path.*`는 형식상 있지만 요즘 심사에서 이 용도로는
승인되지 않고, 넣으면 반려 사유만 늘어난다.

CleanMyMac이 App Store에 없고 DaisyDisk는 있는 이유가 이것이다 — DaisyDisk는
"사용자가 고른 폴더를 시각화"로 제품을 샌드박스에 맞췄다.

**그래서 App Store 빌드는 다운로드 폴더만 다룬다.** 앱이 실행 중에 샌드박스를 감지해
(`Sandbox.isActive`) 정크 파일 탭을 숨기고, "Sweep이 보는 곳"과 디스크 맵 시작 지점을
`~/Downloads` 하나로 줄인다. 직접 배포본은 샌드박스가 아니라 기능이 온전하다.

> 샌드박스 안에서 `~/Downloads`는 컨테이너 안의 **심볼릭 링크**다. 열거자는 링크 루트를
> 열지 못해서, 링크를 풀지 않으면 스캔 결과가 0개가 된다(`DownloadsFolder`가 푼다).
> 아카이브를 만들면 `Sweep.app/Contents/MacOS/Sweep --scan-only`로 실제 결과를 확인한다.

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

> **같은 빌드 번호는 두 번 못 올린다.** App Store Connect는 이미 받은
> `CFBundleVersion`을 거부한다. 업로드할 때마다 빌드 번호를 올려야 한다.

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
| 1.0.0 (2) | 2026-09-10 | `8bff69a`. TestFlight·심사에는 이 빌드를 쓴다 |

---

## 제출 (사람이 한다)

```bash
open dist/Sweep.xcarchive
```

Xcode Organizer가 열린다 → **Distribute App** → **App Store Connect** → **Upload**.

이 단계에서 Xcode가 하는 일: Apple Distribution으로 재서명, App Store 프로비저닝
프로파일 발급·삽입, `.pkg`로 감싸 업로드. 필요한 인증서(Mac Installer Distribution 포함)가
없으면 Xcode가 만들어 준다 — 계정이 로그인돼 있어야 한다.

### 그 전에 준비돼 있어야 하는 것

1. **App Store Connect에 앱 레코드** — https://appstoreconnect.apple.com → 앱 → **+**
   - 플랫폼 **macOS**, 번들 ID `com.gooreum.sweep`, SKU 아무 값
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
