// 앱의 본 창 CGWindowID를 찍는다.
//
// 영역 캡처(`-R`)는 그 자리에 떠 있는 알림 배너까지 함께 찍힌다.
// 창 캡처(`-l <id>`)는 그 창의 콘텐츠만 가져오므로 판정 화면이 오염되지 않는다.
import CoreGraphics
import Foundation

let owners: Set<String> = ["Sweep", "SweepApp"]

/// 선택 인자로 PID를 받으면 **그 프로세스의 창만** 고른다.
///
/// 이름으로만 고르면 사용자가 따로 띄워 둔 Sweep을 찍는다 —
/// 실제로 어댑터가 남의 창을 찍어 검증이 통째로 헛돌았다.
let wantedPID = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) : nil

guard let list = CGWindowListCopyWindowInfo(
    [.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
    exit(1)
}

var best: (id: Int, area: Double)?
for w in list {
    guard let owner = w[kCGWindowOwnerName as String] as? String, owners.contains(owner),
          wantedPID == nil || (w[kCGWindowOwnerPID as String] as? Int) == wantedPID,
          let id = w[kCGWindowNumber as String] as? Int,
          // layer 0 = 일반 창. 메뉴 막대 패널은 더 높은 layer에 뜬다.
          let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
          let b = w[kCGWindowBounds as String] as? [String: Any],
          let width = b["Width"] as? Double, let height = b["Height"] as? Double,
          // 타이틀바 조각(높이 30짜리)들을 거른다
          height > 100
    else { continue }
    let area = width * height
    if best == nil || area > best!.area { best = (id, area) }
}

guard let best else {
    FileHandle.standardError.write("Sweep 창을 찾을 수 없다\n".data(using: .utf8)!)
    exit(1)
}
print(best.id)
