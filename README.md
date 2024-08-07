# macOS Agent Demo

This project is a macOS application that demonstrates various functionalities including screen capture, event monitoring, and event simulation. The application is built using SwiftUI and leverages several macOS-specific APIs.

## File Structure and Code Logic

### 1. macOS_agent_demoApp.swift

This file serves as the entry point for the application and sets up the main app structure.

#### `Desktop_agent_demoApp` struct
- Conforms to the `App` protocol, indicating it's the main app structure.
- Uses `@NSApplicationDelegateAdaptor` to integrate an AppDelegate.
- Creates and manages a `ScreencaptureViewModel` as a `@StateObject`.

#### Key Components:
- `body`: Defines the main scene of the application, setting up the `ContentView` and injecting the `ViewModel` into the environment.

#### `AppDelegate` class
- Conforms to `NSApplicationDelegate` protocol.
- Handles application lifecycle events.

#### Key Functions:
- `applicationDidFinishLaunching(_:)`: Called when the application finishes launching, triggers the accessibility permission request.
- `requestAccessibilityPermission()`: Requests accessibility permissions required for the app's functionality.

### 2. ContentView.swift

This file contains the main user interface of the application.

#### `ContentView` struct
- Represents the main view of the application.
- Uses `@StateObject` to manage the `ScreencaptureViewModel`.
- Contains UI elements for capturing screenshots, monitoring events, and simulating events.

#### UI Components:
- Buttons for different types of screen captures (area, window, full screen).
- Buttons to start/stop monitoring and export CSV.
- A file picker and button for event simulation.
- A scrollable view to display captured images.

#### Key Functions:
- `screenshotButton(type:label:)`: Creates a button for taking screenshots.
- `body`: Defines the entire UI structure of the application.

### 3. Eventmonitor.swift

This file defines the `EventMonitor` class for monitoring system-wide events.

#### `EventMonitor` class
- Responsible for setting up and managing a global event monitor.
- Uses `NSEvent.addGlobalMonitorForEvents` to capture system events.

#### Key Functions:
- `init(mask:handler:)`: Initializes the event monitor with specified event types and a handler.
- `start()`: Starts the event monitoring.
- `stop()`: Stops the event monitoring and cleans up resources.

### 4. Eventsimulator.swift

This file contains the `EventSimulator` class for simulating various system events.

#### `EventSimulator` class
- Provides static methods to simulate keyboard, mouse, and scroll wheel events.
- Reads event data from a CSV file and simulates these events.

#### Key Functions:
- `simulateEventsFromCSV(filePath:)`: Reads a CSV file and simulates events based on its content.
- `simulateModifierChange(action:modifiers:)`: Simulates modifier key events.
- `simulateKeyboardEvent(action:keyName:)`: Simulates keyboard events.
- `simulateMouseEvent(action:button:x:y:)`: Simulates mouse button events.
- `simulateMouseMove(x:y:)`: Simulates mouse movement.
- `simulateScrollWheel(deltaY:)`: Simulates scroll wheel events.
- Various helper functions for key code conversions and event type determinations.

### 5. ScreenCaptureViewModel.swift

This file defines the `ScreencaptureViewModel` class, which manages the core functionality of the application.

#### `ScreencaptureViewModel` class
- Manages screen capture, event monitoring, and data processing.
- Conforms to `ObservableObject` for SwiftUI integration.

#### Key Properties:
- `images`: Stores captured images.
- `events` and `monitorEvents`: Store captured events.
- `isMonitoring`: Indicates if event monitoring is active.

#### Key Functions:
- `takeScreenshot(for:)`: Captures screenshots based on the specified type.
- `setupEventTap()`: Sets up the event tap for monitoring.
- `handleEvent(type:event:)`: Processes captured events.
- `startMonitoring()` and `stopMonitoring()`: Control event monitoring.
- `exportToCSV()`: Exports captured events to a CSV file.
- Various helper functions for processing different types of events.

### 6. WindowMonitor.swift

This file defines the `MonitorWindow` struct, which provides a UI for displaying monitored events.

#### `MonitorWindow` struct
- Defines the UI for the event monitoring window.
- Displays real-time mouse coordinates and a list of captured events.

#### Key Components:
- `body`: Defines the structure of the monitoring window UI.
- Uses a `List` to display captured events.
- Shows current mouse coordinates.

## Overall Architecture

1. `macOS_agent_demoApp.swift` serves as the entry point, setting up the app structure and handling initial setup like requesting permissions.
2. The `ContentView` serves as the main UI, interacting with the `ScreencaptureViewModel`.
3. `ScreencaptureViewModel` manages the core functionality, including screen capture and event monitoring.
4. `EventMonitor` is used by `ScreencaptureViewModel` to set up system-wide event monitoring.
5. `EventSimulator` provides functionality to simulate events, which can be triggered from the main UI.
6. `MonitorWindow` provides a separate window for displaying monitored events in real-time.

This architecture separates concerns effectively, with the ViewModel (`ScreencaptureViewModel`) acting as the central point of control, coordinating between the UI (`ContentView` and `MonitorWindow`) and the lower-level event handling and simulation components (`EventMonitor` and `EventSimulator`). The app delegate in `macOS_agent_demoApp.swift` ensures that necessary permissions are requested at the appropriate time in the app's lifecycle.
