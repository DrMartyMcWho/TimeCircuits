//
//  ConfigureSheetController.swift
//  VideoScreen
//
//  Created by Tadhg on R 8/03/06.
//

import Cocoa
import ScreenSaver

@objc(ConfigureSheetController)
class ConfigureSheetController: NSObject {
    
    @IBOutlet var window: NSWindow!
    @IBOutlet weak var videoPathLabel: NSTextField!
    @IBOutlet weak var logoImageView: NSImageView!
    
    var selectedVideoURL: URL?
    
    override init() {
        super.init()
        // Load any previously saved video path so it's ready when the sheet opens
        if let savedPath = defaults.string(forKey: "VideoPath") {
            selectedVideoURL = URL(fileURLWithPath: savedPath)
        }
    }
    
    // Called AFTER the nib has loaded and outlets are connected —
    // this is the safe moment to touch logoImageView
    func loadImage() {
        // 1️⃣ Try the asset catalog first (recommended)
        if let img = NSImage(named: "greatscott") {
            logoImageView.image = img
            NSLog("✅ Image loaded from asset catalog")
            return
        }

        // 2️⃣ Fallback – raw file in the bundle (e.g. if you move the png out of the catalog)
        let bundle = Bundle(for: type(of: self))
        if let img = bundle.image(forResource: "greatscott") {
            logoImageView.image = img
            NSLog("✅ Image loaded from bundle resources")
            return
        }

        // 3️⃣ Nothing found – give a clear diagnostic
        NSLog("❌ greatscott not found – bundle path: %@", bundle.bundlePath)
    }
//
//        // Fallback: look for a raw PNG in the bundle resources
//        let bundle = Bundle(for: type(of: self))
//        if let img = bundle.image(forResource: "greatscott") {
//            logoImageView.image = img
//            NSLog("✅ Image loaded from bundle resources")
//        } else {
//            NSLog("❌ greatscott not found – bundle path: %@", bundle.bundlePath)
//        }
//    }
    
    var defaults: UserDefaults {
        return ScreenSaverDefaults(forModuleWithName: "McWho.VideoScreen")
            ?? UserDefaults.standard
    }
    
    @IBAction func choosVideo(_ sender: Any) {
        selectedVideoURL?.stopAccessingSecurityScopedResource()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            selectedVideoURL = url
            videoPathLabel.stringValue = url.lastPathComponent
            
            // ✅ Clear old values FIRST before saving new ones
            defaults.removeObject(forKey: "VideoPath")
            defaults.removeObject(forKey: "VideoBookmark")
            defaults.synchronize()
            
            // Save plain path
            defaults.set(url.path, forKey: "VideoPath")
            
            // Save fresh bookmark
            do {
                let bookmarkData = try url.bookmarkData(
                    options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                defaults.set(bookmarkData, forKey: "VideoBookmark")
                DistributedNotificationCenter.default().post(
                    name: Notification.Name("com.apple.screensaver.didChange"),
                    object: nil
                )
                NSLog("✅ Bookmark saved for: %@", url.path)
            } catch {
                NSLog("❌ Failed to create bookmark: %@", error.localizedDescription)
            }
            
            defaults.synchronize()

            // Notify the screensaver engine that settings changed
            DistributedNotificationCenter.default().post(
                name: Notification.Name("com.apple.screensaver.didChange"),
                object: nil
            )
        }
    }
    
    @IBAction func closeSheet(_ sender: Any) {
        guard let window = window,
              let parent = window.sheetParent else { return }
        parent.endSheet(window)
    }
}
