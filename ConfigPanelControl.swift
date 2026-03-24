//
//  ConfigPanelControl.swift
//  TimeCircuits
//
// developed by DrMartyMcWho
// github.com/DrMartyMcWho
//


import Cocoa
import ScreenSaver

@objc(ConfigPanelController)
@MainActor
class ConfigPanelController: NSObject {

    @IBOutlet var window: NSWindow!
    @IBOutlet weak var destinationDatePicker: NSDatePicker!
    @IBOutlet weak var lastDepartedDatePicker: NSDatePicker!
    @IBOutlet weak var destinationCalendarButton: NSButton!
    @IBOutlet weak var lastDepartedCalendarButton: NSButton!

    private var activePopover: NSPopover?
    private var activePicker: NSDatePicker?

    var defaults: UserDefaults {
        return UserDefaults(suiteName: "com.apple.screensaver") ?? UserDefaults.standard
    }

    override init() {
        super.init()
    }
    
    @MainActor
    func loadDates() {
        destinationDatePicker.calendar = Calendar(identifier: .gregorian)
        destinationDatePicker.locale = Locale(identifier: "en_IE")
        lastDepartedDatePicker.calendar = Calendar(identifier: .gregorian)
        lastDepartedDatePicker.locale = Locale(identifier: "en_IE")
        if let destDate = defaults.object(forKey: "TC_DestinationDate") as? Date {
            destinationDatePicker.dateValue = destDate

        } else {
            // Default — Oct 26 1985 01:22
            var components = DateComponents()
            components.month = 10; components.day = 26; components.year = 1985
            components.hour = 1; components.minute = 22
            destinationDatePicker.dateValue = Calendar.current.date(from: components) ?? Date()
        }

        if let lastDate = defaults.object(forKey: "TC_LastDepartedDate") as? Date {
            lastDepartedDatePicker.dateValue = lastDate

        } else {
            // Default — Nov 05 1955 06:15
            var components = DateComponents()
            components.month = 11; components.day = 5; components.year = 1955
            components.hour = 6; components.minute = 15
            lastDepartedDatePicker.dateValue = Calendar.current.date(from: components) ?? Date()
        }
    }
    
    @IBAction func showCalendar(_ sender: NSButton) {
        // Dismiss any existing popover first
        activePopover?.close()
        activePopover = nil

        // Figure out which date picker this button belongs to
        let targetPicker = (sender == destinationCalendarButton)
            ? destinationDatePicker
            : lastDepartedDatePicker
        activePicker = targetPicker

        // Create the graphical date picker
        let graphicalPicker = NSDatePicker()
        graphicalPicker.datePickerStyle = .clockAndCalendar
        graphicalPicker.datePickerElements = [.yearMonthDay, .hourMinute]
        graphicalPicker.calendar = Calendar(identifier: .gregorian)
        graphicalPicker.locale = Locale(identifier: "en_IE")
        graphicalPicker.timeZone = TimeZone.current
        graphicalPicker.dateValue = targetPicker?.dateValue ?? Date()
        graphicalPicker.target = self
        graphicalPicker.action = #selector(calendarDateChanged(_:))
        graphicalPicker.frame = NSRect(x: 8, y: 8, width: 300, height: 175)

        // Wrap it in a view controller for the popover
        let vc = NSViewController()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 175))
        container.addSubview(graphicalPicker)
        vc.view = container

        // Create and show the popover
        let popover = NSPopover()
        popover.contentViewController = vc
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 300, height: 175)
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        activePopover = popover
    }

    @objc @MainActor func calendarDateChanged(_ sender: NSDatePicker) {
        activePicker?.dateValue = sender.dateValue
    }
    
    @IBAction @MainActor func allonsY(_ sender: Any) {
        defaults.set(destinationDatePicker.dateValue, forKey: "TC_DestinationDate")
        defaults.set(lastDepartedDatePicker.dateValue, forKey: "TC_LastDepartedDate")

        DistributedNotificationCenter.default().post(
            name: Notification.Name("com.apple.screensaver.didChange"),
            object: nil
        )

        guard let window, let parent = window.sheetParent else { return }
        parent.endSheet(window)
    }
}
