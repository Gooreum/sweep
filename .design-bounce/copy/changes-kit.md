# SweepKit 문구 1차 변경표

기존 문장은 삭제 결과와 대상의 사실을 확인하는 데만 참고했어요. 각 행은 화면에 나가는 문구 한 곳이에요. 같은 문구가 여러 곳에 있으면 각각 기록했어요.

사이드바 이름은 스마트 스캔을 **한번에 찾기**로, 정크 파일을 **정리할 파일**로, 디스크 맵을 **공간 보기**로 바꿨어요. 외래어를 몰라도 할 일을 예상할 수 있고 기존 길이를 넘지 않아요. 큰 파일, 중복 파일, 휴지통과 CPU는 유지해요. CPU는 이 화면에서 확인하는 대상의 이름이에요. SAFE, REVIEW, DANGER도 유지해요.

안전 확인: 휴지통 이동과 영구 삭제를 구분했어요. 원본 보존, 재생성 조건, iCloud의 다른 기기 영향, 앱과 설정 및 데이터의 손실을 남겼어요. ‘사라질 수 있어요’인 위험을 확정으로 바꾸지 않았어요. 정리 후 실제 공간은 휴지통을 비워야 늘어난다는 점도 남겼어요.

| 파일 | 이전 | 이후 | 남긴 안전 사실 |
|---|---|---|---|
| Sources/SweepKit/Insight/DiskMapRoot.swift:23 | "diskMap.group.whole", defaultValue: "전체" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Insight/DiskMapRoot.swift:24 | "내 사용자 폴더 안" | "내 폴더 안" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Insight/DiskMapRoot.swift:25 | "응용 프로그램" | 유지: macOS의 실제 폴더 이름을 유지해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Insight/DiskMapRoot.swift:26 | "정리 대상" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Insight/DiskMapRoot.swift:104 | "내 사용자 폴더" | "내 폴더" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Insight/DiskMapRoot.swift:105 | "이 Mac" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Insight/DiskMapRoot.swift:111 | "응용 프로그램" | 유지: macOS의 실제 폴더 이름을 유지해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Insight/DiskMapRoot.swift:143 | "앱 임시 폴더" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/CleanupScope.swift:63 | "앱 임시 폴더" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/CleanupScope.swift:64 | "앱이 쓰다 남긴 임시 파일" | "앱을 쓰고 남은 임시 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/CleanupScope.swift:75 | "큰 파일 · 중복 파일 · 내가 추가한 폴더" | "직접 추가한 곳에서 큰 파일과 중복 파일을 찾아요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/CleanupScope.swift:88 | "~ 내 사용자 폴더" | "~ 내 폴더" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/CleanupScope.swift:99 | "큰 파일 · 중복 파일: \(shown) 외 \(rest)곳" | "\(shown) 외 \(rest)곳에서 큰 파일과 중복 파일을 찾아요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/CleanupScope.swift:100 | "큰 파일 · 중복 파일: \(shown)" | "\(shown)에서 큰 파일과 중복 파일을 찾아요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/CleanupScope.swift:105 | "Xcode가 앱을 만들거나 시험할 때 생긴 파일" | "Xcode 개발용 파일을 찾아요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/CleanupScope.swift:106 | "앱이 다시 만들 수 있는 임시 파일" | "지워도 앱에서 다시 만들 수 있는 파일을 찾아요" | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Model/CleanupScope.swift:107 | "앱 활동 기록" | "앱 사용 기록" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/CleanupScope.swift:108 | "내려받은 파일 · 중복 파일" | "받아 둔 파일과 중복 파일을 찾아요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/CleanupScope.swift:109 | "시스템 임시 파일" | "macOS 임시 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/CleanupScope.swift:111 | "npm 내려받기 임시 파일" | "npm 설치 임시 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/CleanupScope.swift:112 | "Expo 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/CleanupScope.swift:113 | "Gradle 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/CleanupScope.swift:114 | "Cargo 내려받기 임시 파일" | "Cargo 설치 임시 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/CleanupScope.swift:115 | "Maven 내려받기 임시 파일" | "Maven 설치 임시 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/CleanupScope.swift:116 | "휴지통이에요. 비우면 되돌릴 수 없어요" | "버린 파일이 모여 있어요. 완전히 지우면 복구할 수 없어요" | 휴지통 이동과 비운 뒤의 결과 / 복구 가능 여부 |
| Sources/SweepKit/Model/CleanupScope.swift:118 | "iCloud Drive 휴지통이에요. 비우면 다른 기기에서도 사라져요" | "iCloud Drive에서 버린 파일이에요. 비우면 연결된 다른 기기에서도 없어져요" | 휴지통 이동과 비운 뒤의 결과 / iCloud 공간 및 다른 기기 영향 / 삭제 대상과 손실 결과 |
| Sources/SweepKit/Model/CleanupScope.swift:119 | "iOS 기기 백업" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/CleanupScope.swift:121 | "메일 첨부 사본" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/FileDates.swift:35 | "\($0) 만듦" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/FileDates.swift:48 | "방금 사용" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/FileDates.swift:49 | "오늘 사용" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/FileDates.swift:50 | "\(days)일 전 사용" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/FileDates.swift:51 | "\(days / 30)개월 전 사용" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/FileDates.swift:52 | "\(days / 365)년 전 사용" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/FileDates.swift:61 | "만든 날 \($0)" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/FileDates.swift:63 | "마지막 사용 \($0)" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/SafetyLevel.swift:20 | "안전" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/SafetyLevel.swift:21 | "주의" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/SafetyLevel.swift:22 | "위험" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/ScanCategory.swift:29 | "급증한 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/ScanCategory.swift:30 | "Xcode · 앱 시험 도구" | "Xcode 개발 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/ScanCategory.swift:31 | "개발 임시 파일" | "개발용 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/ScanCategory.swift:32 | "앱 웹 임시 파일" | "앱 임시 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/ScanCategory.swift:33 | "오래된 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/ScanCategory.swift:34 | "메일 첨부 사본" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/ScanCategory.swift:35 | "휴지통" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 휴지통 이동과 비운 뒤의 결과 |
| Sources/SweepKit/Model/ScanCategory.swift:36 | "기기 백업" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/ScanCategory.swift:37 | "큰 파일" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Model/ScanCategory.swift:38 | "중복 파일" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/AppModel.swift:439 | "준비됨" | "시작 전" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/AppModel.swift:440 | "검색 중… \(percent)%" | "찾는 중… \(percent)%" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/AppModel.swift:441 | "검색 완료" | "찾기 완료" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/AppModel.swift:442 | "정리하는 중…" | "정리 중…" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/AppModel.swift:443 | "정리 완료" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/AppModel.swift:444 | "되돌리는 중…" | "복구 중…" | 복구 가능 여부 |
| Sources/SweepKit/Presentation/AppModel.swift:445 | "되돌리기 완료" | "복구 완료" | 복구 가능 여부 |
| Sources/SweepKit/Presentation/AppModel.swift:449 | "항목 \($0.items.count)개" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/AppModel.swift:450 | "정리 가능 \($0.formattedTotalSize)" | "정리 대상 \($0.formattedTotalSize)" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/AppModel.swift:456 | "\(scanned.formatted())개 세는 중…" | "\(scanned.formatted())개 확인 중…" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/AppModel.swift:457 | "사용량을 재는 중… \(percent)%" | "크기 확인 중… \(percent)%" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/AppModel.swift:458 | "준비됨") : String(localized: "표시 완료" | "시작 전") : String(localized: "확인 완료" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/AppModel.swift:465 | "항목 \(current.children.count)개" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/AppModel.swift:466 | "크기 \(current.formattedSize)" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/AppModel.swift:478 | "폴더 허용 필요" | "폴더 선택 필요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/Feature.swift:23 | "스마트 스캔" | "한번에 찾기" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/Feature.swift:24 | "정크 파일" | "정리할 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/Feature.swift:25 | "큰 파일" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/Feature.swift:26 | "중복 파일" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/Feature.swift:27 | "휴지통" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 휴지통 이동과 비운 뒤의 결과 |
| Sources/SweepKit/Presentation/Feature.swift:28 | "디스크 맵" | "공간 보기" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/Feature.swift:48 | "한 번에 전체를 살펴보고 정리할 수 있는 용량을 알려줘요." | "지울 만한 파일이 얼마나 있는지 한 번에 확인해 보세요." | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/Feature.swift:51 | "Xcode가 앱을 만들거나 시험할 때 생긴 파일을 찾아 공간을 비워요." | "Xcode 개발용 파일 중에서 정리할 것을 찾아보세요." | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/Feature.swift:52 | "임시 파일, 앱을 만들 때 생긴 파일, 개발 도구의 임시 파일, 기기 백업을 찾아 공간을 비워요." | "앱이 만든 임시 파일과 개발용 파일, 기기 백업을 모아 보여줘요. 필요 없는 것을 골라 주세요." | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/Feature.swift:53 | "내 사용자 폴더와 추가한 폴더에서 큰 파일을 찾아요." | "내 폴더에 큰 파일이 있는지 살펴보세요. 직접 추가한 폴더도 함께 찾아요." | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/Feature.swift:54 | "내용이 같은 파일을 찾아 하나만 남겨요." | "똑같은 파일이 여러 개 있으면 여분을 골라 정리해 보세요." | 동일한 원본 보존 |
| Sources/SweepKit/Presentation/Feature.swift:55 | "휴지통에 든 것을 크기순으로 보고 골라서 비워요. 비우면 되돌릴 수 없어요." | "휴지통에서 지울 것을 골라 주세요. 큰 항목부터 보여줘요. 지운 항목은 되살릴 수 없어요." | 휴지통 이동과 비운 뒤의 결과 / 복구 가능 여부 |
| Sources/SweepKit/Presentation/Feature.swift:56 | "무엇이 공간을 차지하는지 큰 것부터 살펴봐요." | "큰 폴더부터 열어 보며 어디에 공간을 많이 쓰는지 확인하세요." | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/Feature.swift:59 | "지금 어떤 프로그램이 CPU를 쓰는지 보여줘요." | "컴퓨터를 바쁘게 하는 프로그램을 확인해 보세요." | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/Feature.swift:71 | "대부분 앱을 만들면 다시 생겨요. 복구할 수 없는 앱 심사 제출본은 선택할 수 없게 잠가 뒀어요." | "지워도 대부분 개발할 때 다시 생기는 파일이에요. 심사에 낸 앱은 복구할 수 없어 고르지 못하게 했어요." | 복구 가능 여부 / 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Presentation/Feature.swift:73 | "설치 파일은 다시 받을 수 있어요. 촬영 원본과 백업은 내용을 확인한 뒤 고르세요." | "사진이나 영상 원본, 백업은 필요한지 먼저 확인하세요. 앱 설치 파일은 다시 받을 수 있어요." | 재생성 또는 재다운로드 조건 / 동일한 원본 보존 |
| Sources/SweepKit/Presentation/Feature.swift:75 | "원본은 항상 남겨요. 아래 파일을 지워도 내용이 같은 파일은 그대로 남아요." | "아래는 여분의 파일이에요. 지우더라도 내용이 똑같은 원본 하나는 반드시 남아요." | 동일한 원본 보존 |
| Sources/SweepKit/Presentation/Feature.swift:77 | "고른 항목은 휴지통에서 바로 지워져 되돌릴 수 없어요." | "여기서 고르면 휴지통에서도 완전히 없어져요. 다시 되살릴 수 없으니 꼭 확인하세요." | 휴지통 이동과 비운 뒤의 결과 / 복구 가능 여부 |
| Sources/SweepKit/Presentation/Feature.swift:79 | "기능별로 나눠 뒀어요. 잠긴 항목은 되돌릴 수 없어 선택할 수 없어요." | "종류별로 살펴보고 정리할 것을 고르세요. 복구할 수 없는 항목은 잠가 두었어요." | 복구 가능 여부 |
| Sources/SweepKit/Presentation/ProgressDisplay.swift:16 | "\(clamped)초" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/ProgressDisplay.swift:17 | "\(clamped / 60)분 \(clamped % 60)초" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/ScanModel.swift:43 | "다시 만들 수 있음" | "다시 생김" | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Presentation/ScanModel.swift:44 | "확인 필요" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/ScanModel.swift:45 | "되돌릴 수 없음" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 복구 가능 여부 |
| Sources/SweepKit/Presentation/ScanModel.swift:172 | "안전만" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/ScanModel.swift:173 | "권장" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/ScanModel.swift:174 | "selection.all", defaultValue: "전체" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Presentation/ScanModel.swift:175 | "해제" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Remove/CleanupHistory.swift:67 | "지금까지 \(bytes)를 휴지통으로 옮겼어요. 마지막 정리는 \(Self.relative(lastCleanup, now: now))" | "휴지통으로 보낸 파일은 모두 \(bytes)예요. 최근 정리한 때는 \(Self.relative(lastCleanup, now: now))" | 휴지통 이동과 비운 뒤의 결과 |
| Sources/SweepKit/Remove/CleanupHistory.swift:73 | "휴지통을 비워야 디스크 공간이 늘어나요" | "옮긴 파일은 아직 공간을 차지해요. 휴지통까지 비워 주세요" | 휴지통 이동과 비운 뒤의 결과 |
| Sources/SweepKit/Remove/CleanupHistory.swift:85 | "마지막 정리 후 \(days)일이 지났어요. 다시 만들 수 있는 \(bytes)를 정리해 보세요" | "다시 만들 수 있는 파일이 \(bytes) 있어요. \(days)일 만에 다시 정리해 볼까요?" | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Remove/CleanupHistory.swift:93 | "방금" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Remove/CleanupHistory.swift:94 | "오늘" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Remove/CleanupHistory.swift:95 | "\(days)일 전" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Remove/CleanupHistory.swift:96 | "\(days / 30)개월 전" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Remove/CleanupHistory.swift:97 | "\(days / 365)년 전" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Remove/RemovalReport.swift:24 | "앱을 종료한 뒤 다시 시도하세요" | "쓰고 있는 앱을 먼저 닫고 다시 해 보세요" | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Remove/RemovalReport.swift:25 | "전체 디스크 접근을 켜면 옮길 수 있어요" | "설정에서 ‘전체 디스크 접근’을 켜 주세요. 그러면 옮길 수 있어요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Remove/RemovalReport.swift:26 | "보호된 항목이라 이 앱으로는 지울 수 없어요" | "Sweep이 보호하는 항목은 삭제하지 않아요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Remove/RemovalReport.swift:27 | "원래 자리의 항목을 치운 뒤 Finder 휴지통에서 되돌려 놓으세요" | "원래 위치를 먼저 비워 주세요. 그다음 Finder의 휴지통에서 꺼내 주세요" | 휴지통 이동과 비운 뒤의 결과 / 복구 가능 여부 |
| Sources/SweepKit/Remove/RemovalReport.swift:28 | "휴지통을 비웠거나 이미 옮겨져 되돌릴 수 없어요" | "이미 휴지통 밖으로 옮겼거나 완전히 지운 항목은 여기서 복구할 수 없어요" | 휴지통 이동과 비운 뒤의 결과 / 복구 가능 여부 |
| Sources/SweepKit/Remove/RemovalReport.swift:102 | "휴지통을 비우면 \(formattedReclaimed)가 실제로 확보돼요" | "아직 공간이 늘어난 것은 아니에요. 휴지통까지 비워야 \(formattedReclaimed)를 쓸 수 있어요" | 휴지통 이동과 비운 뒤의 결과 |
| Sources/SweepKit/Remove/Restorer.swift:26 | "휴지통에서 찾을 수 없어요" | "되살릴 파일이 휴지통에 없어요" | 휴지통 이동과 비운 뒤의 결과 |
| Sources/SweepKit/Remove/Restorer.swift:30 | "원래 자리에 같은 이름이 있어요" | "같은 이름의 항목이 있어 되돌려 놓지 못했어요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Remove/Restorer.swift:34 | "원래 폴더가 사라졌어요" | "돌려놓을 폴더가 더는 없어요" | 삭제 대상과 손실 결과 |
| Sources/SweepKit/Safety/FolderAccess.swift:25 | "\(expected) 폴더를 골라 주세요. (고른 곳: \(picked.path))" | "지금 고른 곳은 \(picked.path)이에요. \(expected) 폴더를 선택해 주세요." | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/FolderAccess.swift:27 | "폴더 접근 권한을 저장하지 못했어요: \(reason)" | "이 폴더를 다시 열 수 있도록 저장하는 데 실패했어요. \(reason)" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/FolderAccess.swift:68 | "이 Mac" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/FolderAccess.swift:69 | "디스크 맵에서 모든 폴더 보기" | "공간 보기에서 폴더 전체를 살펴봐요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/FolderAccess.swift:75 | "큰 파일 · 중복 파일 · 휴지통 · 개발 도구 임시 파일" | "큰 파일과 중복 파일, 휴지통, 개발용 임시 파일을 살펴봐요" | 휴지통 이동과 비운 뒤의 결과 |
| Sources/SweepKit/Safety/FolderAccess.swift:81 | "앱 시험용 파일 · 앱과 브라우저의 임시 파일 · 활동 기록" | "개발용 파일과 앱이나 브라우저의 임시 파일, 사용 기록을 찾아요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/FolderAccess.swift:83 | "npm 내려받기 임시 파일" | "npm 설치 임시 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/FolderAccess.swift:85 | "Expo 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/FolderAccess.swift:88 | "응용 프로그램" | 유지: macOS의 실제 폴더 이름을 유지해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/FolderAccess.swift:89 | "쓰지 않는 앱 지우기" | "안 쓰는 앱을 골라 정리해요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/FolderAccess.swift:242 | "Xcode가 앱을 만들거나 시험할 때 생긴 파일" | "Xcode 개발용 파일을 찾아요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/ProtectedPaths.swift:26 | "정리할 수 있는 범위 밖이에요: \(u.path)" | "Sweep에서 삭제할 수 없는 위치예요: \(u.path)" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/ProtectedPaths.swift:27 | "보호된 위치예요: \(u.path)" | "지우지 못하도록 보호하는 곳이에요: \(u.path)" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/ProtectedPaths.swift:28 | "다른 위치로 연결된 항목이 정리 허용 범위 밖을 가리켜요: \(u.path)" | "Sweep에서 삭제할 수 없는 곳으로 연결돼 있어요: \(u.path)" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/ProtectedPaths.swift:29 | "디스크의 최상위 폴더나 내 사용자 폴더 자체는 지울 수 없어요: \(u.path)" | "디스크 전체나 내 폴더 전체를 삭제할 수는 없어요: \(u.path)" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/ProtectedPaths.swift:30 | "정리 대상의 기준 폴더 자체는 지울 수 없어요: \(u.path)" | "이 폴더는 남겨 두고 안에 든 항목만 정리할 수 있어요: \(u.path)" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/ProtectedPaths.swift:31 | "다른 사용자나 시스템 소유라 정리할 수 없어요: \(u.path)" | "내 소유가 아닌 항목은 지울 수 없어요: \(u.path)" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/ProtectedPaths.swift:32 | "시스템이 보호 중이라 삭제할 수 없어요: \(u.path)" | "macOS에서 삭제를 막고 있어요: \(u.path)" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/ProtectedPaths.swift:33 | "실행 중인 앱이에요. 종료한 뒤 다시 시도해 주세요: \(u.path)" | "아직 켜져 있는 앱이에요. 먼저 닫고 다시 해 보세요: \(u.path)" | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Safety/ProtectedPaths.swift:34 | "내 사용자 폴더의 기본 폴더나 계정 데이터라 지울 수 없어요: \(u.path)" | "내 계정에 필요한 파일이나 기본 폴더는 삭제하지 않아요: \(u.path)" | 앱 데이터 및 설정 손실 범위와 확실성 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:28 | "지워도 됨" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:29 | "확인 필요" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:30 | "보호됨" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:73 | "임시 파일이에요. Mac을 재시동하면 비워져요." | "Mac을 껐다 켜면 없어지는 임시 파일이에요." | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:76 | "앱의 임시 파일이에요. 필요하면 앱이 다시 만들어요." | "지워도 필요한 임시 파일은 앱에서 새로 만들어요." | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:84 | "앱이에요. 지우면 앱이 사라지고, 설정은 ~/Library 폴더에 남아요." | "이 앱을 삭제해요. 앱 설정은 ~/Library 폴더에 그대로 남아요." | 앱 데이터 및 설정 손실 범위와 확실성 / 삭제 대상과 손실 결과 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:87 | "앱과 시스템의 설정 정보예요. 무엇인지 확실할 때만 지우세요." | "컴퓨터나 앱의 설정이 들어 있어요. 필요 없다는 확신이 들 때만 고르세요." | 앱 데이터 및 설정 손실 범위와 확실성 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:90 | "내 파일이에요. 휴지통으로 가지만 비우면 되돌릴 수 없어요." | "개인 파일을 휴지통으로 옮겨요. 나중에 휴지통까지 비우면 복구할 수 없어요." | 휴지통 이동과 비운 뒤의 결과 / 복구 가능 여부 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:92 | "내 사용자 폴더 밖에 있는 내 소유 항목이에요. 어떤 프로그램이 쓰는지 확인하고 지우세요." | "내 폴더 바깥에 보관된 내 파일이에요. 삭제하기 전에 어느 프로그램에 필요한지 확인하세요." | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:103 | "Xcode가 앱을 만들 때 다시 생겨요" | "지워도 Xcode로 개발하면 새로 만들어져요" | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:105 | "앱 시험 도구의 임시 파일이에요" | "개발 중 앱을 실행하며 생긴 임시 파일이에요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:107 | "앱 시험 도구가 쓰다 남긴 임시 파일이에요" | "개발 중 앱을 실행하고 남은 임시 파일이에요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:109 | "앱의 임시 파일이에요. 필요하면 앱이 다시 만들어요." | "지워도 필요한 임시 파일은 앱에서 새로 만들어요." | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:111 | "앱 활동 기록이에요. 다시 쌓여요." | "앱을 쓰면서 쌓인 기록이에요. 지운 뒤에도 새 기록이 쌓여요." | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:113 | "npm 임시 파일이에요. 설치할 때 다시 받아요." | "설치에 쓰려고 npm에서 받은 임시 파일이에요. 다음 설치 때 다시 받아요." | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:115 | "Expo 임시 파일이에요. 앱을 만들 때 다시 받아요." | "개발에 쓰려고 Expo에서 받은 임시 파일이에요. 다음에 개발할 때 다시 받아요." | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:121 | "앱 심사 제출본이에요. 지우면 복구할 수 없어요" | "심사에 낸 앱을 보관한 파일이에요. 삭제하면 되살릴 수 없어요" | 복구 가능 여부 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:123 | "기기를 다시 연결하면 내려받아요" | "지워도 기기를 연결할 때 다시 받아요" | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:125 | "Xcode가 내려받은 구성요소예요" | "개발에 쓰려고 Xcode에서 받은 파일이에요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:127 | "앱을 시험하는 데 쓰는 가상 기기예요" | "개발 중인 앱을 실행해 보는 가상 기기예요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:129 | "앱 시험용 가상 기기예요. 안의 앱과 데이터가 함께 사라져요." | "개발 중인 앱을 실행해 보는 가상 기기예요. 삭제하면 그 안의 앱과 데이터도 모두 없어져요." | 앱 데이터 및 설정 손실 범위와 확실성 / 삭제 대상과 손실 결과 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:131 | "앱 데이터예요. 지우면 그 앱의 설정, 로그인 정보, 문서가 사라질 수 있어요." | "앱이 보관하는 파일이에요. 삭제하면 설정이나 로그인 정보, 문서까지 잃을 수 있어요." | 앱 데이터 및 설정 손실 범위와 확실성 / 삭제 대상과 손실 결과 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:133 | "앱이 따로 보관하는 데이터예요. 앱을 지웠다면 남은 파일이지만, 쓰는 앱이면 데이터가 사라져요." | "삭제한 앱이 남긴 파일일 수 있어요. 아직 쓰는 앱이라면 지울 때 그 앱의 데이터도 없어져요." | 앱 데이터 및 설정 손실 범위와 확실성 / 삭제 대상과 손실 결과 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:135 | "앱이 따로 보관하는 데이터예요. 앱을 지웠다면 남은 파일이지만, 쓰는 앱이면 데이터가 사라져요." | "삭제한 앱이 남긴 파일일 수 있어요. 아직 쓰는 앱이라면 지울 때 그 앱의 데이터도 없어져요." | 앱 데이터 및 설정 손실 범위와 확실성 / 삭제 대상과 손실 결과 |
| Sources/SweepKit/Safety/RemovalVerdict.swift:137 | "내려받은 파일이에요. 다시 받을 수 있으면 지워도 돼요." | "다시 구할 수 있는 파일인지 확인하세요. 다시 받을 수 있다면 정리해도 괜찮아요." | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Safety/UserFolders.swift:28 | "내 사용자 폴더 자체나 이를 포함하는 폴더는 추가할 수 없어요. 그 안에 보이는 폴더는 이미 모두 살펴봐요." | "내 폴더 안은 이미 모두 찾고 있어요. 내 폴더 전체나 그 상위 폴더는 추가할 수 없어요." | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/UserFolders.swift:30 | "Library 안은 추가할 수 없어요. 앱 데이터는 정크 파일 기능에서 따로 살펴봐요." | "Library는 여기에 추가할 수 없어요. 앱이 만든 파일은 ‘정리할 파일’에서 확인하세요." | 앱 데이터 및 설정 손실 범위와 확실성 |
| Sources/SweepKit/Safety/UserFolders.swift:32 | "시스템 폴더는 추가할 수 없어요." | "컴퓨터에 필요한 폴더라 추가할 수 없어요." | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/UserFolders.swift:34 | "이미 보고 있는 폴더예요: \(CleanupItem.abbreviating(url.path, home: Sandbox.userHome.path))" | "따로 추가하지 않아도 찾는 곳이에요: \(CleanupItem.abbreviating(url.path, home: Sandbox.userHome.path))" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/UserFolders.swift:36 | "폴더 접근 권한을 저장하지 못했어요: \(reason)" | "이 폴더를 다시 열 수 있도록 저장하는 데 실패했어요. \(reason)" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Safety/UserFolders.swift:136 | "큰 파일 · 중복 파일" | "큰 파일과 중복 파일 찾기" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/AppCacheScanner.swift:99 | "\(app) 인터넷 없이 쓰는 파일이에요. 다시 내려받아요" | "인터넷 없이 \(app)을 쓸 때 필요한 파일이에요. 지우면 다시 받아요" | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Scan/AppCacheScanner.swift:100 | "\(app)이(가) 다시 만들어요" | "지워도 \(app)에서 새로 만들어요" | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Scan/AppCacheScanner.swift:109 | "앱" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:18 | "Swift Package Manager 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:19 | "Carthage 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:20 | "CocoaPods 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:21 | "Homebrew 내려받기 임시 파일" | "Homebrew 설치 임시 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:22 | "Xcode 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:23 | "Go 앱 생성 임시 파일" | "Go 개발 임시 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:24 | "node-gyp 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:25 | "TypeScript 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:26 | "Deno 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:27 | "JetBrains 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:28 | "pnpm 내려받기 임시 파일" | "pnpm 설치 임시 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:29 | "Yarn 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:30 | "Playwright 브라우저 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:31 | "Cypress 실행 파일 사본" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:32 | "Electron 내려받기 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:33 | "electron-builder 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:34 | "pip 내려받기 임시 파일" | "pip 설치 임시 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:35 | "uv 내려받기 임시 파일" | "uv 설치 임시 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:36 | "Bazelisk 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:50 | "npm 내려받기 임시 파일" | "npm 설치 임시 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:51 | "npx 실행 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:52 | "Expo 앱 구성 파일 사본" | "Expo 개발 파일 사본" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:53 | "Expo 버전 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:54 | "Expo 설정 형식 임시 파일" | "Expo 설정 임시 파일" | 앱 데이터 및 설정 손실 범위와 확실성 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:55 | "Expo 앱 시험용 임시 파일" | "Expo 개발 임시 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:56 | "Expo Go 내려받기 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:65 | "Gradle 임시 파일" | 유지: 제품 이름과 파일 성격을 정확하고 짧게 구분해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:66 | "Cargo 내려받기 임시 파일" | "Cargo 설치 임시 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:67 | "Maven 내려받기 임시 파일" | "Maven 설치 임시 파일" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DevCacheScanner.swift:118 | "앱 활동 기록이에요" | "앱을 쓰면서 쌓인 기록이에요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DeviceBackupScanner.swift:41 | "iOS 기기 백업" | 유지: 짧고 익숙한 이름으로 의미가 분명해요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DeviceBackupScanner.swift:46 | "오늘 백업" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DeviceBackupScanner.swift:47 | "\(days)일 전 백업" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DeviceBackupScanner.swift:48 | "\(days / 30)개월 전 백업" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/DuplicateScanner.swift:82 | "\(originalName(original.url, beside: duplicate.url))와 내용이 같아요" | "같은 내용의 원본이 남아요: \(originalName(original.url, beside: duplicate.url))" | 동일한 원본 보존 |
| Sources/SweepKit/Scan/LargeFileScanner.swift:77 | "오늘 받았어요" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/LargeFileScanner.swift:78 | "\(days)일 전에 받았어요" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/LargeFileScanner.swift:79 | "\(days / 30)개월 전에 받았어요" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/LargeFileScanner.swift:83 | "오늘 수정했어요" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/LargeFileScanner.swift:84 | "\(days)일 전에 수정했어요" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/LargeFileScanner.swift:85 | "\(days / 30)개월 전에 수정했어요" | 유지: 시간과 날짜는 이미 가장 짧고 자연스러운 표기예요 | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/MailDownloadsScanner.swift:27 | "메일에서 다시 열면 생겨요" | "메일 원본은 남아요. 첨부 파일을 다시 열면 새 사본이 생겨요" | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Scan/RunawayTempScanner.swift:95 | "쓰다 남긴 임시 파일이에요. 크기는 늘지 않아요" | "더 커지지 않는 임시 파일이에요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/RunawayTempScanner.swift:97 | "증가 중" | "커지는 중" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/RunawayTempScanner.swift:99 | "\(ByteCountFormatter.string(fromByteCount: perMinute, countStyle: .file))/분 증가 중" | "1분에 \(ByteCountFormatter.string(fromByteCount: perMinute, countStyle: .file))씩 커져요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/StaleCacheScanner.swift:53 | "\(Int(idle / 86_400))일 동안 쓰이지 않았어요" | "마지막으로 쓴 뒤 \(Int(idle / 86_400))일이 지났어요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/TrashScanner.swift:39 | "비우면 되돌릴 수 없어요" | "완전히 삭제해요. 복구는 불가능해요" | 복구 가능 여부 |
| Sources/SweepKit/Scan/TrashScanner.swift:41 | "iCloud Drive 휴지통이에요. 비우면 다른 기기에서도 사라져요" | "iCloud Drive에서 버린 파일이에요. 비우면 연결된 다른 기기에서도 없어져요" | 휴지통 이동과 비운 뒤의 결과 / iCloud 공간 및 다른 기기 영향 / 삭제 대상과 손실 결과 |
| Sources/SweepKit/Scan/TrashScanner.swift:46 | "\(volume.lastPathComponent) 휴지통이에요. 비우면 되돌릴 수 없어요" | "\(volume.lastPathComponent)에서 버린 파일이에요. 완전히 지우면 복구할 수 없어요" | 휴지통 이동과 비운 뒤의 결과 / 복구 가능 여부 |
| Sources/SweepKit/Scan/TrashScanner.swift:61 | "iCloud에만 있어요. 지우면 iCloud 공간만 비워져요" | "Mac에는 없는 파일이에요. 삭제해도 iCloud의 빈 공간만 늘어나요" | iCloud 공간 및 다른 기기 영향 |
| Sources/SweepKit/Scan/XcodeScanner.swift:27 | "Xcode가 앱을 만들 때 다시 생겨요" | "지워도 Xcode로 개발하면 새로 만들어져요" | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Scan/XcodeScanner.swift:32 | "앱 시험 도구의 임시 파일이에요" | "개발 중 앱을 실행하며 생긴 임시 파일이에요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/XcodeScanner.swift:34 | "앱 시험 도구가 쓰다 남긴 임시 파일이에요" | "개발 중 앱을 실행하고 남은 임시 파일이에요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/XcodeScanner.swift:36 | "기기를 다시 연결하면 내려받아요" | "지워도 기기를 연결할 때 다시 받아요" | 재생성 또는 재다운로드 조건 |
| Sources/SweepKit/Scan/XcodeScanner.swift:38 | "앱을 시험하는 데 쓰는 가상 기기예요" | "개발 중인 앱을 실행해 보는 가상 기기예요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/XcodeScanner.swift:40 | "Xcode가 내려받은 구성요소예요" | "개발에 쓰려고 Xcode에서 받은 파일이에요" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
| Sources/SweepKit/Scan/XcodeScanner.swift:42 | "앱 심사 제출본이에요. 지우면 복구할 수 없어요" | "심사에 낸 앱을 보관한 파일이에요. 삭제하면 되살릴 수 없어요" | 복구 가능 여부 |
| Sources/SweepKit/Scan/XcodeScanner.swift:107 | "\(device.name) · \(device.runtime). 설치한 앱과 설정이 사라져요" | "\(device.name)에 \(device.runtime)이 설치되어 있어요. 지우면 안에 설치한 앱과 설정도 없어져요" | 앱 데이터 및 설정 손실 범위와 확실성 / 삭제 대상과 손실 결과 |
| Sources/SweepKit/Scan/XcodeScanner.swift:127 | "알 수 없는 실행 환경" | "설치 버전 모름" | 별도 삭제 안전 사실 없음. 대상과 상태 유지 |
