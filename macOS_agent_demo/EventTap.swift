//
//  EventTap.swift
//  macOS_agent_demo
//
//  Created by 殷瑜 on 2024/8/29.
//

import Foundation
import CoreGraphics
import Quartz
import Carbon
import Combine

class EventTapManager: ObservableObject {
    var eventTap: CFMachPort?
    
    // Store the mouse start and end positions
    @Published var mouseStartPosition: CGPoint?
    @Published var mouseEndPosition: CGPoint?
    
    // Variables to track the state of modifier keys
    var shiftKeyDown = false
    var controlKeyDown = false
    var optionKeyDown = false
    var commandKeyDown = false
    var capslockKeyDown = false
    var helpKeyDown = false
    var fnKeyDown = false
    
    // Mapping of event types to their names
    let eventTypeNames: [CGEventType: String] = EventMasks.eventTypeNames
    // Mapping of key codes to their corresponding string representations
    let reversedKeyCodeMapping: [Int64: String] = EventMasks.reversedKeyCodeMapping
    
    init() {
        // Define the events of interest
        let eventOfInterest = EventMasks.allEventsMask
        
        // Create an event tap to listen for events
        let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventOfInterest),
            callback: EventTapManager.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        if let eventTap = eventTap {
            // Add the event tap to the run loop
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            self.eventTap = eventTap
        } else {
            print("Failed to create event tap")
        }
    }
    
    deinit {
        // Invalidate the event tap when the object is deallocated
        if let eventTap = eventTap {
            CFMachPortInvalidate(eventTap)
        }
    }
    
    // Callback function for handling events
    private static let eventTapCallback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
        let manager = Unmanaged<EventTapManager>.fromOpaque(refcon!).takeUnretainedValue()
        
        // Print the event type name if available
        if let eventName = manager.eventTypeNames[type] {
            // Uncomment to print event names
            print("Event type: \(eventName)")
        } else {
            print("Event type: \(type.rawValue)")
        }
        
        // Get the key code and flags from the event
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        // Handle key down events for key codes less than or equal to 50
        if type == .keyDown && keyCode <= 50 {
            let maxStringLength = 4
            var actualStringLength = 0
            var unicodeString = [UniChar](repeating: 0, count: maxStringLength)
            
            event.keyboardGetUnicodeString(maxStringLength: maxStringLength, actualStringLength: &actualStringLength, unicodeString: &unicodeString)
            let characters = String(utf16CodeUnits: unicodeString, count: actualStringLength)
            
            // Print the key-down event with specific key names
            switch characters {
            case "\u{9}":
                print("key-down: tab")
            case "\u{D}":
                print("key-down: return")
            case "\u{20}":
                print("key-down: space")
            default:
                print("key-down: \(characters)")
            }
        }
        
        // Handle key up events for key codes less than or equal to 50
        if type == .keyUp && keyCode <= 50 {
            let maxStringLength = 4
            var actualStringLength = 0
            var unicodeString = [UniChar](repeating: 0, count: maxStringLength)
            
            event.keyboardGetUnicodeString(maxStringLength: maxStringLength, actualStringLength: &actualStringLength, unicodeString: &unicodeString)
            let characters = String(utf16CodeUnits: unicodeString, count: actualStringLength)
            
            // Print the key-up event with specific key names
            switch characters {
            case "\u{9}":
                print("key-up: tab")
            case "\u{D}":
                print("key-up: return")
            case "\u{20}":
                print("key-up: space")
            default:
                print("key-up: \(characters)")
            }
        }
        
        // Handle key up events for key codes greater than 50
        if type == .keyUp && keyCode > 50 {
            if let characters = manager.reversedKeyCodeMapping[keyCode] {
                print("key-up: \(characters)")
            } else {
                print("key-up: invalid keyCode")
            }
        }

        // Handle key down events for key codes greater than 50
        if type == .keyDown && keyCode > 50 {
            if let characters = manager.reversedKeyCodeMapping[keyCode] {
                print("key-down: \(characters)")
            } else {
                print("key-down: invalid keyCode")
            }
        }
        
        // Handle flag change events to detect modifier keys
        if type == .flagsChanged {
            let shiftDown = flags.contains(.maskShift)
            let controlDown = flags.contains(.maskControl)
            let optionDown = flags.contains(.maskAlternate)
            let commandDown = flags.contains(.maskCommand)
            let capslockDown = flags.contains(.maskAlphaShift)
            let helpDown = flags.contains(.maskHelp)
            let fnDown = flags.contains(.maskSecondaryFn)
            
            // Check the state change for each modifier key and print accordingly
            if shiftDown != manager.shiftKeyDown {
                manager.shiftKeyDown = shiftDown
                print("key-\(shiftDown ? "down" : "up"): shift")
            }
            if controlDown != manager.controlKeyDown {
                manager.controlKeyDown = controlDown
                print("key-\(controlDown ? "down" : "up"): ctrl")
            }
            if optionDown != manager.optionKeyDown {
                manager.optionKeyDown = optionDown
                print("key-\(optionDown ? "down" : "up"): option")
            }
            if commandDown != manager.commandKeyDown {
                manager.commandKeyDown = commandDown
                print("key-\(commandDown ? "down" : "up"): command")
            }
            if capslockDown != manager.capslockKeyDown {
                manager.capslockKeyDown = capslockDown
                print("key-\(capslockDown ? "down" : "up"): caps lock")
            }
            if helpDown != manager.helpKeyDown {
                manager.helpKeyDown = helpDown
                print("key-\(helpDown ? "down" : "up"): help")
            }
            if fnDown != manager.fnKeyDown {
                manager.fnKeyDown = fnDown
                print("key-\(fnDown ? "down" : "up"): fn")
            }
        }

        // Print mouse codes
        if type == .leftMouseDown || type == .rightMouseDown {
            let mouseCode = event.getIntegerValueField(.mouseEventClickState)
            print("Mouse state: \(mouseCode)")
        }
        
        // Monitor mouse position changes
        if type == .mouseMoved {
            let mouseLocation = event.location
            
            if manager.mouseStartPosition == nil {
                manager.mouseStartPosition = mouseLocation
            } else {
                manager.mouseEndPosition = mouseLocation
                // Print mouse start and end positions
                print("Mouse moved from: \(manager.mouseStartPosition!) to \(manager.mouseEndPosition!)")
                // Update start position to current end position
                manager.mouseStartPosition = mouseLocation
            }
        }
        
        // Return the event (pass through the event)
        return Unmanaged.passUnretained(event)
    }
}
