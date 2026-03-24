import Foundation
import AppKit

class WindowSnapper {
    private let snapThreshold: CGFloat = 300.0

    func execute() {
        let screens = NSScreen.screens
        guard let mainScreen = screens.first else { return }
        let mainHeight = mainScreen.frame.height
        
        let monitors = screens.map { MonitorBoundary(screen: $0, mainHeight: mainHeight) }
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return }
        let runningApps = NSWorkspace.shared.runningApplications
        
        for info in windowList {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  var window = WindowEntity(info) else { continue }
            
            let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
            guard let monitor = monitors.first(where: { $0.fullFrame.contains(center) }) else { continue }
            
            if calculate(window: &window, monitor: monitor) {
                apply(window: window, apps: runningApps)
            }
        }
    }

    private func calculate(window: inout WindowEntity, monitor: MonitorBoundary) -> Bool {
        let f = window.frame
        
        // [1] 현재 4개 면의 좌표를 상수로 고정
        let curL = f.minX
        let curR = f.maxX
        let curT = f.minY
        let curB = f.maxY
        
        // [2] 목표 좌표 초기값 (현재 값)
        var targetL = curL
        var targetR = curR
        var targetT = curT
        var targetB = curB
        
        var isChanged = false

        // [3] 독립 판정: else if를 쓰지 않고 모든 면을 개별 체크
        // 이렇게 해야 왼쪽이 붙으면서 동시에 오른쪽도 늘어납니다.
        if abs(curL - monitor.left) < snapThreshold { targetL = monitor.left; isChanged = true }
        if abs(curR - monitor.right) < snapThreshold { targetR = monitor.right; isChanged = true }
        if abs(curT - monitor.top) < snapThreshold { targetT = monitor.top; isChanged = true }
        if abs(curB - monitor.bottom) < snapThreshold { targetB = monitor.bottom; isChanged = true }

        if isChanged {
            let nextFrame = CGRect(x: targetL, y: targetT, width: targetR - targetL, height: targetB - targetT)
            
            // 터미널/Gemini 앱의 글자 격자 오차(25px) 허용치 적용
            let diffL = abs(f.origin.x - nextFrame.origin.x)
            let diffW = abs(f.size.width - nextFrame.size.width)
            let diffT = abs(f.origin.y - nextFrame.origin.y)
            let diffH = abs(f.size.height - nextFrame.size.height)

            // 1px 이상의 변화가 있고, 아직 25px 이상의 유격이 있다면 실행
            if (diffL > 1.0 || diffW > 1.0 || diffT > 1.0 || diffH > 1.0) && 
               (diffL > 25 || diffW > 25 || diffT > 25 || diffH > 25) {
                window.frame = nextFrame
                return true
            }
        }
        return false
    }

    private func apply(window: WindowEntity, apps: [NSRunningApplication]) {
        guard let app = apps.first(where: { $0.localizedName == window.owner }) else { return }
        let appRef = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?
        
        if AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef) == .success,
        let list = windowsRef as? [AXUIElement] {
            for axWin in list {
                var id: CGWindowID = 0
                _ = _AXUIElementGetWindow(axWin, &id)
                if id == window.id {
                    let targetSize = window.frame.size
                    let targetPos = window.frame.origin
                    
                    // [핵심] OS와 앱의 간섭을 무시하고 0.05초 동안 최대 5번 강제 반복
                    for _ in 1...5 {
                        var s = targetSize
                        var p = targetPos
                        
                        // 1. 위치와 크기를 거의 동시에 계속 주입
                        AXUIElementSetAttributeValue(axWin, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &p)!)
                        AXUIElementSetAttributeValue(axWin, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &s)!)
                        
                        // 2. 현재 상태 확인
                        var curP: CFTypeRef?; var curS: CFTypeRef?
                        AXUIElementCopyAttributeValue(axWin, kAXPositionAttribute as CFString, &curP)
                        AXUIElementCopyAttributeValue(axWin, kAXSizeAttribute as CFString, &curS)
                        
                        if let cpRef = curP, let csRef = curS {
                            var cp = CGPoint.zero; var cs = CGSize.zero
                            AXValueGetValue(cpRef as! AXValue, .cgPoint, &cp)
                            AXValueGetValue(csRef as! AXValue, .cgSize, &cs)
                            
                            // 5px 이내로 들어왔으면 "승리"하고 루프 탈출
                            if abs(cp.x - targetPos.x) < 5 && abs(cs.width - targetSize.width) < 5 {
                                break
                            }
                        }
                        // 0.01초 대기 (앱이 명령을 처리할 최소한의 시간)
                        usleep(10000)
                    }
                    break
                }
            }
        }
    }
}

struct MonitorBoundary {
    let fullFrame: CGRect
    let left, right, top, bottom: CGFloat
    
    init(screen: NSScreen, mainHeight: CGFloat) {
        let f = screen.frame
        let vf = screen.visibleFrame
        self.fullFrame = f
        
        // 절대 좌표 기반으로 재계산
        self.left = vf.origin.x
        self.right = vf.origin.x + vf.size.width
        self.top = mainHeight - (vf.origin.y + vf.size.height)
        self.bottom = self.top + vf.size.height
    }
}

struct WindowEntity {
    let id: CGWindowID
    let owner: String
    var frame: CGRect
    
    init?(_ info: [String: Any]) {
        guard let id = info[kCGWindowNumber as String] as? CGWindowID,
              let owner = info[kCGWindowOwnerName as String] as? String,
              let b = info[kCGWindowBounds as String] as? [String: Any],
              let x = b["X"] as? CGFloat, let y = b["Y"] as? CGFloat,
              let w = b["Width"] as? CGFloat, let h = b["Height"] as? CGFloat else { return nil }
        self.id = id; self.owner = owner; self.frame = CGRect(x: x, y: y, width: w, height: h)
    }
}

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: inout CGWindowID) -> AXError

WindowSnapper().execute()