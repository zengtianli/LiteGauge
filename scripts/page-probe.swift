// Offscreen live-page check: page-probe <url> <out.png> <width> <mobile:0|1> <play:0|1>
// Hosted in a borderless window at -20000,-20000 that ignores the mouse; activation policy .prohibited, so it never takes focus.
import AppKit
import WebKit
let a = CommandLine.arguments
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let width = CGFloat(Double(a[3])!), mobile = a[4] == "1", play = a[5] == "1"
let cfg = WKWebViewConfiguration()
cfg.mediaTypesRequiringUserActionForPlayback = []
let view = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: 900), configuration: cfg)
if mobile { view.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1" }
let metricsJS = """
(() => { const imgs=[...document.images]; const v=document.querySelector('video');
return JSON.stringify({title:document.title, innerWidth:innerWidth, scrollWidth:document.documentElement.scrollWidth,
 scrollHeight:document.documentElement.scrollHeight, images:imgs.length,
 broken:imgs.filter(i=>!(i.complete&&i.naturalWidth>0)).map(i=>i.currentSrc||i.src),
 overflowing:[...document.querySelectorAll('body *')].filter(e=>e.getBoundingClientRect().right>innerWidth+1).length,
 video: v ? {src:v.currentSrc, tracks:v.textTracks.length, poster:v.poster} : null,
 h1:(document.querySelector('h1')||{}).innerText, downloads:[...document.querySelectorAll('a')].filter(x=>/\\.(zip|dmg)$/.test(x.href)).map(x=>x.href)}) })()
"""
final class D: NSObject, WKNavigationDelegate {
  func webView(_ w: WKWebView, didFinish _: WKNavigation!) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      w.evaluateJavaScript(metricsJS) { r, e in
        print("METRICS", r ?? "nil", e.map { "\($0)" } ?? "")
        if play { self.startPlay(w) } else { self.snap(w) }
      }
    }
  }
  func startPlay(_ w: WKWebView) {
    w.evaluateJavaScript("(()=>{const v=document.querySelector('video'); v.muted=true; window.__ev=[]; ['playing','ended','error','stalled'].forEach(n=>v.addEventListener(n,()=>__ev.push(n+'@'+v.currentTime.toFixed(2)))); const t=v.textTracks[0]; if(t){t.mode='showing'}; v.currentTime=0; v.play().then(()=>__ev.push('play-ok')).catch(e=>__ev.push('play-err:'+e)); return 'started'})()") { r, e in print("PLAY", r ?? "nil", e ?? "") }
    var polls = 0
    func poll() {
      w.evaluateJavaScript("(()=>{const v=document.querySelector('video'); return JSON.stringify({currentTime:v.currentTime,duration:v.duration,readyState:v.readyState,ended:v.ended,paused:v.paused,error:v.error&&v.error.code,videoWidth:v.videoWidth,events:__ev,cues:(v.textTracks[0]&&v.textTracks[0].cues)?v.textTracks[0].cues.length:null,activeCue:(v.textTracks[0]&&v.textTracks[0].activeCues&&v.textTracks[0].activeCues[0])?v.textTracks[0].activeCues[0].text:null})})()") { r, _ in
        let s = r as? String ?? ""; polls += 1
        if polls % 5 == 0 || s.contains("\"ended\":true") { print("POLL", s) }
        if s.contains("\"ended\":true") || polls > 60 { exit(s.contains("\"ended\":true") ? 0 : 3) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { poll() }
      }
    }
    poll()
  }
  func snap(_ w: WKWebView) {
    w.evaluateJavaScript("document.documentElement.scrollHeight") { h, _ in
      w.frame = NSRect(x: 0, y: 0, width: w.frame.width, height: min(CGFloat((h as? Double) ?? 900), 16000))
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        let c = WKSnapshotConfiguration(); c.rect = w.bounds
        w.takeSnapshot(with: c) { img, err in
          guard let img, let t = img.tiffRepresentation, let r = NSBitmapImageRep(data: t), let p = r.representation(using: .png, properties: [:]) else { print(err ?? "fail"); exit(1) }
          try! p.write(to: URL(fileURLWithPath: a[2])); exit(0) }
      }
    }
  }
  func webView(_ w: WKWebView, didFail _: WKNavigation!, withError e: Error) { print(e); exit(1) }
  func webView(_ w: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError e: Error) { print(e); exit(1) }
}
let d = D(); view.navigationDelegate = d
let win = NSWindow(contentRect: NSRect(x: -20000, y: -20000, width: width, height: 900), styleMask: [.borderless], backing: .buffered, defer: false)
win.contentView = view
win.ignoresMouseEvents = true
win.orderBack(nil)
view.load(URLRequest(url: URL(string: a[1])!))
DispatchQueue.main.asyncAfter(deadline: .now() + 90) { print("timeout"); exit(2) }
app.run()
