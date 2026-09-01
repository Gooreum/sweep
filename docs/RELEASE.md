# 배포 절차

Sweep을 다른 Mac에서 경고 없이 열리는 상태로 만들어 내보내는 순서.

---

## 한 번만 하면 되는 준비 (2가지)

### 1. Developer ID Application 인증서

App Store 밖으로 직접 배포하려면 이 인증서가 있어야 한다.
`Apple Development`·`Apple Distribution`으로는 **공증(notarization)을 받을 수 없다.**

CSR은 이미 만들어져 있다 (`scripts/make-csr.sh`가 만들고 개인 키는 키체인에 넣음):

```
~/Desktop/SweepDeveloperID.certSigningRequest
```

포털에서:

1. https://developer.apple.com/account/resources/certificates/list
2. **+** 버튼
3. Software 목록에서 **Developer ID Application** 선택 → Continue
4. Profile Type은 **G2 Sub-CA (Xcode 11 or later)** 그대로
5. Choose File → 위 CSR 파일 올리기 → Continue
6. **Download** → 내려받은 `.cer` **더블클릭**

> 팀을 고르라고 하면 **LHW4ZX343L (MINGU SEO)** — 유료 멤버십이 붙은 팀이다.
> 다른 팀 `X2D5P4CHD8`에는 Developer ID를 만들 수 없다.
>
> "Developer ID" 항목이 아예 안 보이면 계정 역할이 **Account Holder**가 아니거나
> 개인(Individual) 계정이 아닌 것이다. 그 경우 팀 관리자에게 요청해야 한다.

확인:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

한 줄이라도 나오면 된 것이다. CSR을 만들 때 넣은 개인 키와 짝이 맞아야
여기 나타난다 — 안 나오면 다른 Mac에서 만든 CSR을 쓴 것이다.

### 2. 공증 자격 프로필

공증은 Apple 서버에 제출하는 것이라 로그인 정보가 필요하다.
**Apple ID 본 암호가 아니라 앱 전용 암호**를 쓴다.

앱 전용 암호 만들기: https://appleid.apple.com → 로그인 및 보안 → 앱 암호 → **+**

만든 뒤 한 번만 등록:

```bash
xcrun notarytool store-credentials sweep \
  --apple-id <Apple ID 이메일> \
  --team-id LHW4ZX343L \
  --password <방금 만든 앱 전용 암호>
```

확인:

```bash
xcrun notarytool history --keychain-profile sweep
```

---

## 배포할 때마다 하는 것

```bash
bash scripts/make-app.sh     # release 빌드 → dist/Sweep.app
bash scripts/sign-app.sh     # Developer ID + Hardened Runtime 서명
bash scripts/notarize.sh     # 공증 제출 → staple → dist/Sweep-<버전>.zip
```

각 스크립트는 준비물이 없으면 **무엇이 없고 어떻게 만드는지 말하고 멈춘다.**
ad-hoc 서명으로 조용히 대체하지 않는다 — 그러면 받는 사람이 열어 보고 나서야
막힌 것을 알게 된다.

버전을 올리려면 `Sources/SweepApp/Info.plist`의
`CFBundleShortVersionString`(사람이 보는 버전)과 `CFBundleVersion`(빌드 번호)을
고친다. 배포 ZIP 이름이 여기서 나온다.

---

## 확인

```bash
# 번들 구조·Info.plist 키·아이콘·서명
bash .ai-bouncer-tasks/2026-08-31/review-fixes/verifications/e2e-tests/09-app-bundle.sh

# 받는 사람 시점
spctl -a -vv -t install dist/Sweep.app
#   → accepted / source=Notarized Developer ID  이면 통과
```

---

## 알아둘 것

**전체 디스크 접근 권한.** 디스크 맵에서 `/`(이 Mac)를 고르면 `~/Library/Mail`
같은 보호 영역은 **"읽을 수 없음"**으로 나온다. 이건 정상이다 — 0바이트라고
거짓말하지 않기 위해서다. 전부 보려면 사용자가 시스템 설정 → 개인정보 보호 및
보안 → 전체 디스크 접근 권한에서 Sweep을 직접 켜야 한다. 앱이 대화로 요청할 수
있는 권한이 아니다.

**Desktop·Documents·Downloads**는 앱이 처음 접근할 때 macOS가 대화를 띄운다.
그 문구는 `Sources/SweepApp/Info.plist`의 `NS*FolderUsageDescription`에서 온다.

**서명을 바꾸면 권한이 초기화된다.** ad-hoc → Developer ID로 바뀌면 macOS가
다른 앱으로 보고 TCC 허용을 다시 묻는다. 정상이다.
