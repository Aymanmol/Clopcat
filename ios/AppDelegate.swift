// ios/Runner/AppDelegate.swift  (use @UIApplicationMain instead of @main on older Flutter templates)
import UIKit
import Flutter
import AVFoundation

@main @objc class AppDelegate: FlutterAppDelegate {
  override func application(_ app: UIApplication,
      didFinishLaunchingWithOptions o: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let messenger = self.registrar(forPlugin: "CutlineExport")!.messenger()
    FlutterMethodChannel(name: "cutline/export", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "export", let a = call.arguments as? [String: Any],
              let out = a["out"] as? String, let clips = a["clips"] as? [[String: Any]]
        else { return result(FlutterMethodNotImplemented) }
        Exporter.run(clips, texts: (a["texts"] as? [[String: Any]]) ?? [], out: out, result: result)
      }
    return super.application(app, didFinishLaunchingWithOptions: o)
  }
}

enum Exporter {
  static func oriented(_ t: AVAssetTrack) -> CGRect {
    CGRect(origin: .zero, size: t.naturalSize).applying(t.preferredTransform)
  }
  /// Rotate, then scale-to-fit and center inside the render size.
  static func fit(_ t: AVAssetTrack, _ r: CGSize) -> CGAffineTransform {
    let b = oriented(t), s = min(r.width / abs(b.width), r.height / abs(b.height))
    return t.preferredTransform
      .concatenating(CGAffineTransform(translationX: -b.minX, y: -b.minY))
      .concatenating(CGAffineTransform(scaleX: s, y: s))
      .concatenating(CGAffineTransform(translationX: (r.width - abs(b.width) * s) / 2,
                                       y: (r.height - abs(b.height) * s) / 2))
  }
  /// Text layer timed with an opacity animation. Core Animation here uses a bottom-left origin, so y is flipped.
  static func textLayer(_ t: [String: Any], _ size: CGSize) -> CATextLayer {
    let sz = CGFloat(t["size"] as! Double) * size.height
    let l = CATextLayer()
    l.string = t["text"] as! String
    l.font = CTFontCreateUIFontForLanguage(.emphasizedSystem, sz, nil)
    l.fontSize = sz
    let c = UInt32(truncatingIfNeeded: t["color"] as! Int)
    l.foregroundColor = UIColor(red: CGFloat((c >> 16) & 255) / 255, green: CGFloat((c >> 8) & 255) / 255,
                                blue: CGFloat(c & 255) / 255, alpha: CGFloat((c >> 24) & 255) / 255).cgColor
    l.alignmentMode = .center
    l.contentsScale = 1
    l.bounds = CGRect(x: 0, y: 0, width: size.width, height: sz * 1.4)
    l.position = CGPoint(x: (t["x"] as! Double) * size.width, y: (1 - (t["y"] as! Double)) * size.height)
    l.shadowColor = UIColor.black.cgColor
    l.shadowOpacity = 1
    l.shadowRadius = sz * 0.06
    l.shadowOffset = CGSize(width: 0, height: -sz * 0.03)
    l.opacity = 0
    let s = Double(t["start"] as! Int) / 1000, e = Double(t["end"] as! Int) / 1000
    let a = CABasicAnimation(keyPath: "opacity")
    a.fromValue = 1; a.toValue = 1
    a.beginTime = AVCoreAnimationBeginTimeAtZero + s
    a.duration = max(e - s, 0.05)
    a.fillMode = .removed
    a.isRemovedOnCompletion = false
    l.add(a, forKey: "show")
    return l
  }
  static func fail(_ r: FlutterResult, _ m: String?) { r(FlutterError(code: "EXPORT", message: m, details: nil)) }

  static func run(_ clips: [[String: Any]], texts: [[String: Any]], out: String, result: @escaping FlutterResult) {
    let comp = AVMutableComposition()
    guard let vt = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    else { return fail(result, "Could not create video track") }
    let at = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
    let assets = clips.map { AVURLAsset(url: URL(fileURLWithPath: $0["path"] as! String)) }
    guard let first = assets.first?.tracks(withMediaType: .video).first
    else { return fail(result, "No video track in first clip") }
    let b = oriented(first)
    let size = abs(b.height) > abs(b.width) ? CGSize(width: 720, height: 1280) : CGSize(width: 1280, height: 720)
    var cursor = CMTime.zero
    var instrs: [AVMutableVideoCompositionInstruction] = []
    for (i, c) in clips.enumerated() {
      let asset = assets[i]
      guard let src = asset.tracks(withMediaType: .video).first else { continue }
      let s = c["start"] as! Int, e = c["end"] as! Int, speed = c["speed"] as! Double
      let dur = CMTime(value: CMTimeValue(e - s), timescale: 1000)
      let range = CMTimeRange(start: CMTime(value: CMTimeValue(s), timescale: 1000), duration: dur)
      do {
        try vt.insertTimeRange(range, of: src, at: cursor)
        if !(c["mute"] as! Bool), let sa = asset.tracks(withMediaType: .audio).first {
          try at?.insertTimeRange(range, of: sa, at: cursor)
        }
      } catch { return fail(result, error.localizedDescription) }
      let outDur = CMTimeMultiplyByFloat64(dur, multiplier: 1 / speed)
      if speed != 1 {
        let r = CMTimeRange(start: cursor, duration: dur)
        vt.scaleTimeRange(r, toDuration: outDur)
        at?.scaleTimeRange(r, toDuration: outDur)
      }
      let ins = AVMutableVideoCompositionInstruction()
      ins.timeRange = CMTimeRange(start: cursor, duration: outDur)
      let li = AVMutableVideoCompositionLayerInstruction(assetTrack: vt)
      li.setTransform(fit(src, size), at: cursor)
      ins.layerInstructions = [li]
      instrs.append(ins)
      cursor = CMTimeAdd(cursor, outDur)
    }
    let vc = AVMutableVideoComposition()
    vc.instructions = instrs; vc.renderSize = size; vc.frameDuration = CMTime(value: 1, timescale: 30)
    if !texts.isEmpty {
      let parent = CALayer(), video = CALayer()
      parent.frame = CGRect(origin: .zero, size: size)
      video.frame = parent.frame
      parent.addSublayer(video)
      for t in texts { parent.addSublayer(textLayer(t, size)) }
      vc.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: video, in: parent)
    }
    guard let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)
    else { return fail(result, "Could not create export session") }
    try? FileManager.default.removeItem(atPath: out)
    ex.videoComposition = vc; ex.outputURL = URL(fileURLWithPath: out); ex.outputFileType = .mp4
    ex.exportAsynchronously {
      DispatchQueue.main.async {
        if ex.status == .completed { result(out) } else { fail(result, ex.error?.localizedDescription) }
      }
    }
  }
}
