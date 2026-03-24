import Foundation
import CoreGraphics
import AppKit

let layoutFilePath = "layout.json"

struct WindowLayout: Codable {
    let owner: String
    let title: String
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

// 1. 현재 레이아웃 추출 함수
func getCurrentLayout() -> [WindowLayout] {
    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
    let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
    
    return windowList.compactMap { window in
        guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else { return nil }
        let owner = window[kCGWindowOwnerName as String] as? String ?? ""
        let title = window[kCGWindowName as String] as? String ?? ""
        let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
        
        return WindowLayout(
            owner: owner,
            title: title,
            x: Int(bounds["X"] as? CGFloat ?? 0),
            y: Int(bounds["Y"] as? CGFloat ?? 0),
            width: Int(bounds["Width"] as? CGFloat ?? 0),
            height: Int(bounds["Height"] as? CGFloat ?? 0)
        )
    }
}

// 2. 레이아웃 저장 기능
func saveLayout() {
    let layout = getCurrentLayout()
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    
    if let data = try? encoder.encode(layout) {
        try? data.write(to: URL(fileURLWithPath: layoutFilePath))
        print("✅ 현재 레이아웃이 '\(layoutFilePath)'에 저장되었습니다.")
    }
}

// 3. 레이아웃 복구 기능 (Accessibility API 사용)
func restoreLayout() {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: layoutFilePath)),
          let savedLayouts = try? JSONDecoder().decode([WindowLayout].self, from: data) else {
        print("❌ 저장된 레이아웃 파일을 찾을 수 없습니다.")
        return
    }
    
    let runningApps = NSWorkspace.shared.runningApplications
    
    for saved in savedLayouts {
        // 1. 앱 이름(owner)으로 실행 중인 앱 찾기
        if let app = runningApps.first(where: { $0.localizedName == saved.owner }) {
            let appRef = AXUIElementCreateApplication(app.processIdentifier)
            var windowList: CFTypeRef?
            
            if AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowList) == .success,
               let windows = windowList as? [AXUIElement] {
                
                // 2. 해당 앱의 창들을 하나씩 대조
                for (index, window) in windows.enumerated() {
                    var titleValue: CFTypeRef?
                    AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
                    let currentTitle = titleValue as? String ?? ""
                    
                    // 핵심 매칭 로직: 
                    // - 저장된 타이틀과 현재 창 타이틀이 일치하거나
                    // - 저장된 타이틀이 비어있고 현재 앱의 순서(index)가 맞을 때 처리
                    let isTitleMatch = (currentTitle == saved.title)
                    let isEmptyTitleMatch = (saved.title == "" && index == 0) // 타이틀이 없으면 첫 번째 창으로 간주
                    
                    if isTitleMatch || isEmptyTitleMatch || (saved.owner == "Terminal" && index == 0) {
                        
                        // 위치 이동 (Position)
                        var newPoint = CGPoint(x: saved.x, y: saved.y)
                        if let posRef = AXValueCreate(.cgPoint, &newPoint) {
                            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posRef)
                        }
                        
                        // 크기 조절 (Size)
                        var newSize = CGSize(width: saved.width, height: saved.height)
                        if let sizeRef = AXValueCreate(.cgSize, &newSize) {
                            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeRef)
                        }
                        
                        print("🚀 [\(saved.owner)] '\(currentTitle)' 창을 (\(saved.x), \(saved.y)) 위치로 복구했습니다.")
                        break // 매칭 성공 시 다음 저장 데이터로
                    }
                }
            }
        }
    }
    print("✨ 레이아웃 복구 시도가 완료되었습니다.")
}

// 실행 로직
let args = CommandLine.arguments
if args.count < 2 {
    print("사용법: swift layout_manager.swift [save | restore]")
} else if args[1] == "save" {
    saveLayout()
} else if args[1] == "restore" {
    restoreLayout()
}
