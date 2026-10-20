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
                summary: String(localized: "맥이 작동하는 데 꼭 필요한 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "맥이 너무 뜨거우면 열을 식히려고 일부러 CPU 사용을 막기도 해요. 이 숫자가 높으면 보통 맥이 뜨겁다는 뜻이에요. 식으면 줄어들어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["windowserver"],
            process: KnownProcess(
                summary: String(localized: "앱 창과 화면을 보여 주는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "창을 많이 열거나 화면에 움직임이 많으면 바빠요. 창을 줄이거나 움직임이 멈추면 줄어들어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["launchd"],
            process: KnownProcess(
                summary: String(localized: "맥에 필요한 프로그램을 켜 주는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "맥을 켜거나 여러 프로그램이 시작될 때 바쁠 수 있어요. 시작이 끝나면 줄어들어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["fileproviderd"],
            process: KnownProcess(
                summary: String(localized: "온라인에 보관한 파일을 Finder에서 쓸 수 있게 돕는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "파일을 많이 받거나 바꾸면 한동안 바빠요. 파일을 맞추는 일이 끝나면 조용해져요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["bird"],
            process: KnownProcess(
                summary: String(localized: "iCloud Drive 파일을 다른 기기와 맞추는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "파일을 많이 바꾸거나 처음 연결하면 한동안 바빠요. 끝나면 조용해져요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["cloudd"],
            process: KnownProcess(
                summary: String(localized: "앱의 iCloud 자료를 주고받는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "앱이 iCloud 자료를 많이 주고받으면 바빠요. 주고받는 일이 끝나면 줄어들어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["mds", "mds_stores", "mdworker", "mdworker_shared"],
            process: KnownProcess(
                summary: String(localized: "Spotlight에서 파일을 찾을 수 있게 준비하는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "파일이 많이 늘거나 macOS를 업데이트하면 한동안 바빠요. 검색 준비가 끝나면 조용해져요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["spotlight"],
            process: KnownProcess(
                summary: String(localized: "맥에서 파일과 앱을 찾는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "검색어를 입력하고 결과를 보여 줄 때 바쁠 수 있어요. 검색을 마치면 줄어들어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["photoanalysisd"],
            process: KnownProcess(
                summary: String(localized: "사진 속 사람과 사물을 찾아 주는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "사진이 많이 추가되면 한동안 바빠요. 사진을 살펴보는 일이 끝나면 조용해져요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["mediaanalysisd"],
            process: KnownProcess(
                summary: String(localized: "사진과 동영상의 내용을 살펴보는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "사진이나 동영상이 많이 추가되면 바쁠 수 있어요. 살펴보는 일이 끝나면 줄어들어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["softwareupdated"],
            process: KnownProcess(
                summary: String(localized: "macOS 업데이트를 준비하는 기본 프로그램이에요."),
                whenBusy: String(localized: "업데이트를 확인하거나 받고 설치할 때 바빠요. 업데이트 작업이 끝나면 조용해져요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["diskimagesiod"],
            process: KnownProcess(
                summary: String(localized: "설치 파일처럼 디스크 모양으로 여는 파일을 다루는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "이런 파일을 열거나 그 안의 파일을 읽고 쓸 때 바쁠 수 있어요. 작업이 끝나면 줄어들어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["backupd"],
            process: KnownProcess(
                summary: String(localized: "Time Machine으로 파일을 따로 보관해 주는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "처음 보관하거나 바뀐 파일이 많으면 오래 바쁠 수 있어요. 보관이 끝나면 조용해져요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["coreaudiod"],
            process: KnownProcess(
                summary: String(localized: "맥에서 소리를 듣고 녹음할 수 있게 하는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "음악을 듣거나 통화하고 녹음할 때 바쁠 수 있어요. 소리를 쓰는 일이 끝나면 줄어들어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["syspolicyd"],
            process: KnownProcess(
                summary: String(localized: "앱을 실행해도 되는지 확인하는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "앱을 처음 열거나 새 앱을 확인할 때 바쁠 수 있어요. 확인이 끝나면 조용해져요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["trustd"],
            process: KnownProcess(
                summary: String(localized: "웹사이트와 앱이 믿을 만한 곳에서 왔는지 확인하는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "웹사이트에 연결하거나 앱을 확인할 때 바쁠 수 있어요. 확인이 끝나면 줄어들어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["xprotectservice"],
            process: KnownProcess(
                summary: String(localized: "해로운 프로그램이 있는지 확인하는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "새로 받은 앱 등을 확인할 때 바쁠 수 있어요. 확인이 끝나면 조용해져요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["node"],
            process: KnownProcess(
                summary: String(localized: "개발할 때 켜는 프로그램이에요."),
                whenBusy: String(localized: "개발 중인 프로그램이 일을 많이 하면 바빠요. 작업을 마치거나 개발 도구에서 멈추면 줄어들어요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["swift-frontend", "swift-build", "swbbuildservice", "xcodebuild", "clang", "ld"],
            process: KnownProcess(
                summary: String(localized: "개발할 때 앱을 만드는 데 쓰는 프로그램이에요."),
                whenBusy: String(localized: "앱을 만드는 동안 바빠요. 만드는 일이 끝나거나 개발 도구에서 멈추면 조용해져요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["xcode"],
            process: KnownProcess(
                summary: String(localized: "앱을 개발할 때 쓰는 Xcode예요."),
                whenBusy: String(localized: "앱을 만들거나 개발용 파일을 살펴볼 때 바빠요. 작업이 끝나면 줄어들어요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["simulator"],
            process: KnownProcess(
                summary: String(localized: "개발 중인 앱을 아이폰 같은 가상 기기에서 실행해 보는 프로그램이에요."),
                whenBusy: String(localized: "가상 기기를 켜거나 그 안에서 앱이 일하면 바빠요. 앱을 멈추거나 가상 기기를 끄면 줄어들어요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["claude"],
            process: KnownProcess(
                summary: String(localized: "AI에게 질문하거나 일을 맡길 때 쓰는 Claude예요."),
                whenBusy: String(localized: "요청한 일을 처리하거나 파일을 살펴볼 때 바쁠 수 있어요. 작업이 끝나면 줄어들어요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["codex"],
            process: KnownProcess(
                summary: String(localized: "AI에게 개발 일을 맡길 때 쓰는 Codex예요."),
                whenBusy: String(localized: "개발 작업을 하거나 파일을 살펴볼 때 바쁠 수 있어요. 작업이 끝나면 줄어들어요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["whisper-cli"],
            process: KnownProcess(
                summary: String(localized: "녹음한 말을 글로 바꾸는 프로그램이에요."),
                whenBusy: String(localized: "녹음한 말을 글로 바꾸는 동안 바빠요. 변환이 끝나면 조용해져요."),
                advice: .safeToQuit
            )
        ),
        Entry(
            names: ["ollama"],
            process: KnownProcess(
                summary: String(localized: "맥에서 AI를 실행하는 Ollama예요."),
                whenBusy: String(localized: "AI가 답을 만드는 동안 바빠요. 답을 다 만들거나 요청을 멈추면 줄어들어요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["docker", "com.docker.backend"],
            process: KnownProcess(
                summary: String(localized: "개발에 필요한 프로그램을 실행하는 Docker예요."),
                whenBusy: String(localized: "Docker 안에서 실행한 프로그램이 일을 하면 바빠요. Docker에서 해당 작업을 멈추면 줄어들어요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["python", "python3"],
            process: KnownProcess(
                summary: String(localized: "개발이나 자동 작업에 쓰는 프로그램이에요."),
                whenBusy: String(localized: "실행한 작업에 따라 오래 바쁠 수 있어요. 작업이 끝나거나 실행한 앱에서 멈추면 줄어들어요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["java"],
            process: KnownProcess(
                summary: String(localized: "여러 앱과 개발 도구를 실행하는 데 쓰는 프로그램이에요."),
                whenBusy: String(localized: "이 프로그램을 쓰는 앱이 일을 많이 하면 바빠요. 해당 앱에서 작업을 마치면 줄어들어요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["qemu-system-aarch64"],
            process: KnownProcess(
                summary: String(localized: "맥 안에서 다른 컴퓨터 환경을 실행하는 프로그램이에요."),
                whenBusy: String(localized: "그 안에서 실행한 프로그램이 일을 하면 바빠요. 실행한 앱에서 해당 환경을 끄면 줄어들어요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["google chrome helper", "google chrome helper (renderer)", "google chrome helper (gpu)"],
            process: KnownProcess(
                summary: String(localized: "Chrome에서 웹페이지와 화면을 보여 주는 보조 프로그램이에요."),
                whenBusy: String(localized: "웹페이지에서 영상이나 복잡한 화면을 보여 주면 바빠요. 해당 탭을 닫으면 줄어들 수 있어요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["com.apple.webkit.webcontent"],
            process: KnownProcess(
                summary: String(localized: "Safari 같은 앱 안에서 웹페이지를 보여 주는 프로그램이에요."),
                whenBusy: String(localized: "웹페이지에서 영상이나 복잡한 화면을 보여 주면 바빠요. 해당 페이지를 닫으면 줄어들 수 있어요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["chrome", "google chrome"],
            process: KnownProcess(
                summary: String(localized: "인터넷을 볼 때 쓰는 Google Chrome이에요."),
                whenBusy: String(localized: "탭을 많이 열거나 영상 등을 보면 바빠요. 쓰지 않는 탭을 닫으면 줄어들 수 있어요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["finder"],
            process: KnownProcess(
                summary: String(localized: "맥의 파일과 폴더를 보고 여는 Finder예요."),
                whenBusy: String(localized: "파일을 많이 옮기거나 폴더를 열 때 바쁠 수 있어요. 파일 작업이 끝나면 줄어들어요."),
                advice: .quitInApp
            )
        ),
        Entry(
            names: ["dock"],
            process: KnownProcess(
                summary: String(localized: "화면 아래의 앱 막대와 열려 있는 창 보기를 맡는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "앱 막대나 창을 모아 보는 화면이 움직일 때 바쁠 수 있어요. 움직임이 끝나면 줄어들어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["loginwindow"],
            process: KnownProcess(
                summary: String(localized: "맥에 로그인하거나 로그아웃하는 일을 맡는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "로그인하거나 로그아웃할 때 바쁠 수 있어요. 작업이 끝나면 줄어들어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["hidd"],
            process: KnownProcess(
                summary: String(localized: "키보드와 마우스 등의 입력을 받는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "키보드나 마우스 등을 사용할 때 바쁠 수 있어요. 입력이 멈추면 줄어들어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["notificationcenter"],
            process: KnownProcess(
                summary: String(localized: "앱 알림과 위젯을 보여 주는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "알림이 오거나 위젯 내용을 새로 받을 때 바쁠 수 있어요. 화면을 갱신하고 나면 줄어들어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["coreservicesd"],
            process: KnownProcess(
                summary: String(localized: "파일을 알맞은 앱으로 여는 일을 돕는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "앱을 설치하거나 파일을 열 때 바쁠 수 있어요. 관련 작업이 끝나면 줄어들어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["logd"],
            process: KnownProcess(
                summary: String(localized: "맥과 앱의 작동 기록을 남기는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "앱이 기록을 많이 남기면 바빠요. 기록이 줄어들면 조용해져요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["sharingd"],
            process: KnownProcess(
                summary: String(localized: "AirDrop 같은 기기 간 공유를 돕는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "주변 기기를 찾거나 파일을 공유할 때 바쁠 수 있어요. 공유 작업이 끝나면 줄어들어요."),
                advice: .leaveIt
            )
        ),
        Entry(
            names: ["nsurlsessiond"],
            process: KnownProcess(
                summary: String(localized: "앱이 화면에 없어도 파일을 주고받게 돕는 macOS 기본 프로그램이에요."),
                whenBusy: String(localized: "앱이 파일을 많이 받거나 보내면 바빠요. 주고받는 일이 끝나면 조용해져요."),
                advice: .leaveIt
            )
        )
    ]
}
