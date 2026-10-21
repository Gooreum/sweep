import Foundation

/// 자주 보이는 프로그램이 **무엇이고, 바쁜 게 정상인지, 건드려도 되는지**.
///
/// 이름만 보고는 `fileproviderd`가 iCloud 동기화인지 알 수 없다. 사용자가 CPU 탭을 여는
/// 이유는 "이거 왜 바쁘지?"이므로, 자주 나오는 것만 사람 말로 적어 둔다.
/// **목록에 없는 프로그램은 설명을 지어내지 않는다** — `match`가 nil을 돌려주고 화면은
/// 설명 줄을 숨긴다. 틀린 설명은 설명이 없는 것보다 나쁘다.
public struct KnownProcess: Sendable, Equatable {

    /// 사용자가 할 수 있는 일. 강제 종료는 샌드박스가 막아서 이 앱은 대신 해 주지 않는다.
    public enum Advice: Sendable, Equatable {
        /// 건드리지 마세요. macOS가 다시 띄우거나, 꺼지면 불편해진다.
        case leaveIt
        /// 끝내도 해로울 게 없다. 하던 일이 멈출 뿐이다.
        case safeToQuit
        /// 그 프로그램을 직접 열어서 끝내는 것이 맞다.
        case quitInApp
    }

    /// 이게 무엇인지 한두 문장.
    public let summary: String
    /// 바쁠 때 흔한 이유와 언제 조용해지는지.
    public let whenBusy: String
    public let advice: Advice

    public init(summary: String, whenBusy: String, advice: Advice) {
        self.summary = summary
        self.whenBusy = whenBusy
        self.advice = advice
    }

    /// 프로세스 이름(대소문자 무시)으로 찾는다. 같은 프로그램이 이름을 달리 쓰는 경우는
    /// `names`에 모두 적는다 — 접두어 일치로 뭉치면 `node`가 `nodemon`까지 삼킨다.
    public static func match(name: String, path: String? = nil) -> KnownProcess? {
        let key = name.lowercased()
        return catalog.first { $0.names.contains(key) }?.process
    }

    // `names`는 소문자로 적는다. 항목의 문구는 `.design-bounce/copy/style.md`를 따른다.
    private struct Entry {
        let names: Set<String>
        let process: KnownProcess
    }

    private static let catalog: [Entry] = [
        Entry(
            names: ["kernel_task"],
            process: KnownProcess(
                summary: String(localized: "Mac의 메모리와 기기 작동을 맡고, CPU가 과열되지 않게 도와요."),
                whenBusy: String(localized: "열 때문에 다른 앱의 CPU 사용을 줄일 때 이 값이 높아지기도 해요. 온도가 내려가면 이 활동도 줄어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["windowserver"],
            process: KnownProcess(
                summary: String(localized: "여러 앱의 창을 모아 모니터에 보이는 한 화면으로 만들어요."),
                whenBusy: String(localized: "영상이나 움직이는 창이 많을수록 그릴 화면도 늘어요. 쓰지 않는 창을 닫아 화면 작업을 줄여 보세요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["launchd"],
            process: KnownProcess(
                summary: String(localized: "Mac을 켤 때 필요한 프로그램을 시작하고, 계속 실행할 프로그램을 관리해요."),
                whenBusy: String(localized: "로그인 직후에는 여러 프로그램을 한꺼번에 켜요. 잠시 뒤에도 사용률이 높다면 반복해서 켜지는 앱이 있는지 살펴보세요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["fileproviderd"],
            process: KnownProcess(
                summary: String(localized: "iCloud Drive 같은 온라인 저장소의 파일을 Finder에서 열고 바꿀 수 있게 해 줘요."),
                whenBusy: String(localized: "파일을 많이 받거나 옮긴 뒤에는 목록과 바뀐 내용을 맞추는 데 시간이 걸려요. Finder에서 전송 상태를 확인해 보세요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["bird"],
            process: KnownProcess(
                summary: String(localized: "iCloud Drive의 문서를 다른 기기에서도 이어서 쓰게 해 줘요."),
                whenBusy: String(localized: "다른 기기에서 바꾼 문서를 받거나 Mac의 문서를 올릴 때 일해요. iCloud Drive의 전송이 끝날 때까지 기다려 주세요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["cloudd"],
            process: KnownProcess(
                summary: String(localized: "앱이 iCloud에 저장한 내용을 읽고 바꿀 때 연결을 맡아요."),
                whenBusy: String(localized: "앱에서 바꾼 내용을 iCloud로 보내고 새 내용을 받아요. 오래 계속되면 최근 사용한 앱의 iCloud 상태를 확인해 보세요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["mds", "mds_stores", "mdworker", "mdworker_shared"],
            process: KnownProcess(
                summary: String(localized: "파일 이름과 내용을 읽어 두고 Spotlight 검색에서 빨리 찾게 해 줘요."),
                whenBusy: String(localized: "파일을 많이 추가하거나 macOS를 업데이트한 뒤에는 검색할 내용을 다시 읽어요. 이 준비가 끝나면 사용량이 줄어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["spotlight"],
            process: KnownProcess(
                summary: String(localized: "Spotlight 검색창에서 입력한 말에 맞는 앱과 파일을 찾아 보여 줘요."),
                whenBusy: String(localized: "검색어를 바꿀 때마다 결과를 골라요. 검색창을 닫은 뒤 사용률이 내려가는지 확인해 보세요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["photoanalysisd"],
            process: KnownProcess(
                summary: String(localized: "사진 앱에서 사람별로 사진을 모으고, 사물이나 장면으로 찾을 수 있게 해 줘요."),
                whenBusy: String(localized: "새 사진이 많으면 한 장씩 살펴보는 데 오래 걸려요. 사진을 모두 살펴본 뒤에는 이 작업이 줄어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["mediaanalysisd"],
            process: KnownProcess(
                summary: String(localized: "사진과 동영상 속 내용을 알아보는 일을 맡아요."),
                whenBusy: String(localized: "새로 추가한 사진과 영상을 살펴보는 동안 CPU를 써요. 분량이 많으면 처리가 끝날 때까지 기다려 주세요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["softwareupdated"],
            process: KnownProcess(
                summary: String(localized: "Mac을 새 버전으로 바꾸는 데 필요한 업데이트를 받고 준비해요."),
                whenBusy: String(localized: "업데이트 파일을 받거나 설치를 준비할 때 사용량이 늘어요. 시스템 설정의 소프트웨어 업데이트에서 진행 상황을 볼 수 있어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["diskimagesiod"],
            process: KnownProcess(
                summary: String(localized: ".dmg 파일 등을 열었을 때, 그 안의 파일을 읽고 쓰는 일을 맡아요."),
                whenBusy: String(localized: "열어 둔 .dmg 안에서 앱을 복사하는 동안에도 일해요. 복사가 끝났다면 Finder에서 꺼내면 돼요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["backupd"],
            process: KnownProcess(
                summary: String(localized: "Time Machine이 파일을 잃었을 때 되돌릴 사본을 저장해요."),
                whenBusy: String(localized: "첫 백업이나 바뀐 파일이 많은 날에는 오래 걸려요. Time Machine 메뉴에서 백업 진행 상황을 확인해 주세요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["coreaudiod"],
            process: KnownProcess(
                summary: String(localized: "앱의 소리를 스피커로 보내고 마이크로 들어오는 소리를 전달해요."),
                whenBusy: String(localized: "통화와 녹음, 음악 재생이 이어지는 동안 계속 일해요. 쓰지 않는 통화나 녹음을 끝내면 소리 처리도 줄어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["syspolicyd"],
            process: KnownProcess(
                summary: String(localized: "앱을 설치하거나 열 때 macOS의 보안 기준에 맞는지 검사해요."),
                whenBusy: String(localized: "새로 받은 앱을 처음 열 때 검사가 걸려요. 검사가 끝날 때까지 기다리면 돼요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["trustd"],
            process: KnownProcess(
                summary: String(localized: "웹사이트와 앱이 밝힌 신원을 믿을 수 있는지 확인해요."),
                whenBusy: String(localized: "웹 연결이나 앱 실행에 필요한 확인을 맡아요. 계속 높다면 연결을 반복하는 앱이 있는지 살펴보세요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["xprotectservice"],
            process: KnownProcess(
                summary: String(localized: "앱에 Mac을 해치는 악성 코드가 들어 있는지 검사해요."),
                whenBusy: String(localized: "앱을 새로 받거나 바꾼 뒤 실행할 때 검사가 진행돼요. 검사가 끝나도록 그대로 두면 돼요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["node"],
            process: KnownProcess(
                summary: String(localized: "JavaScript로 작성한 코드를 실행해요. 웹 개발 도구나 앱이 함께 켜기도 해요."),
                whenBusy: String(localized: "웹 개발 도구의 작업이나 요청 처리에 CPU를 써요. 아래 실행한 명령을 보고, 켠 도구에서 작업을 멈춰 주세요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["swift-frontend", "swift-build", "swbbuildservice", "xcodebuild", "clang", "ld"],
            process: KnownProcess(
                summary: String(localized: "작성한 코드를 실행할 수 있는 앱으로 만드는 도구예요."),
                whenBusy: String(localized: "앱을 만드는 동안 높은 사용률은 자연스러워요. 완료를 기다리거나 Xcode 또는 실행한 터미널에서 취소하면 돼요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["xcode"],
            process: KnownProcess(
                summary: String(localized: "Apple 기기용 앱의 코드를 쓰고 실행해 보는 도구예요."),
                whenBusy: String(localized: "앱을 만들거나 코드에서 이름과 오류를 찾을 준비를 해요. 작업 표시를 확인하고, 만들기를 멈추려면 Xcode의 중지 버튼을 눌러 주세요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["simulator"],
            process: KnownProcess(
                summary: String(localized: "Mac 화면에 iPhone 같은 시험용 기기를 띄워, 만든 앱을 실행해 봐요."),
                whenBusy: String(localized: "시험용 기기를 켜는 중이거나 그 안의 앱이 움직일 때 CPU를 써요. 시험을 마쳤다면 Simulator에서 기기를 종료해 주세요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["claude"],
            process: KnownProcess(
                summary: String(localized: "질문에 답하거나 파일을 다루는 일을 맡길 수 있는 AI 도구예요."),
                whenBusy: String(localized: "파일을 읽고 명령을 실행하는 등 요청한 일을 진행할 때 사용량이 늘어요. 멈추려면 Claude에서 진행 중인 요청을 중단해 주세요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["codex"],
            process: KnownProcess(
                summary: String(localized: "코드를 읽고 고치거나 명령을 실행하는 일을 돕는 AI 개발 도구예요."),
                whenBusy: String(localized: "코드 검색이나 명령 실행 중에는 Mac도 일을 해요. Codex에서 작업을 끝내거나 중단하면 그 작업의 CPU 사용도 줄어요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["whisper-cli"],
            process: KnownProcess(
                summary: String(localized: "Mac에서 녹음 파일을 읽어 말소리를 글로 옮겨요."),
                whenBusy: String(localized: "녹음이 길수록 글로 옮기는 데 오래 걸려요. 끝날 때까지 기다리거나, 필요 없는 작업이면 종료해도 돼요."),
                advice: .safeToQuit
            )
        ),
        Entry(
            names: ["ollama"],
            process: KnownProcess(
                summary: String(localized: "Mac에 받은 AI 모델로 답을 만들어요."),
                whenBusy: String(localized: "답변을 만드는 계산을 Mac에서 해요. 응답이 끝나길 기다리거나 Ollama를 쓰는 앱에서 요청을 멈춰 주세요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["docker", "com.docker.backend"],
            process: KnownProcess(
                summary: String(localized: "앱을 만드는 데 필요한 도구를 Mac의 다른 프로그램과 분리해서 실행해요."),
                whenBusy: String(localized: "Docker 안에서 켠 프로그램도 Mac의 CPU를 써요. Docker에서 실행 목록을 보고 쓰지 않는 항목을 중지해 주세요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["python", "python3"],
            process: KnownProcess(
                summary: String(localized: "Python으로 작성한 코드를 실행해요. 자료 계산이나 반복 작업 등에 쓰여요."),
                whenBusy: String(localized: "무슨 일을 하는지는 이름만으로 알 수 없어요. 아래 실행한 명령을 확인하고, 실행한 앱이나 터미널에서 멈춰 주세요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["java"],
            process: KnownProcess(
                summary: String(localized: "Java로 만든 앱이나 개발 도구의 코드를 실행해요."),
                whenBusy: String(localized: "계산이나 앱 만들기 등 실제 작업은 Java를 쓰는 앱이 정해요. 아래 경로와 명령으로 어떤 앱인지 먼저 확인해 주세요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["qemu-system-aarch64"],
            process: KnownProcess(
                summary: String(localized: "Mac 안에 또 다른 컴퓨터를 띄워, 그 안에서 앱을 실행해요."),
                whenBusy: String(localized: "그 안에서 실행한 앱도 Mac의 CPU를 써요. 끝내려면 그 컴퓨터의 종료 메뉴로 먼저 꺼 주세요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["google chrome helper", "google chrome helper (renderer)", "google chrome helper (gpu)"],
            process: KnownProcess(
                summary: String(localized: "Chrome이 웹페이지를 실행하고 화면을 그릴 때 나눠 쓰는 프로그램이에요."),
                whenBusy: String(localized: "영상 재생이나 웹페이지의 코드가 CPU를 써요. Chrome의 작업 관리자에서 많이 쓰는 탭을 찾아 닫아 보세요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["com.apple.webkit.webcontent"],
            process: KnownProcess(
                summary: String(localized: "Safari나 다른 앱 안에 열린 웹페이지의 내용을 실행해요."),
                whenBusy: String(localized: "페이지 안의 영상과 코드가 계속 작동할 수 있어요. 최근 연 웹페이지를 닫아 사용량이 줄어드는지 확인해 보세요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["chrome", "google chrome"],
            process: KnownProcess(
                summary: String(localized: "웹사이트를 열고 인터넷을 둘러보는 Google Chrome이에요."),
                whenBusy: String(localized: "여러 탭의 영상과 앱이 동시에 일을 할 수 있어요. 필요 없는 탭을 닫고, 계속 높다면 Chrome의 작업 관리자를 열어 보세요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["finder"],
            process: KnownProcess(
                summary: String(localized: "파일과 폴더를 열고, 복사하거나 옮기는 Finder예요."),
                whenBusy: String(localized: "파일 복사나 폴더 미리보기에 시간이 걸릴 수 있어요. 복사 진행창을 확인하고 작업이 끝날 때까지 기다려 주세요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["dock"],
            process: KnownProcess(
                summary: String(localized: "앱 아이콘이 모인 Dock과 열어 둔 창을 한눈에 보는 화면을 맡아요."),
                whenBusy: String(localized: "Dock을 펼치거나 창을 모아 보여 줄 때 화면을 움직여요. 움직임이 끝난 뒤에도 사용률이 높은지 살펴보세요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["loginwindow"],
            process: KnownProcess(
                summary: String(localized: "로그인 화면을 띄우고, 로그인과 로그아웃을 맡아요."),
                whenBusy: String(localized: "로그인과 로그아웃 때 필요한 일을 해요. 그 과정이 끝난 뒤 사용량이 줄어드는지 확인해 주세요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["hidd"],
            process: KnownProcess(
                summary: String(localized: "키보드, 마우스, 트랙패드로 누르고 움직인 내용을 Mac에 전달해요."),
                whenBusy: String(localized: "입력 기기를 계속 움직이면 전달할 내용도 늘어요. 손을 뗀 뒤에도 높다면 연결한 입력 기기를 확인해 보세요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["notificationcenter"],
            process: KnownProcess(
                summary: String(localized: "화면에 알림을 띄우고 알림 센터의 위젯을 보여 줘요."),
                whenBusy: String(localized: "알림이 몰리거나 위젯이 새 내용을 표시할 때 일해요. 알림과 위젯 화면이 바뀐 뒤에는 사용량이 줄어드는지 보세요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["coreservicesd"],
            process: KnownProcess(
                summary: String(localized: "앱과 파일을 다룰 때 여러 macOS 기능을 연결해 줘요."),
                whenBusy: String(localized: "여러 기능이 함께 쓰는 프로그램이라 이 이름만으로 원인을 알기는 어려워요. 사용률이 계속 높다면 Mac을 재시동해 보세요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["logd"],
            process: KnownProcess(
                summary: String(localized: "앱과 macOS에서 무슨 일이 있었는지 남겨, 문제의 원인을 찾게 도와요."),
                whenBusy: String(localized: "어떤 앱이 같은 오류를 반복해서 남기면 처리할 기록도 늘어요. 최근 문제가 난 앱을 종료한 뒤 사용량을 살펴보세요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["sharingd"],
            process: KnownProcess(
                summary: String(localized: "AirDrop으로 파일을 보내거나 가까운 Apple 기기와 작업을 이어 주는 일을 해요."),
                whenBusy: String(localized: "주변 기기를 찾고 파일이나 작업을 전달할 때 일해요. AirDrop 전송 중이라면 완료를 기다려 주세요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["nsurlsessiond"],
            process: KnownProcess(
                summary: String(localized: "앱 창을 닫은 뒤에도 파일을 받거나 보내는 일을 이어 가요."),
                whenBusy: String(localized: "창이 안 보여도 전송은 계속될 수 있어요. 멈추려면 파일을 주고받기 시작한 앱을 열어 전송을 취소해 주세요."),
                advice: .leaveIt
            )
        )
    ]
}
