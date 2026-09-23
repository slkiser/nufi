import SwiftUI

/// Setup checklist. Stays until every grant is in place; the Done button
/// unlocks then. Statuses poll while the window is open because Accessibility
/// and Automation changes never bring the app back to the foreground.
struct OnboardingView: View {
    @StateObject private var monitor = SetupMonitor()
    private var status: SetupStatus { monitor.status }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 12)
                .padding(.bottom, 24)

            VStack(spacing: 10) {
                SetupRow(
                    done: status.extensionEnabled,
                    title: "Finder extension",
                    detail: "Adds New File and Paste as New File to the right-click menu of any Finder folder.",
                    button: status.extensionEnabled ? nil : "Open Extensions…",
                    action: SetupStatus.openExtensionSettings
                )
                SetupRow(
                    done: status.accessibility,
                    title: "Accessibility",
                    detail: "Lets Nufi press Enter in Finder so the new file is ready to rename.",
                    button: status.accessibility ? nil : "Allow…",
                    action: monitor.requestAccessibility
                )
                SetupRow(
                    done: status.automationGranted,
                    title: "Automation",
                    detail: automationDetail,
                    button: status.automationGranted ? nil
                        : (monitor.automationRequestInFlight ? "Waiting…" : automationButton),
                    action: monitor.requestAutomation
                )
            }
            .padding(.horizontal, 24)

            footer
                .padding(.top, 24)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
        .frame(width: 460)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in monitor.refresh() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 100, height: 100)
            Text("Welcome to Nufi")
                .font(.system(size: 24, weight: .bold))
            Text("Paste copied text as a new file, right from Finder.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "doc.badge.plus")
                    .foregroundStyle(.secondary)
                Text("Nufi lives in your menu bar. Use it there for the Desktop, where Finder has no extension menu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: {
                Windows.shared.closeOnboarding()
                Windows.shared.showSettings()
            }) {
                Text(status.isComplete ? "Done" : "Finish the steps above")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!status.isComplete)
        }
    }

    private var automationDetail: String {
        if status.finderAutomation == .denied || status.systemEventsAutomation == .denied {
            return "Turn on Finder and System Events for Nufi in System Settings."
        }
        return "Lets Nufi select the new file in Finder. Approve both prompts: Finder and System Events."
    }

    private var automationButton: String {
        (status.finderAutomation == .denied || status.systemEventsAutomation == .denied)
            ? "Open Automation…" : "Allow…"
    }
}

private struct SetupRow: View {
    let done: Bool
    let title: String
    let detail: String
    let button: String?
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(done ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(done ? .secondary : .primary)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if let button {
                Button(button, action: action)
                    .controlSize(.regular)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(done ? "done" : "not done")")
    }
}
