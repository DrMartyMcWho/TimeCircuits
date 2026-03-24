//
//  VideoScreenSaverView.swift
//  VideoScreen
//
//  Created by Tadhg on R 8/03/06.
//

import ScreenSaver
import AVFoundation
import AVKit

@objc(VideoScreenSaverView)
class VideoScreenSaverView: ScreenSaverView {
    
    private var configureSheetController: ConfigureSheetController?
    private var playerLayer: AVPlayerLayer?
    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var videoURL: URL?
    
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        setupVideo()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupVideo()
    }
    
    private func setupVideo() {
        
        queuePlayer?.pause()
        queuePlayer = nil
        looper = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        videoURL?.stopAccessingSecurityScopedResource()
        
        let defaults = ScreenSaverDefaults(forModuleWithName: "McWho.VideoScreen")
            ?? UserDefaults.standard
        
        let url: URL
        
        if let bookmarkData = defaults.data(forKey: "VideoBookmark") {
            var isStale = false
            do {
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                if resolvedURL.startAccessingSecurityScopedResource() {
                    videoURL = resolvedURL
                }
                url = resolvedURL
                NSLog("✅ Resolved bookmark to: %@", url.path)
                if isStale {
                    NSLog("⚠️ Bookmark stale — regenerating")

                    do {
                        let newBookmark = try resolvedURL.bookmarkData(
                            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        defaults.set(newBookmark, forKey: "VideoBookmark")
                        defaults.synchronize()
                    } catch {
                        NSLog("❌ Failed to regenerate bookmark: %@", error.localizedDescription)
                    }
                }
            } catch {
                NSLog("❌ Failed to resolve bookmark: %@", error.localizedDescription)
                return
            }
        } else if let savedPath = defaults.string(forKey: "VideoPath") {
            url = URL(fileURLWithPath: savedPath)
        } else {
            NSLog("⚠️ No video configured yet")
            return
        }

        // This is all the diagnostics you really need —
        // if the file isn't reachable, that's your answer
        let reachable = (try? url.checkResourceIsReachable()) ?? false
        NSLog("🎬 Video URL: %@", url.path)
        NSLog("🎬 File reachable: %@", reachable ? "YES" : "NO")

        let item = AVPlayerItem(url: url)

        queuePlayer = AVQueuePlayer()
        looper = AVPlayerLooper(player: queuePlayer!, templateItem: item)

        playerLayer = AVPlayerLayer(player: queuePlayer)
        playerLayer?.videoGravity = .resizeAspectFill

        
    }
    
    override func layout() {
        super.layout()
        // Keep the player layer filling the view if the frame ever changes
        playerLayer?.frame = bounds
    }
    
    override func startAnimation() {
        super.startAnimation()
        
        // Always full teardown first
        queuePlayer?.pause()
        queuePlayer = nil
        looper = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        videoURL?.stopAccessingSecurityScopedResource()
        videoURL = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        // Rebuild fresh
        setupVideo()
        
        guard let viewLayer = self.layer else { return }
        
        if let queuePlayer = queuePlayer {
            let pl = AVPlayerLayer(player: queuePlayer)
            pl.videoGravity = .resizeAspectFill
            pl.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
            pl.frame = bounds
            pl.backgroundColor = CGColor.clear
            viewLayer.addSublayer(pl)
            playerLayer = pl
        }
        
        queuePlayer?.play()
        NSLog("▶️ startAnimation — playing")
    }
    
    override func stopAnimation() {
        super.stopAnimation()
        queuePlayer?.pause()
        queuePlayer?.seek(to: .zero)
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        queuePlayer = nil
        looper = nil
        videoURL?.stopAccessingSecurityScopedResource()
        videoURL = nil  // CRITICAL — nil this out so setupVideo starts fresh
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NSLog("🛑 stopAnimation — security scope released")
    }
    
    override func draw(_ rect: NSRect) {}
    
    override func animateOneFrame() {}
    
    override var hasConfigureSheet: Bool {
        return true
    }
    
    override var configureSheet: NSWindow? {
        if configureSheetController == nil {
            let bundle = Bundle(for: type(of: self))
            let nibName = "ConfigureSheet"
            
            guard bundle.path(forResource: nibName, ofType: "nib") != nil else {
                print("❌ Could not find \(nibName).nib in bundle")
                return nil
            }
            
            configureSheetController = ConfigureSheetController()
            
            // Passing &topLevelObjects (rather than nil) is critical —
            // it keeps the nib's top-level objects like NSWindow alive in memory.
            // If you pass nil, ARC can deallocate the window before you use it,
            // which is why window was coming back nil before.
            var topLevelObjects: NSArray?
            bundle.loadNibNamed(
                nibName,
                owner: configureSheetController,
                topLevelObjects: &topLevelObjects
            )
            
            // Outlets are now connected, so it's safe to load the image
            configureSheetController?.loadImage()
            
            // If a video was already chosen in a prior session, show its name
            if let url = configureSheetController?.selectedVideoURL {
                configureSheetController?.videoPathLabel.stringValue = url.lastPathComponent
            }
        }
        
        guard let window = configureSheetController?.window else {
            print("❌ ConfigureSheetController window is nil after nib load")
            return nil
        }
        
        return window
    }
}
