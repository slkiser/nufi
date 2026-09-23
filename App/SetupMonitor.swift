import AppKit
import Combine

/// Live view of the setup grants. Polls while any observer is alive, because
/// Accessibility and Automation changes never bring Nufi to the foreground.
@MainActor
final class SetupMonitor: ObservableObject {
    @Published private(set) var status = SetupStatus.current()
    @Published private(set) var automationRequestInFlight = false

    private var timer: Timer?
    private var observers: [Any] = []

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
    }

    deinit {
        timer?.invalidate()
    }

    func refresh() {
        let latest = SetupStatus.current()
        if latest != status { status = latest }
    }

    func requestAccessibility() {
        AccessibilityGuide.shared.present()
    }

    /// The system prompts block until answered, so they run off the main
    /// thread. Denied earlier: there is no prompt to show, open the pane.
    func requestAutomation() {
        if status.finderAutomation == .denied || status.systemEventsAutomation == .denied {
            SetupStatus.openAutomationSettings()
            return
        }
        guard !automationRequestInFlight else { return }
        automationRequestInFlight = true
        Task.detached {
            SetupStatus.requestAutomation()
            await MainActor.run {
                self.automationRequestInFlight = false
                self.refresh()
            }
        }
    }
}
