---
name: sweep-release
description: Sweep을 App Store에 배포한다. PR을 main에 머지한 직후, 또는 사용자가 "배포", "릴리스", "스토어에 올려"라고 할 때 쓴다. 배포할지부터 묻고, 버전·앱 정보·업데이트 내용·스크린샷을 차례로 물어 릴리스 커밋을 만들면 GitHub Actions(.github/workflows/appstore.yml)가 App Store Connect에 올린다. 심사 제출은 하지 않는다.
---

# sweep-release — App Store 릴리스

질문은 전부 AskUserQuestion으로 하나씩 묻는다. 답을 받기 전에 다음 질문으로 넘어가지 않는다.
사용자에게 보이는 말은 한국어로 쓴다.

올라가는 길: 이 스킬이 main에 **릴리스 커밋**을 푸시 → `App Store` 워크플로가
`scripts/release-diff.sh`로 무엇이 바뀌었는지 보고 →
빌드 번호가 바뀌었으면 아카이브·업로드·태그 `v<버전>-<빌드>`, `fastlane/metadata`가 바뀌었으면
앱 정보, `fastlane/screenshots`가 바뀌었으면 스크린샷을 반영한다.

## 0. 배포할지 먼저 묻는다

다른 어떤 질문보다 먼저:

- 질문: "이번 머지를 App Store에 배포할까요?"
- 선택지: `배포한다` / `이번엔 안 한다`

`이번엔 안 한다`면 아무 파일도 바꾸지 않고 한 줄로 끝낸다.

배포한다면 준비를 확인한다. 하나라도 어긋나면 멈추고 무엇이 문제인지 말한다.

```bash
git switch main && git pull --ff-only
git status --short -- Sources fastlane scripts .github   # 비어 있어야 한다
gh secret list   # ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 셋이 있어야 한다
```

기준점 `BASE`: 마지막 릴리스 태그. 없으면 Info.plist 버전을 마지막으로 바꾼 커밋.

```bash
BASE=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null \
       || git log -1 --format=%H -G CFBundleShortVersionString -- Sources/SweepApp/Info.plist)
```

## 1. 버전

현재 값: `/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" -c "Print :CFBundleVersion" Sources/SweepApp/Info.plist`

- 질문: "버전을 어떻게 올릴까요? (지금 X.Y.Z)"
- 선택지: `패치 X.Y.(Z+1) (Recommended)`, `마이너 X.(Y+1).0`, `메이저 (X+1).0.0`
- 직접 입력은 Other로 받는다. 정수 1~3개를 점으로 이은 형식이 아니면 다시 묻는다.
  현재보다 낮거나 같으면 다시 묻는다. 승인된 버전에는 더 올릴 수 없다.

**빌드 번호는 묻지 않는다.** 늘 현재 값 + 1이다. 버전을 올려도 1로 되돌리지 않는다.
App Store는 이전에 받은 번호보다 큰 번호만 받는다(1.0.2 빌드 1이 거부된 적이 있다).

값은 한 줄씩 `sed`로 바꾼다. `PlistBuddy Set`은 파일을 다시 써서 주석과 키 순서를 망친다.

```bash
sed -i '' '/<key>CFBundleShortVersionString<\/key>/{n;s|<string>[^<]*</string>|<string>NEW_VERSION</string>|;}' Sources/SweepApp/Info.plist
sed -i '' '/<key>CFBundleVersion<\/key>/{n;s|<string>[^<]*</string>|<string>NEW_BUILD</string>|;}' Sources/SweepApp/Info.plist
bash scripts/make-archive.sh --check-only
```

## 2. 앱 정보 변경

- 질문(multiSelect): "바꿀 앱 정보가 있나요?"
- 선택지: `이름·부제`, `설명`, `키워드`, `프로모션 문구`. 없으면 고르지 않고 넘어가게 "없음"은 Other로 받는다.

고른 항목마다 사용자에게 무엇을 바꾸고 싶은지 묻고, `fastlane/metadata/ko/`와
`fastlane/metadata/en-US/`의 해당 파일을 **둘 다** 고친 초안을 보여 준 뒤 확인을 받는다.
영어는 앱 화면 용어(`Resources/Localizable.xcstrings`)와 같은 이름을 쓴다.

| 파일 | 제한 |
|---|---:|
| `name.txt` | 30자 |
| `subtitle.txt` | 30자 |
| `keywords.txt` | 100자, 쉼표 구분, 이름에 있는 낱말은 넣지 않는다 |
| `promotional_text.txt` | 170자 |
| `description.txt` | 4000자 |

제한을 넘으면 초안을 내기 전에 줄인다(`python3 -c 'print(len(open(f).read().strip()))'`).

## 3. 업데이트 내용 — 확정 전에는 진행하지 않는다

```bash
git log --no-merges --format='%h %s' "$BASE"..HEAD
```

사용자에게 보이는 변화만 고른다. 리팩터·테스트·문서·CI·빌드 번호 커밋은 뺀다.
`fastlane/metadata/{ko,en-US}/release_notes.txt`의 이전 문체(첫 줄 한 문장 + `• 제목 — 설명` 목록)를 따라
ko와 en-US 초안을 쓴다.

초안 전문을 보여 주고 묻는다.

- 질문: "업데이트 내용을 이대로 쓸까요?"
- 선택지: `확정` / `고쳐 줘`

`고쳐 줘`면 무엇을 고칠지 듣고 다시 보여 준다. **`확정`을 받을 때까지 4단계로 가지 않는다.**

## 4. 스크린샷

- 질문: "스크린샷을 바꿀까요?"
- 선택지: `그대로 둔다 (Recommended)`, `전부 다시 찍는다`, `특정 화면만 다시 찍는다`
- 특정 화면이면 다시 multiSelect로 묻는다. 선택지가 4개까지라 두 번에 나눠 묻는다.
  장면은 `store-summary`(스마트 스캔), `store-xcode`(정크), `store-large`(큰 파일), `store-duplicate`(중복), `store-diskmap`(디스크 맵), `store-cleaned`(정리 완료)다.

바꾼다면 아래 순서로 한다.

1. 현재 소스로 앱을 빌드한다: `bash scripts/make-app.sh`
2. 원본을 찍는다. Sweep 창이 잠깐씩 앞으로 뜬다고 먼저 말한다.
   `bash scripts/capture-store-shots.sh <장면...>` → `.build/store-captures/{ko,en}/`
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

## 5. 그 밖의 앱 정보

- 질문(multiSelect): "그 밖에 바꿀 정보가 있나요?"
- 선택지: `지원·마케팅 URL`, `개인정보 처리방침 URL`, `저작권`, `카테고리`. 없음은 Other로 받는다.

파일: `{ko,en-US}/support_url.txt`, `marketing_url.txt`, `privacy_url.txt`, `copyright.txt`,
`primary_category.txt`. 심사 담당자 정보(`review_information/`)는 공개 저장소라 저장소에 없다 —
바꾸려면 App Store Connect에서 직접 고치라고 안내한다.

## 6. 릴리스 커밋 → 워크플로 확인

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

## 참고

- 서명은 CI에서 API 키(관리자 권한, `ASC_KEY_ID`)로 받는다. 서명만 확인하려면
  `gh workflow run appstore.yml -f build=true -f dry_run=true`.
- 로컬에서 앱 정보를 App Store Connect 값으로 다시 맞추려면
  `ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_….p8 fastlane mac pull_metadata`.
- 절차 전체: `docs/APPSTORE.md`
