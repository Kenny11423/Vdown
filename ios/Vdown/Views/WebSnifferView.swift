import SwiftUI
import WebKit

struct WebSnifferView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @State private var urlInput: String = "https://google.com"
    @State private var webView = WKWebView()
    @State private var detectedStreams: [String] = []
    @State private var showDetectedSheet: Bool = false
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var isLoading: Bool = false
    @State private var pageTitle: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Address Bar & Controls
                HStack(spacing: 8) {
                    Button(action: { webView.goBack() }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!canGoBack)

                    Button(action: { webView.goForward() }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!canGoForward)

                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        TextField("Enter URL or search", text: $urlInput, onCommit: loadURL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                            .font(.subheadline)

                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.7)
                        } else {
                            Button(action: { webView.reload() }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)

                // Sniffer WebView
                ZStack(alignment: .bottom) {
                    SnifferWebView(
                        webView: $webView,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward,
                        isLoading: $isLoading,
                        pageTitle: $pageTitle,
                        onMediaDetected: { streamUrl in
                            if !detectedStreams.contains(streamUrl) {
                                detectedStreams.append(streamUrl)
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                            }
                        }
                    )

                    // Detected media floating banner
                    if !detectedStreams.isEmpty {
                        VStack {
                            Button(action: { showDetectedSheet = true }) {
                                HStack {
                                    Image(systemName: "film.fill")
                                    Text("\(detectedStreams.count) Media Stream\(detectedStreams.count > 1 ? "s" : "") Found")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("Download")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.white)
                                        .foregroundColor(.blue)
                                        .cornerRadius(8)
                                }
                                .padding(12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .shadow(radius: 8)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 12)
                        }
                    }
                }
            }
            .navigationTitle(pageTitle.isEmpty ? "Browser" : pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDetectedSheet) {
                detectedStreamsList
            }
            .onAppear {
                if !downloadManager.snifferURL.isEmpty {
                    urlInput = downloadManager.snifferURL
                    downloadManager.snifferURL = ""
                    loadURL()
                } else if webView.url == nil {
                    loadURL()
                }
            }
            .onChange(of: downloadManager.snifferURL) { newUrl in
                if !newUrl.isEmpty {
                    urlInput = newUrl
                    downloadManager.snifferURL = ""
                    loadURL()
                }
            }
        }
    }

    private var detectedStreamsList: some View {
        NavigationView {
            List {
                Section(header: Text("Captured Video & Audio Streams")) {
                    ForEach(detectedStreams, id: \.self) { stream in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(stream)
                                .font(.caption)
                                .lineLimit(2)
                                .foregroundColor(.primary)

                            HStack {
                                Button(action: {
                                    if let url = URL(string: stream) {
                                        downloadManager.startDownload(url: url, quality: .best, isAudio: false)
                                        showDetectedSheet = false
                                    }
                                }) {
                                    Text("Download Stream")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                }

                                Spacer()

                                Button(action: {
                                    UIPasteboard.general.string = stream
                                }) {
                                    Text("Copy URL")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Detected Media")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        showDetectedSheet = false
                    }
                }
            }
        }
    }

    private func loadURL() {
        var clean = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.lowercased().hasPrefix("http://") && !clean.lowercased().hasPrefix("https://") {
            if clean.contains(".") && !clean.contains(" ") {
                clean = "https://" + clean
            } else {
                let query = clean.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clean
                clean = "https://www.google.com/search?q=\(query)"
            }
        }
        if let targetURL = URL(string: clean) {
            webView.load(URLRequest(url: targetURL))
        }
    }
}

struct SnifferWebView: UIViewRepresentable {
    @Binding var webView: WKWebView
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    @Binding var pageTitle: String
    var onMediaDetected: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let contentController = WKUserContentController()

        // JavaScript to detect video elements and network requests
        let js = """
        function detectVideos() {
            var mediaElements = document.querySelectorAll('video, audio, source');
            mediaElements.forEach(function(el) {
                var src = el.src || el.currentSrc;
                if (src && (src.includes('.mp4') || src.includes('.m3u8') || src.includes('.webm') || src.startsWith('blob:') || src.startsWith('http'))) {
                    window.webkit.messageHandlers.mediaDetector.postMessage(src);
                }
            });
        }
        setInterval(detectVideos, 2000);
        detectVideos();
        """

        let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(script)
        contentController.add(context.coordinator, name: "mediaDetector")
        configuration.userContentController = contentController

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        DispatchQueue.main.async {
            self.webView = view
        }
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: SnifferWebView

        init(_ parent: SnifferWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "mediaDetector", let streamUrl = message.body as? String {
                if !streamUrl.isEmpty && !streamUrl.hasPrefix("blob:") {
                    parent.onMediaDetected(streamUrl)
                }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
            parent.pageTitle = webView.title ?? ""
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
        }
    }
}
