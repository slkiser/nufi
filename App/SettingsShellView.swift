import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, fileTypes, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .fileTypes: return "File Types"
        case .about: return "About"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "Where Nufi shows up and how the Finder menu behaves"
        case .fileTypes: return "What New File offers in Finder and the menu bar"
        case .about: return "Version, setup, and removal"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .fileTypes: return "doc.badge.plus"
        case .about: return "info.circle"
        }
    }

    var tint: Color {
        switch self {
        case .general: return .gray
        case .fileTypes: return .teal
        case .about: return .blue
        }
    }
}

@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var page: SettingsPage = .general
}

enum SettingsTheme {
    static let sidebarWidth: CGFloat = 180
    static let pageInset: CGFloat = 22
    static let cardRadius: CGFloat = 10
    static let cardPadding: CGFloat = 14
}

/// Sidebar + detail, in the shape of System Settings. Adapted from Trace's
/// settings shell, with semantic colors so dark mode works.
struct SettingsShellView: View {
    @ObservedObject var navigation: SettingsNavigation
    @StateObject private var model = SettingsModel()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detail
        }
        .frame(minWidth: 640, minHeight: 440)
        .ignoresSafeArea()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Brand row: the icon is larger than the page tiles on purpose,
            // inset so its plate's left edge lines up with them.
            // Plate is 940/1024 of the image, so a 28 pt image has a ~1 pt
            // transparent margin: 7 pt inset + 1 pt margin = the tiles' 8 pt.
            HStack(spacing: 6) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 28, height: 28)
                Text("Nufi").font(.body.weight(.semibold))
            }
            .padding(.horizontal, 5)
            .padding(.top, 44)
            .padding(.bottom, 12)

            ForEach(SettingsPage.allCases) { page in
                SidebarRow(page: page, isSelected: navigation.page == page) {
                    navigation.page = page
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(width: SettingsTheme.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background {
            ZStack(alignment: .trailing) {
                VisualEffect(material: .sidebar)
                Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 1)
            }
        }
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(navigation.page.title).font(.title2.weight(.bold))
                Text(navigation.page.subtitle).font(.callout).foregroundStyle(.secondary)
            }
            .padding(.horizontal, SettingsTheme.pageInset)
            .padding(.top, 44)
            .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch navigation.page {
                    case .general: GeneralPage(model: model)
                    case .fileTypes: FileTypesPage(model: model)
                    case .about: AboutPage()
                    }
                }
                .padding(.horizontal, SettingsTheme.pageInset)
                .padding(.bottom, SettingsTheme.pageInset)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(navigation.page)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SidebarRow: View {
    let page: SettingsPage
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [page.tint.opacity(0.75), page.tint],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 22, height: 22)
                    .overlay {
                        Image(systemName: page.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                Text(page.title).font(.body).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.1)
                          : (hovering ? Color.primary.opacity(0.05) : .clear))
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Titled card. Rows are separated by hairlines; `flush` drops the inner
/// padding for lists that draw their own rows.
struct SettingsCard<Content: View>: View {
    let title: String?
    var footer: String? = nil
    @ViewBuilder let content: Content

    init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: SettingsTheme.cardRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: SettingsTheme.cardRadius, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// One card row: label, optional caption, and a trailing control.
struct SettingsRow<Control: View>: View {
    let title: String
    var caption: String? = nil
    var showsDivider = true
    @ViewBuilder let control: Control

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let caption {
                        Text(caption).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 12)
                control
            }
            .padding(.horizontal, SettingsTheme.cardPadding)
            .padding(.vertical, 10)
            if showsDivider {
                Divider().padding(.leading, SettingsTheme.cardPadding)
            }
        }
    }
}

struct VisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
