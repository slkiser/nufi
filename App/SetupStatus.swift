import AppKit
import ApplicationServices
import FinderSync


/// The three grants Nufi needs. The extension toggle is global; the
/// Accessibility and Automation grants are for the Nufi app process, which
/// runs the menu bar item. The extension asks for its own on first use.
struct SetupStatus: Equatable {
    enum Automation: Equatable {
        case granted, denied, notAsked, unknown
    }

    var extensionEnabled: Bool
    var accessibility: Bool
    var finderAutomation: Automation
    var systemEventsAutomation: Automation

    var automationGranted: Bool {
        finderAutomation == .granted && systemEventsAutomation == .granted
    }

    var isComplete: Bool {
        extensionEnabled && accessibility && automationGranted
    }

    static func current() -> SetupStatus {
        SetupStatus(
            extensionEnabled: FIFinderSyncController.isExtensionEnabled,
            accessibility: AXIsProcessTrusted(),
            finderAutomation: automation(for: "com.apple.finder"),
            systemEventsAutomation: automation(for: "com.apple.systemevents")
        )
    }

    /// kAEDoNotPromptForUserConsent: the send fails with -1744 instead of
    /// showing the consent dialog. AEDeterminePermissionToAppleEventsForApp
    /// is missing from this macOS build, so the probe is a real event.
    private static let doNotPrompt = NSAppleEventDescriptor.SendOptions(rawValue: 0x0002_0000)

    /// Reads the Automation grant without prompting. Any reply, including
    /// "event not handled", means the consent check passed.
    private static func automation(for bundleID: String) -> Automation {
        let result: Automation
        switch probe(bundleID, options: [.waitForReply, doNotPrompt]) {
        case 0, -1708: result = .granted
        case -1743: result = .denied
        case -1744: result = .notAsked
        default: result = .unknown  // -600: target app not running
        }
        return remember(result, for: bundleID)
    }

    /// System Events quits itself when idle, and a probe then only says "not
    /// running". Keep the last real answer so a granted step stays granted.
    private static func remember(_ result: Automation, for bundleID: String) -> Automation {
        let key = "automation.\(bundleID)"
        let defaults = UserDefaults.standard
        switch result {
        case .granted: defaults.set("granted", forKey: key)
        case .denied: defaults.set("denied", forKey: key)
        case .notAsked: defaults.removeObject(forKey: key)
        case .unknown:
            switch defaults.string(forKey: key) {
            case "granted": return .granted
            case "denied": return .denied
            default: return .unknown
            }
        }
        return result
    }

    /// Sends a harmless get-data event; the target answers "not handled" once
    /// consent exists. Returns the error code, 0 on success.
    @discardableResult
    private nonisolated static func probe(_ bundleID: String,
                                          options: NSAppleEventDescriptor.SendOptions) -> Int {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEGetData),
            targetDescriptor: target, returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID))
        do {
            let reply = try event.sendEvent(options: options, timeout: 5)
            return Int(reply.paramDescriptor(forKeyword: keyErrorNumber)?.int32Value ?? 0)
        } catch {
            return (error as NSError).code
        }
    }

    // MARK: Actions

    static func openExtensionSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    /// Asks macOS to show the Automation prompt for each target. Blocks until
    /// the user answers, so call it off the main thread. System Events is
    /// launched first: the check reports "not running" otherwise.
    nonisolated static func requestAutomation() {
        for bundleID in ["com.apple.finder", "com.apple.systemevents"] {
            if bundleID == "com.apple.systemevents" {
                launchSystemEvents()
            }
            probe(bundleID, options: [.waitForReply])
        }
    }

    private nonisolated static func launchSystemEvents() {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systemevents")
        guard running.isEmpty,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systemevents")
        else { return }
        let semaphore = DispatchSemaphore(value: 0)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in semaphore.signal() }
        _ = semaphore.wait(timeout: .now() + 3)
    }

    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func openAutomationSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
    }

    private static func open(_ raw: String) {
        if let url = URL(string: raw) { NSWorkspace.shared.open(url) }
    }
}
