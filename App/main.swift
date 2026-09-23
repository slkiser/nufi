import AppKit

/// Nufi is a menu bar app. There is no Dock icon and no main menu; the
/// onboarding window appears until setup is complete, and Settings opens
/// from the menu bar item or by launching the app again.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
