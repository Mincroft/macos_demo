//
//  WindowMonitor.swift
//  macOS_agent_demo
//
//  Created by 殷瑜 on 2024/7/28.
//

import SwiftUI

struct MonitorWindow: View {
    @ObservedObject var viewModel: ScreencaptureViewModel
    
    var body: some View {
        VStack {
            Text("事件监控")
                .font(.headline)
                .padding()
            
            Text("鼠标坐标: \(viewModel.mousePosition)")
                .font(.subheadline)
                .padding(.bottom)
            
            List {
                ForEach(viewModel.monitorEvents, id: \.self) { event in
                    Text(event)
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}

struct MonitorWindow_Previews: PreviewProvider {
    static var previews: some View {
        MonitorWindow(viewModel: ScreencaptureViewModel())
    }
}

