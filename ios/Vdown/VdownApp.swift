import SwiftUI

@main
struct VdownApp: App {
    @StateObject private var downloadManager = DownloadManager.shared

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(downloadManager)
        }
    }
}
