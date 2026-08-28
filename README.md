# Sweep

macOS 개발 머신의 디스크를 정리하는 앱.

Xcode 산출물, 개발 도구 캐시, **폭주 중인 임시 파일**, 중복 내려받기를 찾아
안전도별로 보여주고 휴지통으로 보낸다.

```
runawayTemp  safe    3.65 GB   /private/var/folders/mg
xcode        caution 5.76 GB   ~/Library/Developer/Xcode/iOS DeviceSupport/...
xcode        safe    1.24 GB   ~/Library/Developer/Xcode/DerivedData/...
xcode        danger  234.5 MB  ~/Library/Developer/Xcode/Archives/2026-03-26
duplicate    safe    16.2 MB   ~/Downloads/...
총 18개 · 11.38 GB
```

## 설계

### 화이트리스트 관문

`ProtectedPaths`가 모든 삭제의 관문이다. 블랙리스트가 아니라 **화이트리스트**라,
아래 루트의 *하위*가 아니면 전부 거부한다.

```
~/Library/Developer   ~/Library/Caches   ~/Downloads
/private/var/folders  /private/tmp
```

허용 루트 안이어도 프로비저닝 프로파일·키바인딩·테마는 deny-list로 막는다.
경로 비교는 문자열 접두사가 아니라 구성요소 단위라 `~/Downloads-backup`을
`~/Downloads`의 하위로 오판하지 않는다. 심볼릭 링크가 허용 범위 밖을 가리키면
실경로를 풀어 거부한다.

관문은 **두 번** 통과한다. `ScanCoordinator`가 스캔 결과를 거르고,
`Remover`가 삭제 직전 다시 검증한다. 스캐너 버그가 삭제까지 이어지면 안 된다.

### 안전도

"다시 만들 수 있는가"로 나눈다. **safe만 기본 선택**되므로,
전체 선택 후 삭제를 눌러도 되돌릴 수 없는 것은 빠져 있다.

| | 뜻 | 예 |
|---|---|---|
| `safe` | 재생성된다 | DerivedData, 각종 캐시 |
| `caution` | 다시 받을 수 있지만 시간이 든다 | iOS DeviceSupport |
| `danger` | 대체물이 없다 | Archives (앱 심사 제출본) |

### 폭주 임시 파일 탐지

"큰 파일"이 아니라 **"커지고 있는 파일"**을 찾는다.
크기를 두 번 재서 증가분을 분당 속도로 환산한다 (`33.0 MB/분 증가 중`).
증가 중이면 무언가 쓰고 있다는 뜻이라 `caution`으로 둔다.

### 중복 탐지

크기 → 앞 64KB SHA256 → 전체 SHA256 3단계.
크기가 다르면 내용이 같을 수 없으므로 1단계에서 해시 비용을 크게 아낀다.
같은 내용 N개 중 가장 먼저 받은 1개는 원본으로 남긴다.

## 실행

```bash
swift run SweepApp              # GUI
swift run SweepApp --scan-only  # 창 없이 스캔 결과만 출력 (아무것도 지우지 않음)
swift test                      # 99개 테스트
```

## 구조

```
SweepKit/
  Safety/      ProtectedPaths      — 삭제 관문
  Model/       CleanupItem, SafetyLevel, ScanCategory
  Scan/        CleanupScanner 프로토콜 + 스캐너 4종 + ScanCoordinator
  Remove/      Remover, RemovalReport
  Presentation/ScanModel           — SwiftUI 비의존 상태 관리
SweepApp/      SwiftUI 화면
```

`CleanupScanner`가 `Scanner`가 아닌 이유는 `Foundation.Scanner`와 충돌하기 때문이다.

## 요구사항

macOS 14+ / Swift 6
