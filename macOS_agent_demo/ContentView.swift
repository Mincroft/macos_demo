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
    @StateObject var recordModel = RecordModel()
    @State private var simulator = Simulator()
    @State private var selectedFilePath: String?
    @State private var showingPromptDialog = false
    @State private var customPrompt = "Start of session: Download the following Github repository: Mobile Agent, Cradle Github, RustDesk Github"
    @State private var commandInput = ""

    var body: some View {
        VStack {
            Text("Desktop Agent")
                .font(.largeTitle)
                .padding()

            Button(action: {
                showingPromptDialog = true
            }) {
                Text(viewModel.isRunning ? "Stop Agent" : "Start Agent")
            }
            .padding(.bottom)

            if let sessionID = viewModel.sessionID {
                Text("Session ID: \(sessionID)")
                    .font(.caption)
                    .padding(.bottom)
            }

            VStack(alignment: .leading) {
                Text("Received Instructions:")
                    .font(.headline)

                ScrollView {
                    LazyVStack(alignment: .leading) {
                        ForEach(viewModel.receivedInstructions, id: \.self) { instruction in
                            Text(instruction)
                                .padding(.vertical, 2)
                        }
                    }
                }
                .frame(height: 150)
                .border(Color.gray, width: 1)
            }
            .padding()

            HStack {
                TextField("Enter command", text: $commandInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Button("Simulate") {
                    simulator.handleCommand(commandInput)
                    commandInput = ""  // Clear the input after simulation
                }
                .padding(.trailing)
            }
            .padding(.bottom)
            
            HStack {
                Button(recordModel.isRecording ? "停止录屏" : "开始录屏") {
                    if recordModel.isRecording {
                        recordModel.stopRecording { url in
                            if let url = url {
                                print("Recording saved to: \(url.path)")
                            }
                        }
                    } else {
                        recordModel.startRecording()
                    }
                }
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
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text(viewModel.alertTitle),
                message: Text(viewModel.alertMessage),
                dismissButton: .default(Text("确定"))
            )
        }
        .sheet(isPresented: $showingPromptDialog) {
            PromptDialog(prompt: $customPrompt, isPresented: $showingPromptDialog, onStart: {
                viewModel.startAgent(with: customPrompt)
            })
        }
    }
}

struct PromptDialog: View {
    @Binding var prompt: String
    @Binding var isPresented: Bool
    var onStart: () -> Void

    var body: some View {
        VStack {
            Text("Enter Custom Prompt")
                .font(.headline)
                .padding()

            TextEditor(text: $prompt)
                .frame(height: 100)
                .border(Color.gray, width: 1)
                .padding()

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .padding()

                Button("Start Agent") {
                    onStart()
                    isPresented = false
                }
                .padding()
            }
        }
        .frame(width: 400)
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
