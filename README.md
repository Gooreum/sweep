# Sweep

macOS 개발 머신의 디스크를 정리하는 앱.

Xcode 산출물, 개발 도구 캐시, **폭주 중인 임시 파일**, 중복 내려받기를 찾아
안전도별로 보여주고 휴지통으로 보낸다.

지우는 것 말고 보기만 하는 화면이 둘 있다 — 디스크 맵과 CPU.

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
~/Library/Developer   ~/Library/Caches   ~/Library/Logs   ~/Downloads
~/.npm                ~/.expo            /private/var/folders   /private/tmp
```

`~/Library/Application Support`는 루트에 **없다.** 그 아래는 기본이 사용자 데이터라
통째로 열면 관문이 무너진다. 대신 끝 이름이 맞는 캐시 폴더만 연다 —
`Cache`·`Code Cache`·`GPUCache`·`Dawn*Cache`·`Service Worker/CacheStorage`.
`IndexedDB`·`Local Storage`·앱의 로컬 DB는 이름이 다르므로 계속 거부된다.

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

### CPU 탭은 보기만 한다

끝내는 버튼이 없다. **App Store 빌드에서는 남의 프로세스를 죽일 수 없기 때문이다.**
서명한 번들로 세 갈래를 모두 재 봤다:

| 시도 | 샌드박스 |
|---|---|
| `kill(pid, SIGTERM)` | `EPERM` — `(allow signal (target same-sandbox))`만 열려 있다 |
| `NSRunningApplication.terminate()` / `forceTerminate()` | 둘 다 `false` |
| Automation entitlement + Apple Event `quit` | `-600 "Application isn't running"` — 떠 있는데도 |

읽는 쪽은 열려 있지만 **`proc_listpids`는 막힌다**(실측 0개). 목록은
`sysctl KERN_PROC_ALL`로 얻는다. 누적 CPU 시간은 `proc_pidinfo`로 읽는데,
그 값은 나노초가 아니라 **Mach 절대시간**이라 환산해야 한다 — 빼먹으면
코어를 꽉 채운 프로세스가 2.4%로 찍힌다.

`proc_pid_rusage`는 처음부터 나노초를 주지만 쓸 수 없다. 샌드박스가
`process-info-rusage`를 자기 자신에게만 열어 둔다.

내 계정 소유만 읽힌다(실측 521개 중 322개). `ps`·`top`이 root 프로세스까지
보여 주는 것은 그 둘이 setuid root이기 때문이다.

### 중복 탐지

크기 → 앞 64KB SHA256 → 전체 SHA256 3단계.
크기가 다르면 내용이 같을 수 없으므로 1단계에서 해시 비용을 크게 아낀다.
같은 내용 N개 중 가장 먼저 받은 1개는 원본으로 남긴다.

## 실행

```bash
swift run SweepApp              # GUI
swift run SweepApp --scan-only  # 창 없이 스캔 결과만 출력 (아무것도 지우지 않음)
swift run SweepApp --cpu-only   # 창 없이 CPU 상위 프로세스만 출력
swift test                      # 569개 테스트
```

## 구조

```
SweepKit/
  Safety/      ProtectedPaths      — 삭제 관문
  Model/       CleanupItem, SafetyLevel, ScanCategory
  Scan/        CleanupScanner 프로토콜 + 스캐너 4종 + ScanCoordinator
  Remove/      Remover, RemovalReport
  Insight/     DiskMapModel, CPUModel — 지우지 않고 보기만 하는 화면의 모델
  Presentation/ScanModel           — SwiftUI 비의존 상태 관리
SweepApp/      SwiftUI 화면
```

`CleanupScanner`가 `Scanner`가 아닌 이유는 `Foundation.Scanner`와 충돌하기 때문이다.

## 요구사항

macOS 14+ / Swift 6
