import SwiftUI
import AVKit
import WebKit

struct PlayerView: View {
    @EnvironmentObject private var playback: Playback
    var body: some View {
        Group {
            if let media = playback.current {
                switch media.kind {
                case .stream: NativePlayerView(playback: playback)
                case .youtube(let id): YouTubeView(videoID: id, playback: playback).id(media.id)
                }
            } else {
                ZStack {
                    Color.black
                    VStack(spacing: 16) {
                        Image(systemName: "play.rectangle").font(.system(size: 36, weight: .ultraLight))
                        Text("A little space for the big screen.").font(.callout)
                    }.foregroundStyle(.white.opacity(0.55)).padding()
                }
            }
        }
        .background(.black)
    }
}

struct YouTubeView: UIViewRepresentable {
    let videoID: String
    @ObservedObject var playback: Playback
    func makeCoordinator() -> Coordinator { Coordinator(playback) }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(context.coordinator, name: "event")
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.isOpaque = false; web.backgroundColor = .black; web.scrollView.isScrollEnabled = false
        playback.webView = web
        // An HTTPS base supplies the origin/referrer required by the official iframe API.
        web.loadHTMLString("""
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="referrer" content="strict-origin-when-cross-origin"><style>html,body,#player{margin:0;width:100%;height:100%;background:#000;overflow:hidden}</style></head><body><div id="player"></div><script>
        var player;var ready=false;function emit(e){window.webkit.messageHandlers.event.postMessage(e)}
        function onYouTubeIframeAPIReady(){player=new YT.Player('player',{host:'https://www.youtube-nocookie.com',videoId:'\(videoID)',playerVars:{playsinline:1,autoplay:1,rel:0,origin:'https://www.youtube-nocookie.com'},events:{onReady:function(){ready=true;emit({ready:true});player.setVolume(\(Int(playback.volume * 100)));player.setPlaybackRate(\(playback.speed));player.playVideo()},onStateChange:function(e){emit({state:e.data})},onError:function(e){emit({error:e.data})}})}
        setInterval(function(){if(player&&player.getCurrentTime){emit({time:player.getCurrentTime(),duration:player.getDuration()})}},1000);
        setTimeout(function(){if(!ready){emit({message:'YouTube is taking too long to connect. Check internet access, or try opening the original video.'})}},20000);
        </script><script src="https://www.youtube.com/iframe_api" onerror="emit({message:'The YouTube player could not load. Check your internet connection.'})"></script></body></html>
        """, baseURL: URL(string: "https://www.youtube-nocookie.com"))
        return web
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "event")
        uiView.stopLoading(); uiView.navigationDelegate = nil
        if coordinator.playback.webView === uiView { coordinator.playback.webView = nil }
    }
    @MainActor final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let playback: Playback
        let mediaID: UUID?
        init(_ playback: Playback) { self.playback = playback; self.mediaID = playback.current?.id }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if playback.current?.id == mediaID, let data = message.body as? [String: Any] { playback.webEvent(data) }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { playback.error = "YouTube could not connect. Check your internet connection and try again." }
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url else { decisionHandler(.allow); return }
            decisionHandler(.cancel)
            if url.scheme == "https" { UIApplication.shared.open(url) }
        }
    }
}
