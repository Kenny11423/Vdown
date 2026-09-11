import SwiftUI

struct MainView: View {
    @ObservedObject var downloadManager = DownloadManager.shared

    var body: some View {
        TabView(selection: $downloadManager.selectedTab) {
            HomeDownloadView()
                .tabItem {
                    Label("Downloader", systemImage: "arrow.down.circle.fill")
                }
                .tag(0)

            WebSnifferView()
                .tabItem {
                    Label("Browser", systemImage: "safari.fill")
                }
                .tag(1)

            DownloadsListView()
                .tabItem {
                    Label("Files", systemImage: "folder.fill")
                }
                .badge(downloadManager.localFiles.count > 0 ? "\(downloadManager.localFiles.count)" : nil)
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
    }
}
