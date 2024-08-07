//
//  Eventsimulator.swift
//  macOS_agent_demo
//
//  Created by 殷瑜 on 2024/7/28.
//

import Foundation
import Cocoa
import Carbon


class EventSimulator {
    static var simulationDelay: UInt32 = 50000 // 默认为 50 毫秒

    private static var activeModifiers: CGEventFlags = []

    static func simulateEventsFromCSV(filePath: String) {
        print("Reading CSV file at path: \(filePath)")
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            print("Failed to read CSV file")
            return
        }
        
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            print("CSV file is empty or contains only header")
            return
        }
        
        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            
            let components = line.components(separatedBy: ",")
            guard components.count >= 2 else { continue }
            
            let timestamp = components[0]
            let commandJson = components.dropFirst().joined(separator: ",")
            
            print("Processing JSON command: \(commandJson)")
            
            // Escape the backslash character in the JSON string
            let escapedCommandJson = commandJson.replacingOccurrences(of: "\\\"", with: "\\\\\"")
            
            guard let data = escapedCommandJson.data(using: .utf8),
                  let command = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String] else {
                print("Failed to parse command JSON: \(commandJson)")
                continue
            }
            
            let eventType = command["type"] ?? ""
            let keyName = command["key"] ?? ""
            let action = command["action"] ?? ""
            
            switch eventType {
            case "key_press":
                 if isModifierKey(keyName) {
                    simulateModifierChange(action: action, modifiers: keyName)
                } else {
                    simulateKeyboardEvent(action: action, keyName: keyName)
                }
            case "mouse_event":
                if let button = Int(command["button"] ?? ""), let x = Double(command["x"] ?? ""), let y = Double(command["y"] ?? "") {
                    simulateMouseEvent(action: action, button: button, x: CGFloat(x), y: CGFloat(y))
                }
            case "mouse_move":
                if let x = Double(command["x"] ?? ""), let y = Double(command["y"] ?? "") {
                    simulateMouseMove(x: CGFloat(x), y: CGFloat(y))
                }
            case "scroll_wheel":
                if let deltaY = Int32(command["deltaY"] ?? "") {
                    simulateScrollWheel(deltaY: deltaY)
                }
            default:
                break
            }

            
            usleep(simulationDelay)
        }
    }


    
    
    private static func isModifierKey(_ keyName: String) -> Bool {
        let modifierKeys = ["shift", "control", "option", "command", "fn", "caps lock"]
        return modifierKeys.contains(keyName.lowercased())
    }


    private static func simulateModifierChange(action: String, modifiers: String) {
        let isKeyDown = action.contains("press")
        let modifierFlags = getModifierFlags(modifiers)
        
        if isKeyDown {
            activeModifiers.insert(modifierFlags)
        } else {
            activeModifiers.subtract(modifierFlags)
        }
        
        let keyCode = keyCodeForModifier(modifiers)
        let eventSource = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: isKeyDown) else { return }
        event.flags = activeModifiers
        event.post(tap: .cghidEventTap)
        
        print("Simulated modifier change: \(modifiers) \(action)")
    }

    private static func simulateKeyboardEvent(action: String, keyName: String) {
        let keyCode = stringToKeyCode(keyName)
        
        if keyCode == 0xFF {
            print("Warning: Unable to translate key name '\(keyName)' to key code")
            return
        }
        
        let keyDown = action == "press"
        
        let eventSource = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: keyDown) else {
            print("Error: Failed to create CGEvent for key '\(keyName)'")
            return
        }
        
        event.flags = activeModifiers
        event.post(tap: .cghidEventTap)
        
        print("Simulated keyboard event: \(keyName) \(action)")
    }

    private static func simulateMouseEvent(action: String, button: Int, x: CGFloat, y: CGFloat) {
        let eventSource = CGEventSource(stateID: .hidSystemState)
        let buttonDown = action == "press"
        let eventType: CGEventType
        
        switch button {
        case 0:
            eventType = buttonDown ? .leftMouseDown : .leftMouseUp
        case 1:
            eventType = buttonDown ? .rightMouseDown : .rightMouseUp
        default:
            return
        }
        
        guard let event = CGEvent(mouseEventSource: eventSource, mouseType: eventType, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: CGMouseButton(rawValue: UInt32(button))!) else {
            return
        }
        event.post(tap: .cghidEventTap)
        
        print("Simulated mouse event: button \(button) \(action) at (\(x), \(y))")
    }
    
    private static func simulateMouseMove(x: CGFloat, y: CGFloat) {
        let eventSource = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(mouseEventSource: eventSource, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left) else {
            return
        }
        event.post(tap: .cghidEventTap)
        
        print("Simulated mouse move to (\(x), \(y))")
    }

    private static func simulateScrollWheel(deltaY: Int32) {
        let eventSource = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(scrollWheelEvent2Source: eventSource, units: .pixel, wheelCount: 1, wheel1: deltaY, wheel2: 0, wheel3: 0) else {
            return
        }
        event.post(tap: .cghidEventTap)
        
        print("Simulated scroll wheel with deltaY \(deltaY)")
    }

    private static func keyCodeForModifier(_ modifier: String) -> CGKeyCode {
        switch modifier.lowercased() {
        case "shift": return 56
        case "control": return 59
        case "option": return 58
        case "command": return 55
        case "fn": return 63
        case "caps lock": return 57  // 添加对 Caps Lock 的处理
        default: return 0xFF
        }
    }

    private static func getModifierFlags(_ modifierString: String) -> CGEventFlags {
        var flags: CGEventFlags = []
        
        if modifierString.contains("Shift") { flags.insert(.maskShift) }
        if modifierString.contains("Control") { flags.insert(.maskControl) }
        if modifierString.contains("Option") { flags.insert(.maskAlternate) }
        if modifierString.contains("Command") { flags.insert(.maskCommand) }
        if modifierString.contains("Fn") { flags.insert(.maskSecondaryFn) }
        if modifierString.contains("Caps Lock") { flags.insert(.maskAlphaShift) }  // 添加对 Caps Lock 的处理
        
        return flags
    }

    private static func stringToKeyCode(_ keyName: String) -> CGKeyCode {
        let keyCodeMap: [String: CGKeyCode] = [
            // 字母键
            "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E, "f": 0x03, "g": 0x05, "h": 0x04,
            "i": 0x22, "j": 0x26, "k": 0x28, "l": 0x25, "m": 0x2E, "n": 0x2D, "o": 0x1F, "p": 0x23,
            "q": 0x0C, "r": 0x0F, "s": 0x01, "t": 0x11, "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07,
            "y": 0x10, "z": 0x06,
            // 符号键
            "=": 0x18, "-": 0x1B, "[": 0x21, "]": 0x1E, "\\": 0x2A, ";": 0x29, "'": 0x27, ",": 0x2B, ".": 0x2F, "/": 0x2C, "`": 0x32,
            
            // 数字键
            "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17, "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D,
            
            // 功能键
            "f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76, "f5": 0x60, "f6": 0x61, "f7": 0x62, "f8": 0x64,
            "f9": 0x65, "f10": 0x6D, "f11": 0x67, "f12": 0x6F, "f13": 0x69, "f14": 0x6B, "f15": 0x71,
            "f16": 0x6A, "f17": 0x40, "f18": 0x4F, "f19": 0x50, "f20": 0x5A,

            // 方向键
            "left arrow": 0x7B, "right arrow": 0x7C, "down arrow": 0x7D, "up arrow": 0x7E,
            
            // 导航键
            "home": 0x73, "end": 0x77, "page up": 0x74, "page down": 0x79,
            
            // 编辑键
            "delete": 0x33, "forward delete": 0x75, "return": 0x24, "tab": 0x30, "space": 0x31, "escape": 0x35,
            
            // 系统键
            "help": 0x72, "insert": 0x72,
            
            // 数字键盘键
            "keypad decimal": 0x41, "keypad multiply": 0x43, "keypad plus": 0x45, "keypad clear": 0x47,
            "keypad divide": 0x4B, "keypad enter": 0x4C, "keypad minus": 0x4E, "keypad equals": 0x51,
            "keypad 0": 0x52, "keypad 1": 0x53, "keypad 2": 0x54, "keypad 3": 0x55, "keypad 4": 0x56,
            "keypad 5": 0x57, "keypad 6": 0x58, "keypad 7": 0x59, "keypad 8": 0x5B, "keypad 9": 0x5C,

            // 修饰键
            "shift (left)": 0x38, "shift (right)": 0x3C,
            "control (left)": 0x3B, "control (right)": 0x3E,
            "option (left)": 0x3A, "option (right)": 0x3D,
            "command (left)": 0x37, "command (right)": 0x36,
            "fn": 0x3F, "caps lock": 0x39
        ]
        return keyCodeMap[keyName.lowercased()] ?? 0xFF
    }
}


