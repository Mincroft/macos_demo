//
//  macOS_agent_demoApp.swift
//  macOS_agent_demo
//
//  Created by 殷瑜 on 2024/7/28.
//

import SwiftUI

@main
struct Desktop_agent_demoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = ScreencaptureViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityPermission()
    }
    
    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            print("请在系统偏好设置中授予应用程序辅助功能权限以启用全部功能。")
        }
    }
}
