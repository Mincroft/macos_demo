//
//  macOS_agent_demoApp.swift
//  macOS_agent_demo
//
//  Created by 殷瑜 on 2024/7/28.
//

import SwiftUI
import os.log

@main
struct Desktop_agent_demoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = ScreencaptureViewModel()
    @StateObject private var recordModel = RecordModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(recordModel)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
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

    func windowWillClose(_ notification: Notification) {
        // 处理窗口关闭事件
        print("Window is about to close")
    }
}
