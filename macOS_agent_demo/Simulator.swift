//
//  Simulator.swift
//  macOS_agent_demo
//
//  Created by 殷瑜 on 2024/8/28.
//

import Foundation
import ApplicationServices

class Simulator {
    
    let keyCodeMapping = EventMasks.keyCodeMapping
    
    // Function to simulate a key press or release event
    func simulateKeyEvent(keyCode: CGKeyCode, keyDown: Bool) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown) else { return }
        event.post(tap: .cghidEventTap)
    }
    
    // Function to simulate typing a string
    func simulateTyping(unicodeString: String) {
        guard !unicodeString.isEmpty else { return }
        let characters = Array(unicodeString.utf16)
        
        for char in characters {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else { continue }
            event.keyboardSetUnicodeString(stringLength: 1, unicodeString: [char])
            event.post(tap: .cghidEventTap)
            
            guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else { continue }
            keyUpEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: [char])
            keyUpEvent.post(tap: .cghidEventTap)
        }
    }
    
    // Function to simulate pressing and releasing a key
    func simulateKeyPress(keyCode: CGKeyCode) {
        simulateKeyEvent(keyCode: keyCode, keyDown: true)
        simulateKeyEvent(keyCode: keyCode, keyDown: false)
    }
    
    // Function to simulate a mouse click
    func simulateMouseClick(at position: CGPoint, button: CGMouseButton, clickCount: Int = 1) {
        for i in 1...clickCount {
            guard let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: position, mouseButton: button),
                  let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: position, mouseButton: button) else { continue }
            
            mouseDown.setIntegerValueField(.mouseEventClickState, value: Int64(i))
            mouseDown.post(tap: .cghidEventTap)
            
            mouseUp.setIntegerValueField(.mouseEventClickState, value: Int64(i))
            mouseUp.post(tap: .cghidEventTap)
            
            usleep(100_000)
        }
    }
    
    // Unified function to handle keyboard input based on action and key
    func handleKeyEvent(action: String, argument: String) {
        guard let keyCode = keyCodeMapping[argument.lowercased()] else {
            print("Key not found for command: \(argument)")
            return
        }
        
        switch action {
        case "key-down":
            simulateKeyEvent(keyCode: keyCode, keyDown: true)
        case "key-up":
            simulateKeyEvent(keyCode: keyCode, keyDown: false)
        case "press":
            simulateKeyPress(keyCode: keyCode)
        default:
            print("Unknown key action: \(action)")
        }
    }
    
    // Function to parse and handle different commands
    func handleCommand(_ command: String) {
        let components = command.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        
        guard components.count == 2 else {
            print("Invalid command format")
            return
        }
        
        let action = components[0]
        let argument = String(components[1])
        
        switch action {
        case "key-down", "key-up", "press":
            handleKeyEvent(action: String(action), argument: argument)
        case "type":
            simulateTyping(unicodeString: argument)
        case "click":
            if let position = parseClickPosition(argument) {
                simulateMouseClick(at: position, button: .left)
            } else {
                print("Invalid position format: \(argument)")
            }
        case "double-click":
            if let position = parseClickPosition(argument) {
                simulateMouseClick(at: position, button: .left, clickCount: 2)
            } else {
                print("Invalid position format: \(argument)")
            }
        case "right-click":
            if let position = parseClickPosition(argument) {
                simulateMouseClick(at: position, button: .right)
            } else {
                print("Invalid position format: \(argument)")
            }
        case "Multi-click":
            if let (position, times) = parseMultiClickPosition(argument) {
                simulateMouseClick(at: position, button: .left, clickCount: times)
            } else {
                print("Invalid position format: \(argument)")
            }
        case "scroll":
            if let scrollAmount = Double(argument) {
                simulateMouseScroll(amount: scrollAmount)
            } else {
                print("Invalid scroll amount: \(argument)")
            }
        case "move":
            if let position = parseClickPosition(argument) {
                simulateMoveMouse(to: position)
            } else {
                print("Invalid position format: \(argument)")
            }
        case "hold-click":
            if let (position, key) = parseHoldClickPosition(argument) {
                if let keyCode = keyCodeMapping[key] {
                    simulateKeyEvent(keyCode: keyCode, keyDown: true)
                }
                simulateMoveMouse(to: position)
                simulateMouseClick(at: position, button: .left)
                if let keyCode = keyCodeMapping[key] {
                    simulateKeyEvent(keyCode: keyCode, keyDown: false)
                }
            } else {
                print("Invalid hold-click format: \(argument)")
            }
        case "scroll-to":
            if let position = parseClickPosition(argument) {
                simulateMoveMouse(to: position)
                simulateMouseScroll(amount: 300)
            } else {
                print("Invalid position format: \(argument)")
            }
        case "batch":
            let commands = parseBatchCommands(argument)
            for cmd in commands {
                handleCommand(cmd)
            }
        case "drag":
            if let positions = parseDragPositions(argument) {
                let (startPoint, endPoint) = positions
                simulateMouseDrag(from: startPoint, to: endPoint)
            } else {
                print("Invalid drag positions format: \(argument)")
            }
        case "shortcut":
            if let keyCodes = parseShortcutKeys(argument) {
                simulateShortcut(keys: keyCodes)
            } else {
                print("Invalid shortcut format: \(argument)")
            }
        case "autocomplete-text":
            if let (prefix, options) = parseAutoComplete(argument) {
                autocompleteText(prefix: prefix, option: options)
            } else {
                print("Invalid autocomplete-text format: \(argument)")
            }
        case "touchpad":
            simulateTouchpadAction(argument: argument)
        case "special_gesture_mac":
            handleSpecialGestureMac(argument: argument)
        default:
            print("Unknown action: \(action)")
        }
    }
    
    func handleSpecialGestureMac(argument: String) {
        switch argument {
        case "enter_exit_full_screen", "toggle_full_screen":
            // Command + Control + F
            simulateKeyStroke(virtualKey: 0x3, flags: [.maskCommand, .maskControl])
        case "minimize_window":
            // Command + M
            simulateKeyStroke(virtualKey: 0x2E, flags: .maskCommand)
        case "close_window":
            // Command + W
            simulateKeyStroke(virtualKey: 0xD, flags: .maskCommand)
        default:
            print("Invalid special_gesture_mac argument: \(argument)")
            return
        }
        
        print("Successfully executed \(argument) action.")
    }
    
    // Function to simulate a shortcut (multiple keys pressed simultaneously)
    func simulateShortcut(keys: [CGKeyCode]) {
        for keyCode in keys {
            simulateKeyEvent(keyCode: keyCode, keyDown: true)
        }
        for keyCode in keys.reversed() {
            simulateKeyEvent(keyCode: keyCode, keyDown: false)
        }
    }
    
    // Parsing functions for mouse positions, drag positions, and shortcut keys
    func parseClickPosition(_ argument: String) -> CGPoint? {
        let components = argument.split(separator: ",")
        guard components.count == 2, let x = Double(components[0]), let y = Double(components[1]) else {
            return nil
        }
        return CGPoint(x: x, y: y)
    }
    
    func parseMultiClickPosition(_ argument: String) -> (CGPoint, Int)? {
        let components = argument.split(separator: ",")
        guard components.count == 3, let x = Double(components[0]), let y = Double(components[1]), let times = Int(components[2]) else {
            return nil
        }
        return (CGPoint(x: x, y: y), times)
    }
    
    func parseDragPositions(_ argument: String) -> (CGPoint, CGPoint)? {
        let components = argument.split(separator: ",")
        guard components.count == 4, let x1 = Double(components[0]), let y1 = Double(components[1]), let x2 = Double(components[2]), let y2 = Double(components[3]) else {
            return nil
        }
        return (CGPoint(x: x1, y: y1), CGPoint(x: x2, y: y2))
    }
    
    func parseShortcutKeys(_ argument: String) -> [CGKeyCode]? {
        let keys = argument.split(separator: "+").compactMap { keyCodeMapping[String($0)] }
        return keys.isEmpty ? nil : keys
    }
    
    func parseHoldClickPosition(_ argument: String) -> (CGPoint, String)? {
        let components = argument.split(separator: ",")
        guard components.count == 3, let x = Double(components[0]), let y = Double(components[1]) else {
            return nil
        }
        return (CGPoint(x: x, y: y), String(components[2]))
    }
    
    func parseAutoComplete(_ argument: String) -> (String, String)? {
        let texts = argument.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        guard texts.count == 2 else { return nil }
        let prefix = String(texts[0])
        let options = String(texts[1])
        return (prefix, options)
    }
    
    // Function to simulate mouse scrolling
    func simulateMouseScroll(amount: Double) {
        guard let location = getCurrentMouseLocation() else { return }
        if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: Int32(amount), wheel2: 0, wheel3: 0) {
            scrollEvent.location = location
            scrollEvent.post(tap: .cghidEventTap)
        }
    }
    
    // Function to simulate mouse movement
    func simulateMoveMouse(to position: CGPoint) {
        let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: position, mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)
    }
    
    // Function to simulate mouse dragging
    func simulateMouseDrag(from startPoint: CGPoint, to endPoint: CGPoint, duration: TimeInterval = 1.0) {
        guard let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: startPoint, mouseButton: .left) else { return }
        mouseDown.post(tap: .cghidEventTap)
        
        let steps = 5
        let xDelta = (endPoint.x - startPoint.x) / CGFloat(steps)
        let yDelta = (endPoint.y - startPoint.y) / CGFloat(steps)
        
        for i in 0...steps {
            let x = startPoint.x + (CGFloat(i) * xDelta)
            let y = startPoint.y + (CGFloat(i) * yDelta)
            if let mouseDrag = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left) {
                mouseDrag.post(tap: .cghidEventTap)
                usleep(useconds_t(duration * 1000000 / Double(steps)))
            }
        }
        
        if let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: endPoint, mouseButton: .left) {
            mouseUp.post(tap: .cghidEventTap)
        }
    }
    
    // Function to simulate AppleScript for touchpad gestures
    func simulateTouchpadAction(argument: String) {
        let keyCode: Int
        
        switch argument {
        case "swipe left":
            keyCode = 123
        case "swipe right":
            keyCode = 124
        case "swipe up":
            keyCode = 126
        case "swipe down":
            keyCode = 125
        case "zoom out":
            keyCode = 27
        case "zoom reset":
            keyCode = 29
        case "zoom in":
            keyCode = 24
        default:
            print("Invalid direction specified")
            return
        }
        
        let appleScript = """
        tell application "System Events"
            key down control
            key code \(keyCode)
            key up control
        end tell
        """
        
        let success = executeAppleScriptWithOSAScript(script: appleScript)
        if success {
            print("Successfully simulated \(argument).")
        } else {
            print("Failed to simulate \(argument).")
        }
    }
    
    // Function to execute AppleScript for window control actions
    func executeAppleScriptForWindowControl(action: String) {
        let appleScript: String
        
        switch action {
        case "fullscreen":
            appleScript = """
            tell application "System Events"
                keystroke "f" using {control down, command down}
            end tell
            """
        case "minimize":
            appleScript = """
            tell application "System Events"
                keystroke "m" using {command down}
            end tell
            """
        case "close":
            appleScript = """
            tell application "System Events"
                keystroke "w" using {command down}
            end tell
            """
        default:
            print("Invalid window control action: \(action)")
            return
        }
        
        let success = executeAppleScriptWithOSAScript(script: appleScript)
        if success {
            print("Successfully executed \(action) action.")
        } else {
            print("Failed to execute \(action) action.")
        }
    }
    
    // Function to toggle full screen using AppleScript
    func toggleFullScreen() {
        let appleScript = """
        tell application "System Events"
            keystroke "f" using {control down, command down}
        end tell
        """
        let success = executeAppleScriptWithOSAScript(script: appleScript)
        if success {
            print("Successfully toggled full screen.")
        } else {
            print("Failed to toggle full screen.")
        }
    }
    
    func simulateKeyStroke(virtualKey: CGKeyCode, flags: CGEventFlags = []) {
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else { return }
        
        // Key down event
        guard let keyDownEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: virtualKey, keyDown: true) else { return }
        keyDownEvent.flags = flags
        keyDownEvent.post(tap: .cghidEventTap)
        
        // Key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: virtualKey, keyDown: false) else { return }
        keyUpEvent.flags = flags
        keyUpEvent.post(tap: .cghidEventTap)
    }
    
    // Function to execute AppleScript
    func executeAppleScriptWithOSAScript(script: String) -> Bool {
        let startSystemEventsScript = """
            tell application "System Events" to set isRunning to (exists process "System Events")
            if not isRunning then
                tell application "System Events" to activate
                delay 1 -- Wait for System Events to start
            end if
            """
        
        // First, ensure System Events is running
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", startSystemEventsScript]
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Failed to start System Events: \(error)")
            return false
        }
        
        // Now execute the original script
        let scriptTask = Process()
        scriptTask.launchPath = "/usr/bin/osascript"
        scriptTask.arguments = ["-e", script]
        
        let outputPipe = Pipe()
        scriptTask.standardOutput = outputPipe
        scriptTask.standardError = outputPipe
        
        do {
            try scriptTask.run()
            scriptTask.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: outputData, encoding: .utf8) {
                print("OSAScript output: \(output)")
            }
            
            return scriptTask.terminationStatus == 0
        } catch {
            print("Failed to execute OSAScript: \(error)")
            return false
        }
    }
    // Function to autocomplete text
    func autocompleteText(prefix: String, option: String) {
        simulateTyping(unicodeString: prefix)
        usleep(100_000)
        let remainingText = String(option.dropFirst(prefix.count))
        simulateTyping(unicodeString: remainingText)
    }
    
    // Function to parse batch commands
    func parseBatchCommands(_ argument: String) -> [String] {
        return argument.split(separator: ";").map { String($0) }
    }
    
    // Function to get current mouse location
    func getCurrentMouseLocation() -> CGPoint? {
        return CGEvent(source: nil)?.location
    }
    
    func simulateEventsFromCSV(filePath: String) {
        guard let contents = try? String(contentsOfFile: filePath) else {
            print("Failed to read CSV file")
            return
        }
        let lines = contents.components(separatedBy: .newlines)
        for line in lines.dropFirst() { // Skip header
            let components = line.components(separatedBy: ",")
            if components.count >= 2 {
                let command = components[1]
                handleCommand(command)
                Thread.sleep(forTimeInterval: 0.1) // Small delay between commands
            }
        }
    }
}
