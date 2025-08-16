import SwiftUI

@main
struct PhotoServerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    _ = await BaseURLProvider.shared.refreshIfStale(force: true)
                }
        }
    }
}

struct ContentView: View {
    @State private var base: URL?

    var body: some View {
        VStack(spacing: 20) {
            Text("Current Base URL:")
            if let base {
                Text(base.absoluteString).bold()
            } else {
                ProgressView()
            }
        }
        .task {
            base = await BaseURLProvider.shared.url()
        }
        .padding()
    }
}
