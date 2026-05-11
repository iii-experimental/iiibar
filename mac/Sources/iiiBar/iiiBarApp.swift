import SwiftUI

@main
struct iiiBarApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(state)
                .task {
                    await state.refreshAll()
                }
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(statusColor(state.status?.state ?? "unknown"))
                    .frame(width: 8, height: 8)
                Text("iiiBar")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
        }
        .menuBarExtraStyle(.window)
    }
}
