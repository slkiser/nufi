import AppKit
import ApplicationServices
import SwiftUI

/// Opens the Accessibility pane and floats a small guide under it with a
/// draggable Nufi row, then watches until the grant lands or the pane goes
/// away. Adapted from Trace's permission guide.
@MainActor
final class AccessibilityGuide {
    static let shared = AccessibilityGuide()

    private var panel: NSPanel?
    private var monitor: Task<Void, Never>?

    private static let panelHeight: CGFloat = 122
    private static let settingsBundleIDs = ["com.apple.SystemSettings", "com.apple.systempreferences"]

    func present() {
        dismiss()
        if AXIsProcessTrusted() { return }

        // The prompt registers Nufi in the list so a single toggle finishes
        // the job; the pane and guide cover the case where the prompt is gone.
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        SetupStatus.openAccessibilitySettings()

        monitor = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            self?.showPanel()
            var missingSettings = 0
            var sawSettings = false
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard let self, !Task.isCancelled else { return }
                if AXIsProcessTrusted() {
                    self.dismiss()
                    return
                }
                let frame = self.settingsWindowFrame()
                if frame != nil { sawSettings = true; missingSettings = 0 } else { missingSettings += 1 }
                if missingSettings >= (sawSettings ? 3 : 8) {
                    self.dismiss()
                    return
                }
                self.reposition(relativeTo: frame)
            }
        }
    }

    func dismiss() {
        monitor?.cancel()
        monitor = nil
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }

    private func showPanel() {
        let settingsFrame = settingsWindowFrame()
        guard let screen = screen(for: settingsFrame) ?? NSScreen.main else { return }
        let panel = NSPanel(
            contentRect: Self.frame(settingsFrame: settingsFrame, visibleFrame: screen.visibleFrame),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: GuideView(
            appURL: Bundle.main.bundleURL,
            onClose: { [weak self] in self?.dismiss() }
        ))
        panel.orderFrontRegardless()
        self.panel = panel

        NSWorkspace.shared.runningApplications
            .first { Self.settingsBundleIDs.contains($0.bundleIdentifier ?? "") }?
            .activate()
    }

    private func reposition(relativeTo settingsFrame: NSRect?) {
        guard let panel, let screen = screen(for: settingsFrame) ?? panel.screen ?? NSScreen.main else { return }
        let target = Self.frame(settingsFrame: settingsFrame, visibleFrame: screen.visibleFrame)
        if abs(panel.frame.origin.x - target.origin.x) > 1 || abs(panel.frame.origin.y - target.origin.y) > 1 {
            panel.setFrame(target, display: true, animate: true)
        }
        panel.orderFrontRegardless()
    }

    private static func frame(settingsFrame: NSRect?, visibleFrame: NSRect) -> NSRect {
        let width = min(max((settingsFrame?.width ?? visibleFrame.width * 0.48) * 0.72, 460), 620)
        if let settingsFrame {
            let x = min(visibleFrame.maxX - width - 16, max(visibleFrame.minX + 16, settingsFrame.maxX - width))
            let y = max(visibleFrame.minY + 16, settingsFrame.minY - panelHeight - 14)
            return NSRect(x: x, y: y, width: width, height: panelHeight)
        }
        return NSRect(x: visibleFrame.midX - width / 2, y: visibleFrame.minY + 120, width: width, height: panelHeight)
    }

    private func screen(for frame: NSRect?) -> NSScreen? {
        guard let frame else { return nil }
        return NSScreen.screens.first { $0.frame.intersects(frame) }
    }

    /// Frame of the System Settings window in AppKit coordinates, if visible.
    private func settingsWindowFrame() -> NSRect? {
        let pids = Set(NSWorkspace.shared.runningApplications
            .filter { Self.settingsBundleIDs.contains($0.bundleIdentifier ?? "") }
            .map(\.processIdentifier))
        guard !pids.isEmpty,
              let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        for window in windows {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t, pids.contains(pid),
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let x = bounds["X"] as? CGFloat, let y = bounds["Y"] as? CGFloat,
                  let w = bounds["Width"] as? CGFloat, let h = bounds["Height"] as? CGFloat,
                  w > 200, h > 200 else { continue }
            for screen in NSScreen.screens {
                let converted = NSRect(x: x, y: screen.frame.maxY - y - h, width: w, height: h)
                if screen.frame.intersects(converted) { return converted }
            }
        }
        return nil
    }
}

private struct GuideView: View {
    let appURL: URL
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false
    @State private var arrowRaised = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Close guide")
                Text("Turn on Nufi in the Accessibility list")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "arrow.up")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.red)
                    .offset(y: reduceMotion ? 0 : (arrowRaised ? -3 : 3))
                    .accessibilityHidden(true)
            }
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                    .resizable()
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nufi").font(.system(size: 15, weight: .semibold))
                    Text("Not listed? Drag this row into the list above.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 12)
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.primary.opacity(hovered ? 0.07 : 0.04))
            )
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .onHover { hovered = $0 }
            .onDrag { NSItemProvider(object: appURL as NSURL) }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1))
        )
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                arrowRaised = true
            }
        }
    }
}
