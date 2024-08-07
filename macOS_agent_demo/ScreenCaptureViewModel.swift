//
//  ScreenCaptureViewModel.swift
//  macOS_agent_demo
//
//  Created by 殷瑜 on 2024/7/28.
//

import SwiftUI
import Cocoa
import CoreGraphics
import os
import Carbon

let logger = Logger(subsystem: "com.yourapp.ScreencaptureViewModel", category: "EventMonitoring")

func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        logger.error("eventTapCallback: refcon is nil")
        return Unmanaged.passRetained(event)
    }
    
    let mySelf = Unmanaged<ScreencaptureViewModel>.fromOpaque(refcon).takeUnretainedValue()
    Task { @MainActor in
        mySelf.handleEvent(type: type, event: event)
    }
    
    return Unmanaged.passRetained(event)
}

extension Date {
    func format() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
        return formatter.string(from: self)
    }
}

@MainActor
class ScreencaptureViewModel: ObservableObject {
    enum ScreenshotType {
        case full, window, area
        
        var processArguments: [String] {
            switch self {
            case .full: return ["-c"]
            case .window: return ["-cw"]
            case .area: return ["-cs"]
            }
        }
    }
    
    @Published var images: [NSImage] = []
    @Published var savedImagePath: String = ""
    @Published var events: [String] = []
    @Published var monitorEvents: [String] = []
    @Published var mousePosition: String = "0, 0"
    @Published var isMonitoring: Bool = false
    @Published var errorMessage: String?
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var monitorWindow: NSWindow?
    private var activeModifiers: CGEventFlags = []
    
    init() {
        // 初始化时不再直接设置事件捕获
    }
    
    func takeScreenshot(for type: ScreenshotType) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = type.processArguments
        
        do {
            try task.run()
            task.waitUntilExit()
            getImageFromPasteboard()
        } catch {
            logger.error("Could not make a screenshot: \(error.localizedDescription)")
        }
    }
    
    private func convertImageToPNGData(image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImageRep = NSBitmapImageRep(data: tiffData) else {
            logger.error("Failed to create NSBitmapImageRep from NSImage")
            return nil
        }
        return bitmapImageRep.representation(using: .png, properties: [:])
    }
    
    private func getImageFromPasteboard() {
        guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else {
            logger.error("Failed to get image from pasteboard")
            return
        }
        
        if let pngData = convertImageToPNGData(image: image) {
            let fileManager = FileManager.default
            if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let directoryPath = documentsDirectory.appendingPathComponent("imageFolder")
                let filePath = directoryPath.appendingPathComponent("image_\(Date().timeIntervalSince1970).png")
                
                do {
                    try fileManager.createDirectory(at: directoryPath, withIntermediateDirectories: true, attributes: nil)
                    try pngData.write(to: filePath)
                    self.savedImagePath = filePath.path
                    logger.info("Image saved successfully at \(filePath.path)")
                    
                    if self.images.count >= 3 {
                        self.images.removeFirst()
                    }
                    self.images.append(image)
                } catch {
                    logger.error("Error saving image: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func setupEventTap() {
        let eventMask = createEventMask()
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            logger.error("Failed to create event tap")
            errorMessage = "无法创建事件捕获。请确保已授予必要的权限。"
            return
        }
        
        self.eventTap = eventTap
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        
        logger.info("Event tap setup completed successfully")
    }
    
    private func createEventMask() -> CGEventMask {
        var mask: CGEventMask = 0
        
        let eventTypes: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .mouseMoved, .scrollWheel
        ]
        
        for eventType in eventTypes {
            mask |= CGEventMask(1 << eventType.rawValue)
        }
        
        return mask
    }
    
    func handleEvent(type: CGEventType, event: CGEvent) {
        let timestamp = Date().format()
        var eventString = "\(timestamp)"
        
        switch type {
        case .keyDown, .keyUp, .flagsChanged:
            eventString += processKeyboardEvent(type: type, event: event)
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp:
            eventString += processMouseButtonEvent(type: type, event: event)
        case .mouseMoved:
            eventString += processMouseMoveEvent(event: event)
        case .scrollWheel:
            eventString += processScrollWheelEvent(event: event)
        default:
            return
        }
        
        addEvent(eventString)
        logger.debug("Processed event: \(eventString)")
    }
    
    private func processKeyboardEvent(type: CGEventType, event: CGEvent) -> String {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        switch type {
        case .flagsChanged:
            return processFlagsChanged(flags: flags, keyCode: UInt16(keyCode))
        case .keyDown, .keyUp:
            return processKeyEvent(type: type, keyCode: UInt16(keyCode), flags: flags)
        default:
            return ""
        }
    }
    
    private func processFlagsChanged(flags: CGEventFlags, keyCode: UInt16) -> String {
        let oldModifiers = activeModifiers
        activeModifiers = flags.intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand, .maskSecondaryFn, .maskAlphaShift])
        
        let changedModifiers = oldModifiers.symmetricDifference(activeModifiers)
        let modifierKey = modifierKeyForKeyCode(keyCode)
        
        if changedModifiers.contains(modifierFlagForKeyCode(keyCode)) {
            let action = activeModifiers.contains(modifierFlagForKeyCode(keyCode)) ? "press" : "release"
            return createKeyboardEventString(keyName: modifierKey, isSpecial: true, action: action)
        }
        
        return ""
    }
    
    private func processKeyEvent(type: CGEventType, keyCode: UInt16, flags: CGEventFlags) -> String {
        let keyName = getKeyName(keyCode, flags: flags)
        let isSpecial = isSpecialKey(keyCode)
        let action = type == .keyDown ? "press" : "release"
        
        return createKeyboardEventString(keyName: keyName, isSpecial: isSpecial, action: action)
    }
    
    private func createKeyboardEventString(keyName: String, isSpecial: Bool, action: String) -> String {
            let command: [String: String] = [
                "type": "key_press",
                "key": keyName,
                "special": isSpecial ? "true" : "false",
                "action": action
            ]
            
            let orderedKeys = ["type", "key", "special", "action"]
            let orderedValues = orderedKeys.map { command[$0] ?? "" }
            let jsonString = "{" + orderedKeys.enumerated().map { "\"\($1)\": \"\(orderedValues[$0])\"" }.joined(separator: ", ") + "}"
            
            return ",\(jsonString)"
        }
    
    private func getKeyName(_ keyCode: UInt16, flags: CGEventFlags) -> String {
        if let specialKeyName = specialKeyMap[keyCode] {
            return specialKeyName
        }
        
        if let keyName = keyMap[keyCode] {
            return keyName
        }
        
        return keyCodeToString(keyCode, flags: flags)
    }
    
    private func isSpecialKey(_ keyCode: UInt16) -> Bool {
        return specialKeyMap[keyCode] != nil
    }
    
    private func modifierKeyForKeyCode(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 56, 60: return "Shift"
        case 59, 62: return "Control"
        case 58, 61: return "Option"
        case 55, 54: return "Command"
        case 63: return "Fn"
        case 57: return "Caps Lock"
        default: return "Unknown"
        }
    }
    
    private func modifierFlagForKeyCode(_ keyCode: UInt16) -> CGEventFlags {
        switch keyCode {
        case 56, 60: return .maskShift
        case 59, 62: return .maskControl
        case 58, 61: return .maskAlternate
        case 55, 54: return .maskCommand
        case 63: return .maskSecondaryFn
        case 57: return .maskAlphaShift
        default: return []
        }
    }
    
    private func keyCodeToString(_ keyCode: UInt16, flags: CGEventFlags) -> String {
        guard let currentKeyboard = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData) else {
            logger.error("Failed to get keyboard layout data")
            return "Unknown"
        }
        
        let dataRef = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        
        var deadKeyState: UInt32 = 0
        var stringLength = 0
        var unicodeString = [UniChar](repeating: 0, count: 4)
        
        let shiftFlag = flags.contains(.maskShift) ? UInt32(shiftKey) : 0
        let capsLockFlag = flags.contains(.maskAlphaShift) ? UInt32(alphaLock) : 0
        
        UCKeyTranslate(dataRef.withUnsafeBytes { $0.bindMemory(to: UCKeyboardLayout.self).baseAddress },
                       UInt16(keyCode),
                       UInt16(kUCKeyActionDown),
                       shiftFlag | capsLockFlag,
                       UInt32(LMGetKbdType()),
                       OptionBits(kUCKeyTranslateNoDeadKeysBit),
                       &deadKeyState,
                       4,
                       &stringLength,
                       &unicodeString)
        
        let result = String(utf16CodeUnits: unicodeString, count: stringLength)
        if result.isEmpty {
            logger.debug("Unmapped key code: \(keyCode)")
            return "Unknown"
        }
        return result
    }
    
    private let keyMap: [UInt16: String] = [
        // 字母键
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 31: "O", 32: "U",
        34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        
        // 数字键
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 25: "9", 26: "7", 28: "8", 29: "0",
        
        // 符号键
        24:  "=", 27:  "-", 33:  "[", 30:  "]", 39:  "'", 41:  ";",
        42:  "\\", 43:  ",", 47:  ".", 44:  "/", 50:  "`",
        
        // 特殊字符键
        10:  "§"
    ]
    
    private let specialKeyMap: [UInt16: String] = [
        // 功能键
        122: "F1", 120: "F2", 99:  "F3", 118: "F4",
        96:  "F5", 97:  "F6", 98:  "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15", 106: "F16",
        64:  "F17", 79:  "F18", 80:  "F19", 90:  "F20",
        
        // 方向键
        123: "Left Arrow", 124: "Right Arrow", 125: "Down Arrow", 126: "Up Arrow",
        
        // 导航键
        115: "Home", 119: "End", 116: "Page Up", 121: "Page Down",
        
        // 编辑键
        51:  "Delete", 117: "Forward Delete", 36:  "Return",
        48:  "Tab", 49:  "Space", 53:  "Escape",
        
        // 系统键
        114: "Help",
        
        // 数字键盘键
        65:  "Keypad Decimal", 67:  "Keypad Multiply", 69:  "Keypad Plus",
        71:  "Keypad Clear", 75:  "Keypad Divide", 76:  "Keypad Enter",
        78:  "Keypad Minus", 81:  "Keypad Equals", 82:  "Keypad 0",
        83:  "Keypad 1", 84:  "Keypad 2", 85:  "Keypad 3", 86:  "Keypad 4",
        87:  "Keypad 5", 88:  "Keypad 6", 89:  "Keypad 7", 91:  "Keypad 8",
        92:  "Keypad 9",
        
        // 修饰键
        56:  "Shift (Left)", 60:  "Shift (Right)",
        59:  "Control (Left)", 62:  "Control (Right)",
        58:  "Option (Left)", 61:  "Option (Right)",
        55:  "Command (Left)", 54:  "Command (Right)",
        63:  "Fn", 57:  "Caps Lock"
    ]
    
    private func processMouseButtonEvent(type: CGEventType, event: CGEvent) -> String {
        let position = event.location
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        let action = getMouseEventName(type)
        
        let eventDict: [String: String] = [
            "type": "mouse_event",
            "action": action,
            "button": String(buttonNumber),
            "x": String(Int(position.x)),
            "y": String(Int(position.y))
        ]
        
        let orderedKeys = ["type", "action", "button", "x", "y"]
        let orderedValues = orderedKeys.map { eventDict[$0] ?? "" }
        let jsonString = "{" + orderedKeys.enumerated().map { "\"\($1)\": \"\(orderedValues[$0])\"" }.joined(separator: ", ") + "}"
        
        return ",\(jsonString)"
    }

    private func processMouseMoveEvent(event: CGEvent) -> String {
        let position = event.location
        updateMousePosition(position)
        
        let eventDict: [String: String] = [
            "type": "mouse_move",
            "x": String(Int(position.x)),
            "y": String(Int(position.y))
        ]
        
        let orderedKeys = ["type", "x", "y"]
        let orderedValues = orderedKeys.map { eventDict[$0] ?? "" }
        let jsonString = "{" + orderedKeys.enumerated().map { "\"\($1)\": \"\(orderedValues[$0])\"" }.joined(separator: ", ") + "}"
        
        return ",\(jsonString)"
    }

    private func processScrollWheelEvent(event: CGEvent) -> String {
        let deltaY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        
        let eventDict: [String: String] = [
            "type": "scroll_wheel",
            "deltaY": String(deltaY)
        ]
        
        let orderedKeys = ["type", "deltaY"]
        let orderedValues = orderedKeys.map { eventDict[$0] ?? "" }
        let jsonString = "{" + orderedKeys.enumerated().map { "\"\($1)\": \"\(orderedValues[$0])\"" }.joined(separator: ", ") + "}"
        
        return ",\(jsonString)"
    }

    private func createJSONString(from dict: [String: String]) -> String {
        let orderedKeys = dict.keys.sorted()
        let orderedValues = orderedKeys.map { dict[$0] ?? "" }
        let jsonString = "{" + orderedKeys.enumerated().map { "\"\($1)\": \"\(orderedValues[$0])\"" }.joined(separator: ", ") + "}"
        return jsonString
    }

    private func addEvent(_ eventString: String) {
        events.append(eventString)
        if isMonitoring {
            monitorEvents.append(eventString)
        }
    }

    private func updateMousePosition(_ position: CGPoint) {
        mousePosition = "\(Int(position.x)), \(Int(position.y))"
    }

    private func getMouseEventName(_ type: CGEventType) -> String {
        switch type {
        case .leftMouseDown, .rightMouseDown:
            return "press"
        case .leftMouseUp, .rightMouseUp:
            return "release"
        default:
            return "unknown"
        }
    }
    
    func startMonitoring() {
        logger.info("Starting monitoring")
        
        if !checkAccessibilityPermission() {
            errorMessage = "请在系统偏好设置中授予应用程序辅助功能权限以启用监控功能。"
            return
        }
        
        isMonitoring = true
        monitorEvents.removeAll()
        
        if eventTap == nil {
            setupEventTap()
        }
        
        if let currentEventTap = eventTap {
            CGEvent.tapEnable(tap: currentEventTap, enable: true)
            logger.info("Event tap enabled")
            openMonitorWindow()
            logger.info("Monitor window opened")
        } else {
            logger.error("Failed to create event tap")
            errorMessage = "无法启动监控。请检查应用程序权限并重试。"
            isMonitoring = false
        }
    }
    
    func stopMonitoring() {
        logger.info("Stopping monitoring")
        
        // 禁用事件监控
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            logger.info("Event tap disabled")
        }
        
        // 关闭监控窗口
        closeMonitorWindow()
        logger.info("Monitor window closed")
        
        isMonitoring = false
        
        // 确保 eventTap 和 runLoopSource 已正确释放和移除
        if let eventTap = eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
            logger.info("Event tap invalidated and set to nil")
        }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
            logger.info("Run loop source removed and set to nil")
        }
    }

    private func openMonitorWindow() {
        let monitorView = MonitorWindow(viewModel: self)
        let hostingController = NSHostingController(rootView: monitorView)
        monitorWindow = NSWindow(contentViewController: hostingController)
        monitorWindow?.title = "事件监控"
        monitorWindow?.makeKeyAndOrderFront(nil)
    }
    
    private func closeMonitorWindow() {
        monitorWindow?.close()
        monitorWindow = nil
    }
    
    func exportToCSV() {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Unable to access documents directory")
            errorMessage = "无法访问文档目录"
            return
        }
        
        let fileName = "monitor_events_\(Int(Date().timeIntervalSince1970)).csv"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        let csvHeader = "Timestamp,Command\n"
        var csvString = csvHeader
        
        for event in monitorEvents {
            let components = event.components(separatedBy: ",")
            if components.count >= 2 {
                let timestamp = components[0]
                let command = components.dropFirst().joined(separator: ",")
                csvString += "\(timestamp),\(command)\n"
            }
        }
        
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            logger.info("CSV file exported successfully: \(fileURL.path)")
            DispatchQueue.main.async {
                self.errorMessage = "CSV文件导出成功：\(fileURL.path)"
            }
        } catch {
            logger.error("Failed to export CSV file: \(error.localizedDescription)")
            errorMessage = "导出CSV文件失败：\(error.localizedDescription)"
        }
    }
    
    private func checkAccessibilityPermission() -> Bool {
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options = [checkOptPrompt: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    deinit {
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
    }
}

extension CGEvent {
    func keyboardGetUnicodeString() -> (string: String, length: Int) {
        var length = 0
        let maxLength = 4
        var chars = [UniChar](repeating: 0, count: maxLength)
        self.keyboardGetUnicodeString(maxStringLength: maxLength, actualStringLength: &length, unicodeString: &chars)
        return (String(utf16CodeUnits: chars, count: length), length)
    }
}


