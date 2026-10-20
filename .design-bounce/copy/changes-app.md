# SweepApp 한국어 문구 변경표

화면에서 무엇을 할지 먼저 정하고 설명을 새로 썼어요. 로직, 레이아웃, 단축키, SAFE/REVIEW/DANGER 배지와 가짜 파일 이름은 그대로예요.

CPU의 코어 계산법과 측정 방식은 뺐어요. 보간값을 없앨 수 없다는 조건에 따라 CPU 구성 숫자와 최대 퍼센트는 짧은 기기 정보로만 남겼어요. 사용률이 높다고 고장이라고 단정하지 않고, 느릴 때 확인할 곳을 안내해요.

## 화면별 안전 확인

- 정리 확인: 휴지통에 보관하는 경우와 즉시 완전히 지우는 경우를 구분해요. 휴지통을 비우기 전 복구 가능, 비운 뒤 복구 불가, 빈 공간이 생기는 시점을 남겼어요.
- 위험 항목: 새로 만들 수 없는 파일의 개수와, 비운 뒤 필요하면 처음부터 다시 받아야 한다는 기존 안내를 남겼어요.
- iCloud: 완전 삭제 시 다른 기기에서도 함께 지워진다고 알려요.
- 실패 안내: 처리하지 못한 항목만 다시 시도해요. 복구 실패 파일은 휴지통에 남아 있고 Finder에서 되돌려 놓을 수 있어요.
- 큰 파일과 중복 파일: 실제 설명은 SweepKit에서 가져와요. 예시 설명에는 받은 시점, 다시 받는 조건, 남겨 둘 원본을 남겼어요.
- 폴더 허용: 허용해야 볼 수 있는 범위를 유지해요. 관리자 소유 항목은 남기며 Finder에서 Mac 암호로 지우는 절차를 안내해요.

Info.plist의 기본 영어 권한 안내도 사용자 행동 중심으로 바꿨어요. Sweep.entitlements에는 사용자에게 보이는 권한 안내가 없어 그대로 두었어요. SweepApp.swift의 한국어는 로그와 헤드리스 출력이라 제외했어요. RootMenu, Theme, PrivacySettings 등 주석에만 한국어가 있는 파일도 그대로예요.

## 변경과 유지

| 파일 | 이전 | 이후 | 남긴 안전 사실 |
|---|---|---|---|
| Sources/SweepApp/CPUView.swift | 사용률 ▼ | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CPUView.swift | 프로그램과 위치 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CPUView.swift | 번호 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CPUView.swift | 위치·복사 | 파일 위치 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/CPUView.swift | 프로그램 사용률은 활성 상태 보기처럼 코어 하나를 100%로 세요. 여러 코어를 함께 쓰면 100%를 넘고, 모두 합치면 최대 \(model.cores * 100)%예요. | 숫자가 클수록 컴퓨터를 많이 쓰고 있어요. 100%를 넘어도 고장은 아니에요. 이 Mac에서는 최대 \(model.cores * 100)%까지 나와요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/CPUView.swift | 왼쪽은 Mac 전체를 100%로 봐요. 프로그램 실행, Mac 기본 작동, 쉬는 몫을 나눠 보여줘요. | 퍼센트 기준은 활성 상태 보기와 같아요. Mac이 느리다면 오른쪽에서 많이 쓰는 프로그램을 확인해 보세요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/CPUView.swift | 활성 상태 보기 열기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CPUView.swift | CPU 안에는 계산을 나눠 하는 코어가 \(model.cores)개 있어요. 빠른 계산용 \(performance)개와 전기를 덜 쓰는 \(efficiency)개예요. | 어떤 프로그램이 컴퓨터를 바쁘게 하는지 살펴보세요. CPU 정보는 총 \(model.cores)개, 성능 \(performance)개, 효율 \(efficiency)개예요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/CPUView.swift | CPU 안에는 계산을 나눠 하는 코어가 \(model.cores)개 있어요. | 어떤 프로그램이 컴퓨터를 바쁘게 하는지 살펴보세요. CPU 정보는 총 \(model.cores)개예요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/CPUView.swift | CPU 사용량 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CPUView.swift | 많이 쓰는 프로그램 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CPUView.swift | 막대가 꽉 차면 코어 하나 이상을 쓰고 있어요. 100%는 코어 하나, 200%는 두 개를 온전히 쓰는 양이에요. | 막대가 길수록 많이 쓰고 있어요. 꽉 찬 막대끼리는 옆의 숫자를 비교해 보세요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/CPUView.swift | 사용 중 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CPUView.swift | 프로그램 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CPUView.swift | Mac 작동 | 시스템 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/CPUView.swift | 쉬는 중 | 여유 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/CPUView.swift | 측정 중… | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CPUView.swift | Mac 전체 CPU 사용량을 읽지 못했어요. | 지금은 Mac이 얼마나 바쁜지 확인할 수 없어요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/CPUView.swift | kernel_task, WindowServer 등 목록 밖 합계 | kernel_task, WindowServer 등 나머지 합계 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/CPUView.swift | 프로그램 사용률순 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CPUView.swift | 측정 중… | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CPUView.swift | 사용률을 계산하려고 두 번 재고 있어요. | 잠시 기다리면 많이 쓰는 프로그램부터 보여드려요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/CPUView.swift | 지금 CPU를 쓰는 프로그램이 없어요. | 지금은 표시할 프로그램이 없어요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/CPUView.swift | 방금 측정한 동안에는 계산한 일이 없어요. | 컴퓨터를 쓰기 시작하면 여기에 나타나요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/CPUView.swift | Finder에서 보기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CPUView.swift | 위치 복사 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CPUView.swift | Mac 시스템 계정으로 실행되거나 잠깐 실행됐다 끝난 프로그램의 합계예요. App Store 앱은 보안 때문에 각각의 사용량을 볼 수 없어요. | Mac을 움직이는 프로그램과 잠깐 실행된 프로그램을 합친 값이에요. App Store 버전에서는 각각 나눠 볼 수 없어요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/DiskMapView.swift | 확인 필요. 휴지통으로 옮길까요? | 내용을 확인한 뒤 옮길까요? | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/DiskMapView.swift | 휴지통으로 옮길까요? | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 휴지통으로 옮기기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 취소 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | \(node.formattedSize) · \(node.url.path) | 크기는 \(node.formattedSize)이에요. 위치는 \(node.url.path) | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/DiskMapView.swift | 옮기지 못했어요 | 휴지통 이동 실패 | 휴지통 이동과 완전 삭제 구별 |
| Sources/SweepApp/DiskMapView.swift | 확인 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 다른 폴더를 골랐어요 | 필요한 폴더와 달라요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/DiskMapView.swift | 확인 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 지금은 다운로드 폴더만 볼 수 있어요 | 다운로드 폴더부터 보여드려요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/DiskMapView.swift | 디스크 접근을 허용하면 내 사용자 폴더와 이 Mac 전체를 볼 수 있어요. | 다른 곳도 보려면 디스크를 허용해 주세요. 내 폴더와 Mac 전체를 살펴볼 수 있어요. | 허용 여부에 따른 확인 범위 유지 |
| Sources/SweepApp/DiskMapView.swift | 디스크 허용… | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 선택하세요 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 선택하세요 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 시작 지점 | 볼 폴더 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/DiskMapView.swift | 재는 중에는 바꿀 수 없어요. 중단하면 고를 수 있어요. | 다른 곳을 보려면 먼저 중단을 눌러 주세요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/DiskMapView.swift | 위로 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 위로 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 다시 읽기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 다시 읽기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | \(scanned.formatted())개 세는 중… | \(scanned.formatted())개 확인했어요… | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/DiskMapView.swift | 사용량을 재는 중… | 어디에 공간을 쓰는지 확인 중… | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/DiskMapView.swift | 중단 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | \(current.name)에는 더 나눌 항목이 없어요 | \(current.name) 안에 표시할 항목이 없어요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/DiskMapView.swift | 검색을 멈췄어요 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 다시 검색하면 처음부터 세요. | 이 폴더를 보려면 다시 검색해 주세요. 처음부터 확인해요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/DiskMapView.swift | 다시 검색 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 시작 지점을 고르세요 | 어느 폴더를 볼까요? | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/DiskMapView.swift | 내 사용자 폴더, 디스크 전체, 응용 프로그램도 살펴볼 수 있어요. | 위에서 폴더를 골라 주세요. 내 폴더나 Mac 전체, 응용 프로그램의 크기를 볼 수 있어요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/DiskMapView.swift | 디스크 사용량 | 공간 사용량 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/DiskMapView.swift | 지워도 됨: 다시 생기는 임시 파일과 앱 활동 기록. 확인 필요: 내 파일과 앱 데이터. 보호됨: 시스템과 계정 데이터. | 임시 파일과 앱 사용 기록은 다시 생겨요. 내 파일과 앱 데이터는 내용을 보고 골라 주세요. 시스템과 계정 데이터는 보호해요. | 재생성 또는 다시 받는 조건 유지, 보호 대상은 이동하지 않음 |
| Sources/SweepApp/DiskMapView.swift | 접근이 허용되지 않은 폴더가 있어요 | 아직 열어 보지 못한 폴더가 있어요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/DiskMapView.swift | 시스템 설정 열기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 용량 확인 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 권한 없음 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 열기… | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | Finder에서 보기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 위치 복사 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 접근이 허용되지 않아 안을 볼 수 없어요 | 폴더를 허용해야 내용을 확인할 수 있어요 | 허용 여부에 따른 확인 범위 유지 |
| Sources/SweepApp/DiskMapView.swift | 휴지통으로 옮기기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | Finder에서 보기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 위치 복사 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 휴지통으로 옮기기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 권한 없음 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/DiskMapView.swift | 접근이 허용되지 않아 안을 볼 수 없어요 | 폴더를 허용해야 내용을 확인할 수 있어요 | 허용 여부에 따른 확인 범위 유지 |
| Sources/SweepApp/ScanButton.swift | 검색 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/ScanButton.swift | 검색 중… | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FolderAccessView.swift | 정리할 폴더 열기 | 어디에서 찾을까요? | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FolderAccessView.swift | App Store 앱은 보안 때문에 폴더를 마음대로 열 수 없어요. 처음 한 번 접근을 허용해 주세요. | 파일을 찾으려면 폴더를 열 수 있어야 해요. 아래에서 찾을 곳을 허용해 주세요. | 허용 여부에 따른 확인 범위 유지 |
| Sources/SweepApp/FolderAccessView.swift | 맨 위 하나만 허용해도 대부분 찾을 수 있어요. | 대부분은 맨 위 폴더 안에 있어요. 우선 그곳부터 열어 주세요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FolderAccessView.swift | 허락할 폴더 | 찾을 폴더 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FolderAccessView.swift | 다른 폴더를 골랐어요 | 필요한 폴더와 달라요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FolderAccessView.swift | 확인 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FolderAccessView.swift | 허용됨 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FolderAccessView.swift | 열기… | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/RemovalFailuresSheet.swift | 실패한 이유를 확인하고 해결한 뒤, 실패한 항목만 다시 시도할 수 있어요. | 아래 항목은 처리되지 않았어요. 항목마다 안내한 조치를 마친 뒤 이것들만 다시 시도해 주세요. | 실패 항목이 처리된 것으로 오해하지 않게 안내 |
| Sources/SweepApp/RemovalFailuresSheet.swift | \(failed.count)개 항목을 옮기지 못했어요 | 정리되지 않은 항목이 \(failed.count)개 있어요 | 휴지통 이동과 완전 삭제 구별 |
| Sources/SweepApp/RemovalFailuresSheet.swift | 전체 디스크 접근 설정 열기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/RemovalFailuresSheet.swift | 휴지통 열기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/RemovalFailuresSheet.swift | 닫기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/RemovalFailuresSheet.swift | 실패한 것만 다시 시도 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/RemovalFailuresSheet.swift | 닫기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/RemovalFailuresSheet.swift | 휴지통을 열지 못했어요 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/RemovalFailuresSheet.swift | 확인 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/RemovalFailuresSheet.swift | 화면 아래 Dock에서 휴지통을 열고 ‘되돌려 놓기’를 선택하세요. | 화면 아래 휴지통을 직접 열어 주세요. 파일을 고르고 ‘되돌려 놓기’를 누르면 원래 자리로 돌아가요. | 휴지통 이동과 완전 삭제 구별 |
| Sources/SweepApp/RemovalFailuresSheet.swift | Finder에서 보기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/RemovalFailuresSheet.swift | \(failed.count)개를 되돌리지 못했어요 | \(failed.count)개는 아직 복구되지 않았어요 | 복구 실패와 휴지통 잔류를 구별 |
| Sources/SweepApp/RemovalFailuresSheet.swift | 휴지통에 남아 있어요. Finder의 휴지통에서 직접 ‘되돌려 놓기’를 할 수 있어요. | 파일은 휴지통 안에 그대로 있어요. 휴지통을 열고 파일을 골라 ‘되돌려 놓기’를 눌러 주세요. | 휴지통 이동과 완전 삭제 구별 |
| Sources/SweepApp/ItemRow.swift | Finder에서 보기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/ItemRow.swift | 위치 복사 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FullDiskAccessBanner.swift | 켜면 앱 임시 파일까지 찾을 수 있어요. ‘다른 앱의 데이터’에 접근할지 더는 묻지 않아요. | 앱의 임시 파일도 찾으려면 설정에서 Sweep을 켜 주세요. 이후에는 다른 앱의 데이터를 열 때마다 허락을 묻지 않아요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FullDiskAccessBanner.swift | 전체 디스크 접근이 꺼져 있어요 | 더 찾으려면 접근을 허용해 주세요 | 허용 여부에 따른 확인 범위 유지 |
| Sources/SweepApp/FullDiskAccessBanner.swift | 시스템 설정 열기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/MenuBarPanel.swift | 휴지통을 열지 못했어요 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/MenuBarPanel.swift | 확인 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/MenuBarPanel.swift | 화면 아래 Dock에서 휴지통을 열어 비워 주세요. | 화면 아래 휴지통을 직접 열어 주세요. 비우면 되돌릴 수 없으니 안에 있는 파일을 먼저 확인해 주세요. | 완전 삭제 후 복구 불가, 휴지통 이동과 완전 삭제 구별 |
| Sources/SweepApp/MenuBarPanel.swift | 디스크 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/MenuBarPanel.swift | \(Int(usage.usedFraction * 100))% 사용됨 | 유지: 개수와 진행 상태를 짧게 표시해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/MenuBarPanel.swift | 사용 가능: \(usage.formattedAvailable)  전체: \(usage.formattedTotal) | 남은 공간은 \(usage.formattedAvailable)이에요. 전체는 \(usage.formattedTotal)이에요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/MenuBarPanel.swift | 검색 중 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/MenuBarPanel.swift | 정리 가능 | 정리 후보 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/MenuBarPanel.swift | \(row.formattedSize) · \(row.count)개 | \(row.count)개, \(row.formattedSize) | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/MenuBarPanel.swift | 아직 검색하지 않았어요 | 검색을 눌러 정리할 파일을 찾아보세요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/MenuBarPanel.swift | 휴지통 열기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/MenuBarPanel.swift | 검색 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/MenuBarPanel.swift | Sweep 열기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SweepCommands.swift | Sweep이 보는 곳 | 찾아볼 곳 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SweepCommands.swift | 기능 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SweepCommands.swift | 검색 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SweepCommands.swift | 검색 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SweepCommands.swift | 정리 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SelectionDock.swift | 선택: \(model.selectedItems.count)개, 전체 \(model.items.count)개 중 | 고른 항목 \(model.selectedItems.count)개, 찾은 항목 \(model.items.count)개 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SelectionDock.swift | 선택 크기: \(model.formattedSelectedSize) | 고른 용량: \(model.formattedSelectedSize) | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SelectionDock.swift | 고른 항목은 바로 지워져 되돌릴 수 없어요. | 휴지통에서 완전히 지워요. 복구할 수 없어요. | 완전 삭제 후 복구 불가, 휴지통 이동과 완전 삭제 구별 |
| Sources/SweepApp/SelectionDock.swift | 휴지통을 비우기 전까지 되돌릴 수 있어요. | 옮긴 파일은 휴지통에 남아요. 비우기 전에는 복구할 수 있어요. | 휴지통 이동과 완전 삭제 구별, 실패 항목이 처리된 것으로 오해하지 않게 안내 |
| Sources/SweepApp/SelectionDock.swift | 선택한 항목 없음 | 파일을 골라 주세요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SelectionDock.swift | 선택 항목 영구 삭제 | 선택 항목 완전 삭제 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SelectionDock.swift | \(count)개 | 유지: 개수와 진행 상태를 짧게 표시해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SelectionDock.swift | \(level.dockLabel) \(count)개 | 유지: 개수와 진행 상태를 짧게 표시해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SelectionDock.swift | 다시 만들 수 있음 | 다시 생김 | 재생성 또는 다시 받는 조건 유지 |
| Sources/SweepApp/SelectionDock.swift | 확인 필요 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SelectionDock.swift | 되돌릴 수 없음 | 복구 불가 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/TrashLeftoverNotice.swift | \(first) 외 \(leftovers.count - 1)개 | 유지: 개수와 진행 상태를 짧게 표시해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/TrashLeftoverNotice.swift | 관리자 소유 항목 \(leftovers.count)개(\(names))는 Sweep이 지울 수 없어요 | \(names), 총 \(leftovers.count)개는 관리자 소유라 남겨 뒀어요 | 관리자 소유 항목은 남김 |
| Sources/SweepApp/TrashLeftoverNotice.swift | Finder에서 휴지통을 비우면 Mac 암호를 물은 뒤 지워요. | 이 항목은 Finder에서 휴지통을 비워야 지워져요. Mac 암호가 필요해요. 비운 뒤에는 복구할 수 없어요. | 완전 삭제 후 복구 불가, 휴지통 이동과 완전 삭제 구별, 빈 공간은 휴지통을 비운 뒤 생김 |
| Sources/SweepApp/TrashLeftoverNotice.swift | 휴지통 열기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/StageHarness.swift | 준비 중 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/StageHarness.swift | 준비 중 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/StageHarness.swift | 준비 중 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/StageHarness.swift | 준비 중 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/StageHarness.swift | 준비 중 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/StageHarness.swift | 준비 중 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/StageHarness.swift | Homebrew 내려받기 캐시 | Homebrew로 받은 임시 파일이에요. 다시 받을 때 생겨요 | 재생성 또는 다시 받는 조건 유지 |
| Sources/SweepApp/StageHarness.swift | 다시 만들 수 없음 | 다시 안 생김 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/StageHarness.swift | 비우면 되돌릴 수 없습니다 | 휴지통에서 완전히 지워요. 복구할 수 없어요 | 완전 삭제 후 복구 불가, 휴지통 이동과 완전 삭제 구별 |
| Sources/SweepApp/StageHarness.swift | 비우면 되돌릴 수 없습니다 | 휴지통에서 완전히 지워요. 복구할 수 없어요 | 완전 삭제 후 복구 불가, 휴지통 이동과 완전 삭제 구별 |
| Sources/SweepApp/StageHarness.swift | iCloud Drive 휴지통 — 비우면 다른 기기에서도 사라집니다 | iCloud Drive 파일이에요. 휴지통을 비우면 다른 기기에서도 지워져요 | iCloud 파일은 다른 기기에서도 삭제, 휴지통 이동과 완전 삭제 구별 |
| Sources/SweepApp/StageHarness.swift | 원래 자리에 같은 이름이 있습니다 | 같은 이름의 파일이 이미 있어요. 원래 자리로 옮기지 않았어요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/StageHarness.swift | 보호된 경로입니다: \(item.url.path) | 이곳은 보호하고 있어요. 파일을 옮기지 않았어요: \(item.url.path) | 보호 대상은 이동하지 않음 |
| Sources/SweepApp/StageHarness.swift | 실행 중인 앱입니다. 종료한 뒤 다시 시도해 주세요: \(item.url.path) | 앱이 켜져 있어 옮기지 않았어요. 앱을 종료하고 다시 시도해 주세요: \(item.url.path) | 실행 중 앱은 종료 후 재시도 |
| Sources/SweepApp/StageHarness.swift | 다시 만들 수 없음 | 다시 안 생김 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SmartScanView.swift | 정리 중 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | 정리하는 중 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | \(done)개 완료, 전체 \(total)개 | 유지: 개수와 진행 상태를 짧게 표시해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | 되돌리는 중 | 복구 중 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SmartScanView.swift | 원래 자리로 되돌리는 중 | 파일을 원래 자리에 놓고 있어요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SmartScanView.swift | \(done)개 완료, 전체 \(total)개 | 유지: 개수와 진행 상태를 짧게 표시해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | Mac 전체를 한 번에 검색해요 | 정리할 파일, 여기서 한번에 찾아보세요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SmartScanView.swift | Xcode가 앱을 만들 때 생긴 파일, 임시 파일, 큰 파일, 중복 파일을 기능별로 보여줘요. | 개발용 파일과 임시 파일부터 큰 파일과 중복 파일까지 찾아드려요. 결과를 보고 필요한 것만 골라 정리하세요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SmartScanView.swift | 전체 검색 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | 디스크 정보 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | 사용 가능 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | 사용됨 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | 전체 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | \(Int(usage.usedFraction * 100))% 사용됨 | 유지: 개수와 진행 상태를 짧게 표시해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | Sweep이 보는 곳 | 찾아볼 곳 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SmartScanView.swift | 이 밖은 건드리지 않아요 | 아래에 있는 곳만 찾아봐요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SmartScanView.swift | 접근이 허용되지 않아 읽을 수 없어요 | 폴더를 허용하면 여기서도 찾을 수 있어요 | 허용 여부에 따른 확인 범위 유지 |
| Sources/SweepApp/SmartScanView.swift | 열기… | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | 빼기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | 다른 폴더를 골랐어요 | 필요한 폴더와 달라요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SmartScanView.swift | 확인 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | 이 폴더는 추가할 수 없어요 | 찾을 곳에 넣지 못했어요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SmartScanView.swift | 확인 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | 폴더 추가 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | 외장 디스크 같은 다른 폴더에서도 큰 파일과 중복 파일을 찾아요 | 찾을 곳이 더 있나요? 폴더를 추가하면 큰 파일과 중복 파일을 함께 찾아요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SmartScanView.swift | 추가… | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | 해제 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | 열기… | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | 접근이 허용되지 않은 폴더가 있어요 | 아직 열어 보지 못한 폴더가 있어요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SmartScanView.swift | 시스템 설정 열기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | 정리 대상 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | Mac 전체를 검색하는 중… | 정리할 파일을 찾고 있어요… | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SmartScanView.swift | \(model.items.count)개 · \(model.formattedTotalSize) 발견 | 찾은 파일 \(model.items.count)개, \(model.formattedTotalSize) | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SmartScanView.swift | 정리 요약 | 찾은 파일 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SmartScanView.swift | 정리 가능 | 정리 후보 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/SmartScanView.swift | \(summary.breakdown.reduce(0) { $0 + $1.count })개 항목 | 유지: 개수와 진행 상태를 짧게 표시해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/SmartScanView.swift | \(row.count)개 | 유지: 개수와 진행 상태를 짧게 표시해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Sidebar.swift | 사용 가능 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Sidebar.swift | \(usage.formattedUsed) 사용됨 · 전체 \(usage.formattedTotal) | 사용 \(usage.formattedUsed), 전체 \(usage.formattedTotal) | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/StoreDemo.swift | \(months)개월 전에 받았어요 | 받은 지 \(months)개월 된 파일이에요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/StoreDemo.swift | \(original)와 내용이 같아요 | 남겨 둘 원본은 \(original)이에요. 내용이 같은 여분이에요 | 내용이 같은 여분이며 남겨 둘 원본 표시 |
| Sources/SweepApp/StoreDemo.swift | 기기를 다시 연결하면 내려받아요 | 지워도 기기를 연결할 때 다시 받아요 | 재생성 또는 다시 받는 조건 유지 |
| Sources/SweepApp/StoreDemo.swift | Xcode가 앱을 만들 때 다시 생겨요 | 지워도 Xcode로 개발하면 새로 만들어져요 | 재생성 또는 다시 받는 조건 유지 |
| Sources/SweepApp/StoreDemo.swift | 기기를 다시 연결하면 내려받아요 | 지워도 기기를 연결할 때 다시 받아요 | 재생성 또는 다시 받는 조건 유지 |
| Sources/SweepApp/StoreDemo.swift | Xcode가 앱을 만들 때 다시 생겨요 | 지워도 Xcode로 개발하면 새로 만들어져요 | 재생성 또는 다시 받는 조건 유지 |
| Sources/SweepApp/StoreDemo.swift | 앱 시험 도구의 임시 파일이에요 | 개발 중 앱을 실행하며 생긴 임시 파일이에요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/StoreDemo.swift | Xcode가 앱을 만들 때 다시 생겨요 | 지워도 Xcode로 개발하면 새로 만들어져요 | 재생성 또는 다시 받는 조건 유지 |
| Sources/SweepApp/StoreDemo.swift | 앱 심사 제출본이에요. 지우면 복구할 수 없어요 | 심사에 낸 앱을 보관한 파일이에요. 삭제하면 되살릴 수 없어요 | 완전 삭제 후 복구 불가 |
| Sources/SweepApp/StoreDemo.swift | \(12)일 전에 받았어요 | 받은 지 \(12)일 된 파일이에요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FeatureScreen.swift | 켜야 휴지통 안을 볼 수 있어요. 꺼져 있으면 비어 있는 것처럼 보여요. | 휴지통이 비어 보이나요? 전체 디스크 접근을 켜야 안에 있는 파일을 확인할 수 있어요. | 휴지통 이동과 완전 삭제 구별, 허용 여부에 따른 확인 범위 유지 |
| Sources/SweepApp/FeatureScreen.swift | 검색 중 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FeatureScreen.swift | \(feature.displayName) 검색 중… | 유지: 개수와 진행 상태를 짧게 표시해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FeatureScreen.swift | \(model.items.count)개 · \(model.formattedTotalSize) 발견 | 찾은 파일 \(model.items.count)개, \(model.formattedTotalSize) | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FeatureScreen.swift | 정리 중 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FeatureScreen.swift | 영구 삭제하는 중… | 휴지통에서 완전히 지우고 있어요… | 휴지통 이동과 완전 삭제 구별 |
| Sources/SweepApp/FeatureScreen.swift | 휴지통으로 옮기는 중… | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FeatureScreen.swift | \(done)개 완료, 전체 \(total)개 | 유지: 개수와 진행 상태를 짧게 표시해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FeatureScreen.swift | 되돌리는 중 | 복구 중 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FeatureScreen.swift | 원래 자리로 되돌리는 중… | 파일을 원래 자리에 놓고 있어요… | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FeatureScreen.swift | \(done)개 완료, 전체 \(total)개 | 유지: 개수와 진행 상태를 짧게 표시해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FeatureScreen.swift | 되돌리지 못했어요 | 복구 실패 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FeatureScreen.swift | 일부만 되돌렸어요 | 일부 복구 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FeatureScreen.swift | 되돌리기 완료 | 복구 완료 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FeatureScreen.swift | \(failed)개를 되돌리지 못했어요 | \(failed)개는 아직 복구되지 않았어요 | 복구 실패와 휴지통 잔류를 구별 |
| Sources/SweepApp/FeatureScreen.swift | \(restored)개, \(report.formattedReclaimed)를 원래 자리로 되돌렸어요 | 원래 자리에 파일 \(restored)개를 다시 놓았어요. 용량은 \(report.formattedReclaimed)예요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FeatureScreen.swift | 실패 이유 보기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FeatureScreen.swift | \(failed)개는 되돌리지 못했어요. 이유 보기 | 복구되지 않은 \(failed)개 확인하기 | 복구 실패와 휴지통 잔류를 구별 |
| Sources/SweepApp/FeatureScreen.swift | 완료 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FeatureScreen.swift | 정리할 항목이 없어요 | 이번에는 정리할 파일이 없어요 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FeatureScreen.swift | 정리할 만큼 큰 항목을 찾지 못했어요. | 찾아본 곳에는 정리 기준에 맞는 크기의 파일이 없어요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FeatureScreen.swift | 다시 검색 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FeatureScreen.swift | 정리하지 못했어요 | 정리 실패 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FeatureScreen.swift | 일부만 정리했어요 | 일부 정리 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FeatureScreen.swift | 정리 완료 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FeatureScreen.swift | \(failed)개를 삭제하지 못했어요 | \(failed)개는 지워지지 않고 남아 있어요 | 실패 항목이 처리된 것으로 오해하지 않게 안내 |
| Sources/SweepApp/FeatureScreen.swift | \(moved)개, \(report.formattedReclaimed)를 영구 삭제했어요 | 파일 \(moved)개를 완전히 지웠어요. \(report.formattedReclaimed)의 공간이 생겼고, 복구할 수 없어요. | 완전 삭제 후 복구 불가 |
| Sources/SweepApp/FeatureScreen.swift | \(failed)개를 휴지통으로 옮기지 못했어요 | \(failed)개는 휴지통으로 가지 않았어요 | 휴지통 이동과 완전 삭제 구별 |
| Sources/SweepApp/FeatureScreen.swift | \(moved)개, \(report.formattedReclaimed)를 휴지통으로 옮겼어요 | 파일 \(moved)개가 휴지통에 있어요. 옮긴 용량은 \(report.formattedReclaimed)예요. | 휴지통 이동과 완전 삭제 구별 |
| Sources/SweepApp/FeatureScreen.swift | 실패 이유 보기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FeatureScreen.swift | \(failed)개는 삭제하지 못했어요. 이유 보기 | 지워지지 않은 \(failed)개 확인하기 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FeatureScreen.swift | \(failed)개는 옮기지 못했어요. 이유 보기 | 옮겨지지 않은 \(failed)개 확인하기 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FeatureScreen.swift | 되돌리기 | 복구 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FeatureScreen.swift | 휴지통 열기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FeatureScreen.swift | 완료 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FeatureScreen.swift | 휴지통을 열지 못했어요 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FeatureScreen.swift | 확인 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FeatureScreen.swift | 화면 아래 Dock에서 휴지통을 열어 비워 주세요. | 화면 아래 휴지통을 직접 열어 주세요. 비우면 되돌릴 수 없으니 안에 있는 파일을 먼저 확인해 주세요. | 완전 삭제 후 복구 불가, 휴지통 이동과 완전 삭제 구별 |
| Sources/SweepApp/FeatureScreen.swift | 정리 항목 | 찾은 파일 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FeatureScreen.swift | 이 묶음 모두 선택하거나 해제하기 | 이 묶음 전체 고르기, 선택 풀기 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FeatureScreen.swift | \(group.items.count)개 | 유지: 개수와 진행 상태를 짧게 표시해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/ContentView.swift | 전체 검색 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/ContentView.swift | 검색 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/ContentView.swift | 안전 항목 선택 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CleanupConfirmSheet.swift | \(model.selectedItems.count)개 항목을 영구 삭제해요 | \(model.selectedItems.count)개를 완전히 지울까요? | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/CleanupConfirmSheet.swift | \(model.selectedItems.count)개 항목을 휴지통으로 옮겨요 | \(model.selectedItems.count)개를 휴지통에 보낼까요? | 휴지통 이동과 완전 삭제 구별 |
| Sources/SweepApp/CleanupConfirmSheet.swift | 취소 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CleanupConfirmSheet.swift | 영구 삭제 | 완전 삭제 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/CleanupConfirmSheet.swift | 취소 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CleanupConfirmSheet.swift | 휴지통으로 옮기기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CleanupConfirmSheet.swift | 휴지통에서 바로 지워져 되돌릴 수 없어요. 지운 만큼 공간이 바로 늘어나요. | 휴지통 안의 파일을 완전히 지워요. 복구할 수 없어요. 지운 용량만큼 바로 쓸 수 있어요. | 완전 삭제 후 복구 불가, 휴지통 이동과 완전 삭제 구별 |
| Sources/SweepApp/CleanupConfirmSheet.swift | 이 중 \(iCloudCount)개는 iCloud Drive 항목이라 다른 기기에서도 지워져요. | iCloud Drive에 있는 \(iCloudCount)개는 다른 기기에서도 함께 지워져요. | iCloud 파일은 다른 기기에서도 삭제 |
| Sources/SweepApp/CleanupConfirmSheet.swift | 이 중 \(riskyCount)개는 다시 만들 수 없어요. 휴지통을 비우면 처음부터 다시 받아야 해요. 비우기 전까지는 모두 되돌릴 수 있어요. 휴지통을 비워야 공간이 늘어나요. | 고른 파일은 휴지통에 보관해요. 비우기 전에는 모두 복구할 수 있어요. 이 중 \(riskyCount)개는 새로 만들 수 없는 파일이에요. 비운 뒤 필요해지면 처음부터 다시 받아야 해요. 빈 공간은 휴지통을 비워야 생겨요. | 휴지통 이동과 완전 삭제 구별, 빈 공간은 휴지통을 비운 뒤 생김, 재생성 또는 다시 받는 조건 유지 |
| Sources/SweepApp/CleanupConfirmSheet.swift | 휴지통을 비우기 전까지 되돌릴 수 있어요. 휴지통을 비워야 공간이 늘어나요. | 파일은 휴지통에 보관해요. 아직은 복구할 수 있어요. 휴지통을 비우면 복구할 수 없고, 그때 빈 공간이 생겨요. | 완전 삭제 후 복구 불가, 휴지통 이동과 완전 삭제 구별, 빈 공간은 휴지통을 비운 뒤 생김 |
| Sources/SweepApp/CleanupConfirmSheet.swift | 지울 항목 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CleanupConfirmSheet.swift | 옮길 항목 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CleanupConfirmSheet.swift | \(model.selectedItems.count)개 | 유지: 개수와 진행 상태를 짧게 표시해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CleanupConfirmSheet.swift | 지울 용량 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CleanupConfirmSheet.swift | 옮길 용량 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CleanupConfirmSheet.swift | 다시 만들 수 없음 | 유지: 다시 생기지 않는다는 강한 안전 경고를 그대로 써요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/CleanupConfirmSheet.swift | \(riskyCount)개 | 유지: 개수와 진행 상태를 짧게 표시해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Info.plist | Sweep reads your Desktop to find items that take up space. | See which files on your Desktop take up the most space. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/Info.plist | Sweep reads your Documents folder to find items that take up space. | See which files in Documents take up the most space. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/Info.plist | Sweep reads your Downloads folder to check what can be cleaned up and how much space it uses. | Find files in Downloads to review for cleanup and see how much space they use. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/FolderPicker.swift | 허용 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FolderPicker.swift | Sweep이 \(grantable.purpose)을(를) 찾을 수 있게 \(grantable.label) 폴더를 허용하세요. | \(grantable.label) 폴더에서 \(grantable.purpose)을 찾아볼게요. 이 폴더를 선택하고 허용을 눌러 주세요. | 허용 여부에 따른 확인 범위 유지 |
| Sources/SweepApp/FolderPicker.swift | 추가 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/FolderPicker.swift | 큰 파일과 중복 파일을 찾을 폴더를 고르세요. | 어디에서 더 찾아볼까요? 큰 파일과 중복 파일이 있을 만한 폴더를 선택해 주세요. | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/Retro95/Retro95Theme.swift | 이름 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Retro95/Retro95Theme.swift | 설명 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Retro95/Retro95Theme.swift | 날짜 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Retro95/Retro95Theme.swift | 크기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Retro95/Retro95Theme.swift | 안전도 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Retro95/Retro95Theme.swift | 기능 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Retro95/Retro95Theme.swift | 항목 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Retro95/Retro95Theme.swift | 크기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Retro95/Retro95Theme.swift | 비율 막대 | 차지한 몫 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/Retro95/Retro95Theme.swift | 이름 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Retro95/Retro95Theme.swift | 크기 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Retro95/Retro95Theme.swift | 비율 막대 | 차지한 몫 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/Retro95/Retro95Theme.swift | 상태·동작 | 파일 관리 | 삭제 동작이나 안전 판정 변경 없음 |
| Sources/SweepApp/Retro95/Retro95Controls.swift | 선택됨 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Retro95/Retro95Controls.swift | 부분 선택됨 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Retro95/Retro95Controls.swift | 선택 안 됨 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Retro95/Retro95Controls.swift | 진행률 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Retro95/Retro95Controls.swift | 진행 중 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Retro95/Retro95Controls.swift | 정렬 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Retro95/Retro95Controls.swift | 오름차순 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |
| Sources/SweepApp/Retro95/Retro95Controls.swift | 내림차순 | 유지: 짧고 익숙한 버튼이나 표 이름으로 뜻이 분명해요. | 원래 의미와 안전 사실 유지 |

## 정적 검증

- 문자열 136곳을 바꿨어요. 변경 줄의 문자열을 제외한 코드는 같아요. 주석, 파일 이름, 단축키와 배지도 그대로예요.
- 변경 줄마다 보간식과 포맷 지정자의 개수, 의미를 대조했어요. 차이 없어요.
- 어미와 공백, 문장부호를 제거한 유사도 0.75 이상은 5곳(3.7%)이에요. 안전 경고, 제품명과 짧은 상태 이름을 포함해도 10% 미만이에요.
- `swiftc -frontend -parse`로 SweepApp Swift 파일 전체 문법 검사를 통과했어요.
- `plutil -lint`로 Info.plist와 Sweep.entitlements 검사를 통과했어요.
- `git diff --check`를 통과했어요. 요청에 따라 빌드와 테스트는 실행하지 않았어요. 실제 화면의 잘림 확인은 남아 있어요.
