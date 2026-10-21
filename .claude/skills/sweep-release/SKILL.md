---
name: sweep-release
description: Sweep을 App Store에 배포한다. PR을 main에 머지한 직후, 또는 사용자가 "배포", "릴리스", "스토어에 올려"라고 할 때 쓴다. 배포 여부·버전·업데이트 내용·앱 정보·스크린샷을 탭 하나로 한 번에 물어 릴리스 커밋을 만들면 GitHub Actions(.github/workflows/appstore.yml)가 App Store Connect에 올린다. 심사 제출은 하지 않는다.
---

# sweep-release — App Store 릴리스

질문은 **한 번에** 띄운다 — AskUserQuestion 한 호출에 탭 4개(배포·버전 / 업데이트 / 앱 정보 / 스크린샷).
사용자가 좌우 키로 탭을 넘기며 고른다. 탭을 한 개씩 따로 묻지 않는다.
"없음"·"배포 안 함"처럼 고를 만한 답은 Other에 쓰게 하지 말고 **반드시 보기로** 둔다.
사용자에게 보이는 말은 한국어로 쓴다.

올라가는 길: 이 스킬이 main에 **릴리스 커밋**을 푸시 → `App Store` 워크플로가
`scripts/release-diff.sh`로 무엇이 바뀌었는지 보고 →
빌드 번호가 바뀌었으면 아카이브·업로드·태그 `v<버전>-<빌드>`, `fastlane/metadata`가 바뀌었으면
앱 정보, `fastlane/screenshots`가 바뀌었으면 스크린샷을 반영한다.

## 0. 준비 — 묻기 전에 읽기만 한다

이 단계에서는 파일을 하나도 바꾸지 않는다. 하나라도 어긋나면 묻지 말고 멈춰 무엇이 문제인지 말한다.

```bash
git switch main && git pull --ff-only
git status --short -- Sources fastlane scripts .github   # 비어 있어야 한다
gh secret list   # ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 셋이 있어야 한다
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" -c "Print :CFBundleVersion" Sources/SweepApp/Info.plist
```

기준점 `BASE`: 마지막 릴리스 태그. 없으면 Info.plist 버전을 마지막으로 바꾼 커밋.

```bash
BASE=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null \
       || git log -1 --format=%H -G CFBundleShortVersionString -- Sources/SweepApp/Info.plist)
git log --no-merges --format='%h %s' "$BASE"..HEAD
```

**설명문의 이름도 확인한다.** 이번 변경으로 사이드바 이름이 바뀌었거나 새 탭이 생겼으면
`grep -n "스마트 스캔\|정크\|디스크 맵\|Smart Scan\|Junk\|Disk Map" fastlane/metadata/*/description.txt`로 옛 이름이
남았는지 본다. 남았으면 앱 정보 탭 설명에 적어 사용자가 고르게 한다(스크린샷과 설명의 이름이 앱과 다르면
심사에서 지적받는다).

**업데이트 내용 초안을 여기서 미리 쓴다** (탭 미리보기에 넣어야 해서다).
사용자에게 보이는 변화만 고른다. 리팩터·테스트·문서·CI·빌드 번호 커밋은 뺀다.
`fastlane/metadata/{ko,en-US}/release_notes.txt`의 이전 문체(첫 줄 한 문장 + `• 제목 — 설명` 목록)를 따라
ko와 en-US를 쓴다. 파일에는 아직 쓰지 않는다.

## 1. 한 번에 묻기 — AskUserQuestion 1회, 탭 4개

| header | 질문 | 보기 (최대 4개) |
|---|---|---|
| 배포·버전 | 이번 머지를 App Store에 배포할까요? 한다면 버전은? (지금 X.Y.Z (B)) | `패치 X.Y.(Z+1) (Recommended)` / `마이너 X.(Y+1).0` / `메이저 (X+1).0.0` / `이번엔 배포 안 함` |
| 업데이트 | 업데이트 내용을 이대로 쓸까요? | `확정` / `고쳐 줘` — 두 보기 모두 `preview`에 ko·en 초안 전문 |
| 앱 정보 | 바꿀 앱 정보가 있나요? (multiSelect) | `없음` / `이름·부제·키워드` / `설명·프로모션 문구` / `URL·저작권·카테고리` |
| 스크린샷 | 스크린샷을 바꿀까요? | `그대로 둔다 (Recommended)` / `전부 다시 찍는다` / `특정 화면만 다시 찍는다` |

- 첫 탭이 배포 여부다. 다른 탭보다 앞에 둔다.
- 현재 버전이 아직 스토어에 나가지 않았으면(`v<현재버전>-*` 태그가 없고 빌드만 올라간 상태)
  `메이저` 대신 `X.Y.Z 그대로 (Recommended)`를 두고, `패치`의 Recommended는 뗀다.
- 버전 직접 입력만 Other 칸을 쓴다.

## 2. 답 처리

- `이번엔 배포 안 함` → 다른 탭 답은 버리고 아무 파일도 바꾸지 않고 한 줄로 끝낸다.
- 앱 정보에서 `없음`과 다른 항목을 같이 골랐으면 `없음`은 무시한다.
- 직접 입력 버전: 정수 1~3개를 점으로 이은 형식이 아니거나, 현재보다 낮으면 그 질문만 다시 묻는다
  (승인된 버전에는 더 올릴 수 없다).

### 후속 질문 — 필요한 것만 모아 AskUserQuestion 1회

아래 중 해당하는 것만 탭으로 묶어 한 번에 묻는다. 하나도 없으면 생략한다.

- 업데이트 `고쳐 줘` → "무엇을 고칠까요?" (Other 입력)
- 앱 정보 항목마다 → "무엇으로 바꿀까요?" (Other 입력)
- `특정 화면만` → 장면 multiSelect 2탭(보기 4개 제한):
  `store-summary`(스마트 스캔)·`store-xcode`(정크)·`store-large`(큰 파일)·`store-duplicate`(중복) /
  `store-diskmap`(디스크 맵)·`store-cleaned`(정리 완료)

답을 받아 초안을 고쳤으면, 고친 업데이트 내용·앱 정보 초안도 탭 하나씩 `preview`로 띄워
`확정` / `고쳐 줘`를 **한 번에** 묻는다.
**업데이트 내용이 `확정`되기 전에는 파일을 바꾸거나 커밋하지 않는다.**

## 3. 파일 반영

### 버전

**빌드 번호는 묻지 않는다.** 늘 현재 값 + 1이다. 버전을 올려도 1로 되돌리지 않는다.
App Store는 **버전이 달라도** 이전에 받은 번호보다 큰 번호만 받는다. 실제로 두 번 거부됐다:
1.0.2 (1), 그리고 2026-10-21 1.0.5 (1) — 업로드에서 `CFBundleVersion [1] ... must contain a higher
version than that of the previously uploaded version [8]` (오류 90061). 사용자 감각(새 버전이면 (1))과 다르니
그대로 따르지 말고 이 규칙을 지킨다.
`그대로`를 골랐고 그 빌드가 이미 올라가 있으면 Info.plist는 건드리지 않는다.

값은 한 줄씩 `sed`로 바꾼다. `PlistBuddy Set`은 파일을 다시 써서 주석과 키 순서를 망친다.

```bash
sed -i '' '/<key>CFBundleShortVersionString<\/key>/{n;s|<string>[^<]*</string>|<string>NEW_VERSION</string>|;}' Sources/SweepApp/Info.plist
sed -i '' '/<key>CFBundleVersion<\/key>/{n;s|<string>[^<]*</string>|<string>NEW_BUILD</string>|;}' Sources/SweepApp/Info.plist
bash scripts/make-archive.sh --check-only
```

### 업데이트 내용·앱 정보

확정된 초안을 `fastlane/metadata/ko/`와 `fastlane/metadata/en-US/`에 **둘 다** 쓴다.
영어는 앱 화면 용어(`Resources/Localizable.xcstrings`)와 같은 이름을 쓴다.

| 보기 | 파일 | 제한 |
|---|---|---:|
| 이름·부제·키워드 | `name.txt` / `subtitle.txt` | 30자 / 30자 |
| | `keywords.txt` | 100자, 쉼표 구분, 이름에 있는 낱말은 넣지 않는다 |
| 설명·프로모션 문구 | `description.txt` / `promotional_text.txt` | 4000자 / 170자 |
| URL·저작권·카테고리 | `support_url.txt`, `marketing_url.txt`, `privacy_url.txt`, `copyright.txt`, `primary_category.txt` | |
| (업데이트) | `release_notes.txt` | 4000자 |

제한을 넘으면 초안을 내기 전에 줄인다(`python3 -c 'print(len(open(f).read().strip()))'`).
심사 담당자 정보(`review_information/`)는 공개 저장소라 저장소에 없다 —
바꾸려면 App Store Connect에서 직접 고치라고 안내한다.

### 스크린샷

바꾼다면 아래 순서로 한다.

1. 현재 소스로 앱을 빌드한다: `bash scripts/make-app.sh`
2. 원본을 찍는다. Sweep 창이 잠깐씩 앞으로 뜬다고 먼저 말한다.
   `bash scripts/capture-store-shots.sh <장면...>` → `.build/store-captures/{ko,en}/`
   Stage Manager 때문에 `could not create image from window`나 썸네일 크기로 실패하면
   `.build/store-captures`를 지우고 **최대 3번까지** 다시 돌린다.
   en 캡처에 한국어가 남았으면 `StoreDemo.swift`의 가짜 데이터 문구가 실제 스캐너 문구와 다른 것이다 —
   같은 `String(localized:)` 키를 쓰게 고친다(`scripts/l10n.sh`는 StoreDemo를 번역 대상에서 빼서 이걸 못 잡는다).
   새 기능 탭이 생겼으면 `StoreDemo`에 가짜 데이터 장면(`store-<이름>`)을 더하고
   `scripts/capture-store-shots.sh`의 `ALL`과 `scripts/store-screenshots.json`에도 넣는다. 진짜 데이터를 쓰면
   이 Mac의 실제 프로그램·파일 이름이 스토어에 나간다.
3. **합성은 Codex에 맡긴다** (`codex` 스킬의 `codex exec` 패턴, `-s workspace-write`).
   프롬프트에 담을 것:
   - 원본 경로와 장면 목록
   - `python3 scripts/store-compose.py <장면...>`을 돌려 `fastlane/screenshots/{ko,en-US}/NN.png`를 만든다.
     아트디렉션과 카피(`scripts/store-screenshots.json`)를 바꾸지 않는다.
   - 결과를 한 장씩 열어 검수한다: 글자 깨짐·잘림, 창 경계, 2880×1800, ko 장에 영어 UI가 섞였거나 그 반대인지.
     문제가 있으면 고친 뒤 무엇을 고쳤는지 보고한다.
   - `Sources/**`, `Tests/**`, `fastlane/metadata/**`는 건드리지 않는다.
4. Codex가 끝나면 `git diff --stat fastlane/screenshots`로 다시 찍은 장면의 파일만 바뀌었는지 보고,
   컨택트 시트 `.build/store-sheet.png`를 직접 열어 확인한 뒤 사용자에게 보여 준다.
   - 질문: "이 스크린샷으로 갈까요?" / `확정` / `다시`

## 4. 릴리스 커밋 → 워크플로 확인

바뀐 파일만 하나씩 `git add`한다(`git add .` 금지). 커밋 규칙은 `~/.claude/rules/git-rules.md`를 따른다.

```bash
git add Sources/SweepApp/Info.plist fastlane/metadata/ko/release_notes.txt ...
git commit -m "$(cat <<'MSG'
chore: X.Y.Z (B) 릴리스 — 업데이트 내용·<바꾼 것> 반영
MSG
)"
git push origin main
```

푸시 후 워크플로를 끝까지 본다.

```bash
sleep 5; RUN=$(gh run list --workflow appstore.yml --limit 1 --json databaseId -q '.[0].databaseId')
gh run watch "$RUN" --exit-status
```

- 성공: 무엇이 올라갔는지(빌드/앱 정보/스크린샷), 태그, 그리고 **심사 제출은 사람이 App Store Connect에서 한다**고 보고한다.
  빌드는 업로드 뒤 처리에 몇 분~수십 분 걸린다.
- 실패: `gh run view "$RUN" --log-failed | tail -60`을 읽고 원인을 요약한다. 고칠 수 있으면 고치고,
  같은 빌드 번호로 다시 올리지 않도록 확인한 뒤 `gh workflow run appstore.yml -f build=true`처럼 수동 실행한다.
- **이전 버전이 심사에 제출돼 있으면(`WAITING_FOR_REVIEW`) 앱 정보·스크린샷을 올릴 수 없다.** deliver가 제출된
  버전을 수정 대상으로 잡아 이름을 새 버전으로 바꾸고, 스크린샷은 제출 뒤라 API로 못 지운다
  (`Can't Delete Screenshot After Submit for review`). 이제 워크플로의 `release_guard`가 deliver 전에 이걸 막고
  한국어 오류로 멈춘다. 손으로 지울 필요 없다:
  1. 0단계에서 `gh workflow run appstore.yml -f status=true`로 상태를 읽는다(로그에 버전별 상태가 나온다).
  2. 제출된 버전이 있으면 첫 질문 탭에 보기로 둔다: "심사 중인 X를 철회하고 올릴까요? (심사 순서를 잃어요)".
  3. 철회를 고르면 `gh workflow run appstore.yml -f metadata=true -f screenshots=true -f cancel_review=true`.
     철회는 사용자가 고를 때만 한다. 심사가 이미 진행 중(`IN_REVIEW`)이면 철회할 수 없으니 끝날 때까지 기다린다.
- 빌드 없이 수동 실행(`build=false`)하면 태그가 안 생긴다. 빌드가 이미 올라가 있으면
  `git tag v<버전>-<빌드> <릴리스 커밋> && git push origin v<버전>-<빌드>`로 직접 찍는다.

## 참고

- 서명은 CI에서 API 키(관리자 권한, `ASC_KEY_ID`)로 받는다. 서명만 확인하려면
  `gh workflow run appstore.yml -f build=true -f dry_run=true`.
- 로컬에서 앱 정보를 App Store Connect 값으로 다시 맞추려면
  `ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_….p8 fastlane mac pull_metadata`.
- 절차 전체: `docs/APPSTORE.md`
