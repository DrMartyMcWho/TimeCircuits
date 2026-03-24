//
//  TimeCircuitsView.swift
//  TimeCircuits
//
// developed by DrMartyMcWho
// github.com/DrMartyMcWho
//

import ScreenSaver

@objc(TimeCircuitsView)
class TimeCircuitsView: ScreenSaverView {

    // MARK: - Types

    struct TimeCircuitRow {
        var month: String
        var day: String
        var year: String
        var hour: String
        var minute: String
        var isPM: Bool
        var color: NSColor
        var dimColor: NSColor
        var bgColor: NSColor
        var headerColor: NSColor
        var label: String
    }

    // MARK: - Properties

    private var configPanelController: ConfigPanelController?
    private var fontLoaded = false
    private var colonVisible = true
    private var backgroundTexture: NSImage?
    nonisolated(unsafe) private var settingsObserver: NSObjectProtocol?

    private var destinationTime = TimeCircuitRow(
        month: "OCT", day: "26", year: "1985",
        hour: "01", minute: "22", isPM: false,
        color: NSColor(red: 1.0,  green: 0.45, blue: 0.0,  alpha: 1.0),
        dimColor: NSColor(red: 0.20, green: 0.07, blue: 0.0,  alpha: 1.0),
        bgColor: NSColor(red: 0.05, green: 0.01, blue: 0.01, alpha: 1.0),
        headerColor: NSColor(red: 0.50, green: 0.05, blue: 0.05, alpha: 1.0),
        label: "DESTINATION TIME"
    )

    private var presentTime = TimeCircuitRow(
        month: "", day: "", year: "",
        hour: "", minute: "", isPM: false,
        color: NSColor(red: 0.18, green: 1.0,  blue: 0.18, alpha: 1.0),
        dimColor: NSColor(red: 0.02, green: 0.16, blue: 0.02, alpha: 1.0),
        bgColor: NSColor(red: 0.01, green: 0.07, blue: 0.01, alpha: 1.0),
        headerColor: NSColor(red: 0.05, green: 0.28, blue: 0.05, alpha: 1.0),
        label: "PRESENT TIME"
    )

    private var lastTimeDeparted = TimeCircuitRow(
        month: "NOV", day: "05", year: "1955",
        hour: "06", minute: "15", isPM: false,
        color: NSColor(red: 1.0,  green: 0.78, blue: 0.0,  alpha: 1.0),
        dimColor: NSColor(red: 0.22, green: 0.16, blue: 0.0,  alpha: 1.0),
        bgColor: NSColor(red: 0.07, green: 0.05, blue: 0.0,  alpha: 1.0),
        headerColor: NSColor(red: 0.32, green: 0.22, blue: 0.0,  alpha: 1.0),
        label: "LAST TIME DEPARTED"
    )

    // MARK: - Init

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0
        loadFonts()
        addSettingsObserver()
        loadSavedDates()
        updatePresentTime()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        animationTimeInterval = 1.0
        loadFonts()
        addSettingsObserver()
        loadSavedDates()
        updatePresentTime()
    }

    deinit {
        if let observer = settingsObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    // MARK: - Settings Observer

    private func addSettingsObserver() {
        settingsObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screensaver.didChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.loadSavedDates()
                self.updatePresentTime()
                self.setNeedsDisplay(self.bounds)
            }
        }
    }

    // MARK: - Font Loading

    private func loadFonts() {
        guard !fontLoaded else { return }
        let bundle = Bundle(for: type(of: self))
        for name in ["DSEG14Classic-BoldItalic", "DSEG7Classic-Italic", "Microgramma-Normal"] {
            if let url = bundle.url(forResource: name, withExtension: "ttf") {
                var error: Unmanaged<CFError>?
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            }
        }
        fontLoaded = true
    }

    private func dseg14(size: CGFloat) -> NSFont {
        return NSFont(name: "DSEG14Classic-BoldItalic", size: size)
            ?? NSFont.monospacedDigitSystemFont(ofSize: size, weight: .bold)
    }

    // MARK: - Japanese Era Year Formatting

    /// Formats a year for display, respecting the system calendar.
    /// On Japanese imperial calendar: R007, H035, S059 etc.
    /// On Gregorian: 1985, 2026 etc.
    private func formatYear(from date: Date) -> String {
        let japaneseCal = Calendar(identifier: .japanese)
        let systemCal = Calendar.current

        if systemCal.identifier == .japanese {
            let era = japaneseCal.component(.era, from: date)
            let year = japaneseCal.component(.year, from: date)

            let eraLetter: String
            switch era {
            case 236: eraLetter = "R"  // Reiwa   (2019–)
            case 235: eraLetter = "H"  // Heisei  (1989–2019)
            case 234: eraLetter = "S"  // Showa   (1926–1989)
            case 233: eraLetter = "T"  // Taisho  (1912–1926)
            case 232: eraLetter = "M"  // Meiji   (1868–1912)
            default:  eraLetter = "?"
            }
            return String(format: "%@%03d", eraLetter, year)
        } else {
            let year = Calendar(identifier: .gregorian).component(.year, from: date)
            return String(format: "%04d", year)
        }
    }

    // MARK: - Date Loading

    private func loadSavedDates() {
        let defaults = UserDefaults(suiteName: "com.apple.screensaver") ?? UserDefaults.standard
        let cal = Calendar(identifier: .gregorian)
        let months = ["JAN","FEB","MAR","APR","MAY","JUN",
                      "JUL","AUG","SEP","OCT","NOV","DEC"]

        if let destDate = defaults.object(forKey: "TC_DestinationDate") as? Date {
            let month = cal.component(.month, from: destDate)
            var hour  = cal.component(.hour,  from: destDate)
            let isPM  = hour >= 12
            if hour > 12 { hour -= 12 }
            if hour == 0 { hour = 12 }
            destinationTime.month  = months[month - 1]
            destinationTime.day    = String(format: "%02d", cal.component(.day,    from: destDate))
            destinationTime.year   = formatYear(from: destDate)
            destinationTime.hour   = String(format: "%02d", hour)
            destinationTime.minute = String(format: "%02d", cal.component(.minute, from: destDate))
            destinationTime.isPM   = isPM
        }

        if let lastDate = defaults.object(forKey: "TC_LastDepartedDate") as? Date {
            let month = cal.component(.month, from: lastDate)
            var hour  = cal.component(.hour,  from: lastDate)
            let isPM  = hour >= 12
            if hour > 12 { hour -= 12 }
            if hour == 0 { hour = 12 }
            lastTimeDeparted.month  = months[month - 1]
            lastTimeDeparted.day    = String(format: "%02d", cal.component(.day,    from: lastDate))
            lastTimeDeparted.year   = formatYear(from: lastDate)
            lastTimeDeparted.hour   = String(format: "%02d", hour)
            lastTimeDeparted.minute = String(format: "%02d", cal.component(.minute, from: lastDate))
            lastTimeDeparted.isPM   = isPM
        }
    }

    // MARK: - Present Time

    private func updatePresentTime() {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let months = ["JAN","FEB","MAR","APR","MAY","JUN",
                      "JUL","AUG","SEP","OCT","NOV","DEC"]
        let month  = cal.component(.month,  from: now)
        let day    = cal.component(.day,    from: now)
        var hour   = cal.component(.hour,   from: now)
        let minute = cal.component(.minute, from: now)
        let isPM   = hour >= 12
        if hour > 12 { hour -= 12 }
        if hour == 0 { hour = 12 }

        presentTime.month  = months[month - 1]
        presentTime.day    = String(format: "%02d", day)
        presentTime.year   = formatYear(from: now)
        presentTime.hour   = String(format: "%02d", hour)
        presentTime.minute = String(format: "%02d", minute)
        presentTime.isPM   = isPM
    }

    // MARK: - Animation

    override func startAnimation() {
        super.startAnimation()
        generateBackgroundTexture()
        loadSavedDates()
        updatePresentTime()
    }

    override func stopAnimation() {
        super.stopAnimation()
    }

    override func animateOneFrame() {
        updatePresentTime()
        colonVisible = !colonVisible
        setNeedsDisplay(bounds)
    }
    
    

    // MARK: - Drawing

    override func draw(_ rect: NSRect) {
        // Full background — dark mottled grey
        if backgroundTexture == nil {
            generateBackgroundTexture()
        }
        backgroundTexture?.draw(in: bounds)

        // Calculate the display area — cap width for ultrawide screens
        let maxAspect: CGFloat = 2.35  // ~21:9 cap
        let displayWidth = min(bounds.width, bounds.height * maxAspect)
        let displayX = (bounds.width - displayWidth) / 2

        // The three rows + labels take up 80% of the height
        // Each row ratio: roughly 3:1 width:height based on movie prop
        let totalContentHeight = bounds.height * 0.88
        let labelBarH = totalContentHeight * 0.04   // thin bar below each row
        let gapH      = totalContentHeight * 0.025   // gap between rows
        let rowH      = (totalContentHeight - labelBarH * 3 - gapH * 2) / 3
        let hPad      = displayWidth * 0.025
        let rowW      = displayWidth - hPad * 2

        // Start Y — centred vertically
        let totalH = rowH * 3 + labelBarH * 3 + gapH * 2
        let startY = (bounds.height - totalH) / 2

        // Row Y positions (bottom up — AppKit coords)
        let row3Y = startY
        let row2Y = row3Y + rowH + labelBarH + gapH
        let row1Y = row2Y + rowH + labelBarH + gapH

        let row1Rect = NSRect(x: displayX + hPad, y: row1Y + labelBarH, width: rowW, height: rowH)
        let row2Rect = NSRect(x: displayX + hPad, y: row2Y + labelBarH, width: rowW, height: rowH)
        let row3Rect = NSRect(x: displayX + hPad, y: row3Y + labelBarH, width: rowW, height: rowH)

        let label1Rect = NSRect(x: displayX + hPad, y: row1Y, width: rowW, height: labelBarH)
        let label2Rect = NSRect(x: displayX + hPad, y: row2Y, width: rowW, height: labelBarH)
        let label3Rect = NSRect(x: displayX + hPad, y: row3Y, width: rowW, height: labelBarH)

        drawRowPanel(destinationTime,  rowRect: row1Rect, labelRect: label1Rect)
        drawRowPanel(presentTime,      rowRect: row2Rect, labelRect: label2Rect)
        drawRowPanel(lastTimeDeparted, rowRect: row3Rect, labelRect: label3Rect)
    }
    
    // MARK: - Colon
    
    private func drawColon(color: NSColor, digitY: CGFloat, digitH: CGFloat, in rect: NSRect) {
        let dimColor = NSColor(white: 0.15, alpha: 1.0)
        let dotR = rect.width * 0.35  // smaller dots, closer together
        let x = rect.midX - dotR / 2
        let activeColor = colonVisible ? color : dimColor

        // Centre vertically within the digit box
        let digitMidY = digitY + digitH / 2
        let spacing = dotR * 1.4  // tighter spacing between dots

        activeColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: x, y: digitMidY + spacing * 0.2,
                                    width: dotR, height: dotR)).fill()
        NSBezierPath(ovalIn: NSRect(x: x, y: digitMidY - spacing * 1.2,
                                    width: dotR, height: dotR)).fill()
    }

    // MARK: - Speckled Texture
    
    private func generateBackgroundTexture() {
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        
        NSColor(white: 0.36, alpha: 1.0).setFill()
        NSRect(origin: .zero, size: bounds.size).fill()
        drawSpeckledTexture(in: NSRect(origin: .zero, size: bounds.size))
        
        image.unlockFocus()
        backgroundTexture = image
    }

    private func drawSpeckledTexture(in rect: NSRect) {
        // Base colour — dark grey
        NSColor(white: 0.38, alpha: 1.0).setFill()
        rect.fill()

        // Large irregular patches — lighter and darker blobs
        for _ in 0..<Int(rect.width * rect.height / 400) {
            let x = CGFloat.random(in: rect.minX..<rect.maxX)
            let y = CGFloat.random(in: rect.minY..<rect.maxY)
            let w = CGFloat.random(in: 4...20)
            let h = CGFloat.random(in: 4...20)
            let brightness = CGFloat.random(in: 0.28...0.52)
            let alpha = CGFloat.random(in: 0.15...0.45)
            NSColor(white: brightness, alpha: alpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: w, height: h)).fill()
        }

        // Fine speckle layer on top
        for _ in 0..<Int(rect.width * rect.height / 60) {
            let x = CGFloat.random(in: rect.minX..<rect.maxX)
            let y = CGFloat.random(in: rect.minY..<rect.maxY)
            let size = CGFloat.random(in: 0.5...2.5)
            let brightness = CGFloat.random(in: 0.25...0.55)
            NSColor(white: brightness, alpha: CGFloat.random(in: 0.2...0.5)).setFill()
            NSRect(x: x, y: y, width: size, height: size).fill()
        }
    }

    
    
    // MARK: - Row Panel

    private func drawRowPanel(_ row: TimeCircuitRow, rowRect: NSRect, labelRect: NSRect) {
        // Outer panel — recessed bevel (dark outer edge, lighter inner)
        let bevel: CGFloat = rowRect.height * 0.04

        // Dark outer frame — gives recessed look
        NSColor(white: 0.18, alpha: 1.0).setFill()
        NSBezierPath(roundedRect: rowRect, xRadius: 4, yRadius: 4).fill()

        // Slightly lighter inner frame
        NSColor(white: 0.35, alpha: 1.0).setFill()
        NSBezierPath(roundedRect: rowRect.insetBy(dx: bevel * 0.5, dy: bevel * 0.5),
                     xRadius: 3, yRadius: 3).fill()

        // Inner panel — speckled dark grey metal
        let innerRect = rowRect.insetBy(dx: bevel, dy: bevel)
        NSColor(white: 0.30, alpha: 1.0).setFill()
        NSBezierPath(roundedRect: innerRect, xRadius: 2, yRadius: 2).fill()


        // Label — black background only as wide as the text, centred at bottom of inner panel
        let labelFontSize = innerRect.height * 0.12
        let labelFont = NSFont(name: "MicrogrammaNormal", size: labelFontSize)
            ?? NSFont.boldSystemFont(ofSize: labelFontSize)
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: NSColor.white,
            .kern: innerRect.width * 0.003
        ]
        let labelStr = row.label as NSString
        let labelSize = labelStr.size(withAttributes: labelAttrs)
        let labelPadH: CGFloat = labelSize.height * 0.4
        let labelPadV: CGFloat = labelSize.height * 0.10
        let labelBgRect = NSRect(
            x: innerRect.midX - labelSize.width / 2 - labelPadH,
            y: innerRect.minY + labelPadV,
            width: labelSize.width + labelPadH * 2,
            height: labelSize.height + labelPadV * 2
        )
        NSColor.black.setFill()
        labelBgRect.fill()
        labelStr.draw(at: NSPoint(
            x: labelBgRect.minX + labelPadH,
            y: labelBgRect.minY + labelPadV
        ), withAttributes: labelAttrs)

        // Content area — excludes the label area at the bottom
        let labelAreaH = innerRect.height * 0.14
        let contentRect = NSRect(
            x: innerRect.minX,
            y: innerRect.minY + labelAreaH,
            width: innerRect.width,
            height: innerRect.height - labelAreaH
        )
        drawRowContent(row, in: contentRect)
    }

    // MARK: - Row Content

    private func drawRowContent(_ row: TimeCircuitRow, in rect: NSRect) {
        let yearCharCount = 4
        let totalUnits: CGFloat = 14.3
        let unitW = rect.width / totalUnits
        let cellGap: CGFloat = rect.width * 0.025

        let headerH = rect.height * 0.18
        let digitH  = rect.height * 0.68
        let digitY  = rect.minY + rect.height * 0.02

        let totalUsedWidth = unitW * totalUnits
        let leftOffset = (rect.width - totalUsedWidth) / 2
        var x = rect.minX + leftOffset

        // MONTH
        drawCell(label: "MONTH", value: row.month, row: row,
                 in: NSRect(x: x, y: rect.minY, width: unitW * 3.1 - cellGap, height: rect.height),
                 headerH: headerH, digitH: digitH, digitY: digitY, charCount: 3)
        x += unitW * 3.0

        // DAY
        drawCell(label: "DAY", value: row.day, row: row,
                 in: NSRect(x: x, y: rect.minY, width: unitW * 2.2 - cellGap, height: rect.height),
                 headerH: headerH, digitH: digitH, digitY: digitY, charCount: 2)
        x += unitW * 2.0

        // YEAR
        drawCell(label: "YEAR", value: row.year, row: row,
                 in: NSRect(x: x, y: rect.minY, width: unitW * 4.0 - cellGap, height: rect.height),
                 headerH: headerH, digitH: digitH, digitY: digitY, charCount: yearCharCount)
        x += unitW * 4.0

        // AM/PM
        drawAMPM(isPM: row.isPM, color: row.color,
                 in: NSRect(x: x, y: rect.minY, width: unitW * 1.2, height: rect.height))
        x += unitW * 1.2

        // HOUR
        drawCell(label: "HOUR", value: row.hour, row: row,
                 in: NSRect(x: x, y: rect.minY, width: unitW * 2.2 - cellGap, height: rect.height),
                 headerH: headerH, digitH: digitH, digitY: digitY, charCount: 2)
        x += unitW * 2.0

        // COLON
        drawColon(color: row.color,
                  digitY: digitY, digitH: digitH,
                  in: NSRect(x: x - unitW * 0.1, y: rect.minY, width: unitW * 0.4, height: rect.height))
        x += unitW * 0.3

        // MIN
        drawCell(label: "MIN", value: row.minute, row: row,
                 in: NSRect(x: x, y: rect.minY, width: unitW * 1.8, height: rect.height),
                 headerH: headerH, digitH: digitH, digitY: digitY, charCount: 2)
    }

    // MARK: - Cell Drawing

    private func drawCell(label: String, value: String, row: TimeCircuitRow,
                          in rect: NSRect, headerH: CGFloat, digitH: CGFloat,
                          digitY: CGFloat, charCount: Int) {

        // Header bar — sits at top, narrow, dark red
        let headerFontsize = headerH * 1
        let headerFont = NSFont(name: "MicrogrammaNormal", size: headerFontsize)
        ?? NSFont.boldSystemFont(ofSize: headerFontsize)
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: NSColor.white
        ]
        let hStr = label as NSString
        let hSize = hStr.size(withAttributes: headerAttrs)
        let hPadH: CGFloat = hSize.height * 0.4
        let hPadV: CGFloat = hSize.height * 0.15
        let headerBgRect = NSRect(
            x: rect.midX - hSize.width / 2 - hPadH,
            y: rect.maxY - hSize.height * 1.2 - hPadV * 2,  // sits at very top with no overlap
            width: hSize.width + hPadH * 2,
            height: hSize.height + hPadV * 2
        )
        NSColor(red: 0.50, green: 0.05, blue: 0.05, alpha: 1.0).setFill()
        headerBgRect.fill()
        hStr.draw(at: NSPoint(
            x: headerBgRect.minX + hPadH,
            y: headerBgRect.minY + hPadV
        ), withAttributes: headerAttrs)

        // Gap between header and digit box is implicit —
        // digit box sits lower with space above it
        // Digit box — separate recessed dark window
        let digitBoxY = digitY - 2
        let digitBoxH = digitH + 4

        // Outer bevel of digit box
        NSColor(white: 0.08, alpha: 1.0).setFill()
        NSRect(x: rect.minX, y: digitBoxY - 1,
               width: rect.width, height: digitBoxH + 2).fill()

        // Inner digit background
        let digitRect = NSRect(x: rect.minX + 1, y: digitBoxY,
                               width: rect.width - 2, height: digitBoxH)
        row.bgColor.setFill()
        digitRect.fill()

        let fontSize = digitH * 0.82
        let font = dseg14(size: fontSize)

        // Ghost digits
        let ghostStr = String(repeating: "8", count: charCount)
        let dimAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: row.dimColor
        ]
        let ghostNS = ghostStr as NSString
        let ghostSize = ghostNS.size(withAttributes: dimAttrs)
        ghostNS.draw(at: NSPoint(
            x: digitRect.midX - ghostSize.width / 2,
            y: digitRect.midY - ghostSize.height / 2
        ), withAttributes: dimAttrs)

        // Lit digits
        guard !value.isEmpty else { return }
        let litAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: row.color
        ]
        let litStr = value as NSString
        let litSize = litStr.size(withAttributes: litAttrs)
        litStr.draw(at: NSPoint(
            x: digitRect.midX - litSize.width / 2,
            y: digitRect.midY - litSize.height / 2
        ), withAttributes: litAttrs)
    }

    // MARK: - AM/PM

    private func drawAMPM(isPM: Bool, color: NSColor, in rect: NSRect) {
        let dotR  = rect.width * 0.10
        let cx    = rect.midX - dotR

        let amY   = rect.midY + dotR * 0.5
        let pmY   = rect.midY - dotR * 7.5

        let amColor = isPM ? NSColor(white: 0.18, alpha: 1) : color
        let pmColor = isPM ? color : NSColor(white: 0.18, alpha: 1)

        let fontSize = rect.width * 0.28
        let font = NSFont(name: "MicrogrammaNormal", size: fontSize)
            ?? NSFont.boldSystemFont(ofSize: fontSize)
        let amAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let pmAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]

        let amSize = ("AM" as NSString).size(withAttributes: amAttrs)
        let pmSize = ("PM" as NSString).size(withAttributes: pmAttrs)

        // AM red label background
        let amLabelRect = NSRect(
            x: rect.midX - amSize.width / 2 - 2,
            y: amY + dotR * 2 + 2,
            width: amSize.width + 4,
            height: amSize.height
        )
        NSColor(red: 0.50, green: 0.05, blue: 0.05, alpha: 1.0).setFill()
        amLabelRect.fill()
        ("AM" as NSString).draw(at: NSPoint(
            x: amLabelRect.minX + 2,
            y: amLabelRect.minY
        ), withAttributes: amAttrs)

        // AM dot
        amColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: cx, y: amY,
                                    width: dotR * 2, height: dotR * 2)).fill()

        // PM red label background
        let pmLabelRect = NSRect(
            x: rect.midX - pmSize.width / 2 - 2,
            y: pmY + dotR * 2 + 2,
            width: pmSize.width + 4,
            height: pmSize.height
        )
        NSColor(red: 0.50, green: 0.05, blue: 0.05, alpha: 1.0).setFill()
        pmLabelRect.fill()
        ("PM" as NSString).draw(at: NSPoint(
            x: pmLabelRect.minX + 2,
            y: pmLabelRect.minY
        ), withAttributes: pmAttrs)

        // PM dot
        pmColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: cx, y: pmY,
                                    width: dotR * 2, height: dotR * 2)).fill()
    }





    // MARK: - Configuration Sheet

    override var hasConfigureSheet: Bool { return true }

    override var configureSheet: NSWindow? {
        let controller = ConfigPanelController()
        let bundle = Bundle(for: type(of: self))
        let nibName = "ConfigPanel"

        guard bundle.path(forResource: nibName, ofType: "nib") != nil else {
            NSLog("❌ Could not find \(nibName).nib in bundle")
            return nil
        }

        var topLevelObjects: NSArray?
        bundle.loadNibNamed(nibName, owner: controller, topLevelObjects: &topLevelObjects)
        controller.loadDates()

        guard let window = controller.window else {
            NSLog("❌ ConfigPanelController window is nil after nib load")
            return nil
        }

        configPanelController = controller
        return window
    }
}
