//
//  ContentView.swift
//  macOS_agent_demo
//
//  Created by 殷瑜 on 2024/7/28.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject var viewModel = ScreencaptureViewModel()
    @State private var isSimulating = false
    @State private var selectedFilePath: String?

    var body: some View {
        VStack {
            Text("Desktop Agent")
                .font(.largeTitle)
                .padding()

            Text(viewModel.savedImagePath)
                .font(.caption)
                .padding()

            HStack {
                screenshotButton(type: .area, label: "Capture Area")
                screenshotButton(type: .window, label: "Capture Window")
                screenshotButton(type: .full, label: "Capture Full Screen")
            }
            
            HStack {
                Button(action: {
                    viewModel.startMonitoring()
                }) {
                    Text("启动监控")
                }
                .disabled(viewModel.isMonitoring)

                Button(action: {
                    viewModel.stopMonitoring()
                }) {
                    Text("停止监控")
                }
                .disabled(!viewModel.isMonitoring)

                Button(action: {
                    viewModel.exportToCSV()
                }) {
                    Text("导出CSV")
                }
                .disabled(viewModel.monitorEvents.isEmpty)
            }
            .padding()

            HStack {
                Button(action: {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.canCreateDirectories = false
                    panel.allowedContentTypes = [UTType.commaSeparatedText]
                    
                    if panel.runModal() == .OK {
                        selectedFilePath = panel.url?.path
                    }
                }) {
                    Text("选择CSV文件")
                }

                Button(action: {
                    guard let filePath = selectedFilePath else { return }
                    isSimulating = true
                    DispatchQueue.global(qos: .userInitiated).async {
                        EventSimulator.simulateEventsFromCSV(filePath: filePath)
                        DispatchQueue.main.async {
                            isSimulating = false
                        }
                    }
                }) {
                    Text("模拟事件")
                }
                .disabled(selectedFilePath == nil || isSimulating)
            }
            .padding()

            ScrollView {
                LazyVStack {
                    ForEach(viewModel.images.indices, id: \.self) { index in
                        Image(nsImage: viewModel.images[index])
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 400, maxHeight: 300)
                            .padding()
                            .onDrag {
                                let provider = NSItemProvider(object: viewModel.images[index])
                                return provider
                            }
                    }
                }
            }
        }
        .padding()
        .alert(item: Binding<AlertItem?>(
            get: { viewModel.errorMessage.map { AlertItem(message: $0) } },
            set: { _ in viewModel.errorMessage = nil }
        )) { alertItem in
            Alert(title: Text("错误"), message: Text(alertItem.message), dismissButton: .default(Text("确定")))
        }
    }
    
    private func screenshotButton(type: ScreencaptureViewModel.ScreenshotType, label: String) -> some View {
        Button(action: {
            viewModel.takeScreenshot(for: type)
        }) {
            Text(label)
        }
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    let message: String
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
