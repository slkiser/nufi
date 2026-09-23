import SwiftUI

struct GeneralPage: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsCard("Show Nufi in", footer: "One of these stays on so Nufi remains reachable. The menu bar item is the Desktop path: click the wallpaper, then the icon.") {
            SettingsRow(title: "Menu bar", caption: "New File and Paste for the folder Finder is showing, or the Desktop.") {
                Toggle("", isOn: $model.showMenuBarItem).labelsHidden().toggleStyle(.switch)
            }
            SettingsRow(title: "Dock", caption: "Regular app with a Dock icon and menu bar menus.", showsDivider: false) {
                Toggle("", isOn: $model.showDockIcon).labelsHidden().toggleStyle(.switch)
            }
        }

        SettingsCard("Startup") {
            SettingsRow(title: "Open Nufi at login", caption: model.loginError, showsDivider: false) {
                Toggle("", isOn: $model.launchAtLogin).labelsHidden().toggleStyle(.switch)
            }
        }

        SettingsCard("Finder right-click menu") {
            SettingsRow(title: "Group file types under New File", caption: "Off lists each enabled type directly. Paste as New File stays a submenu.") {
                Toggle("", isOn: $model.useRightClickSubmenu).labelsHidden().toggleStyle(.switch)
            }
            SettingsRow(title: "Also show on a folder right-clicked in its parent", caption: "Files then go into that folder instead of the open one.", showsDivider: false) {
                Toggle("", isOn: $model.createInSelectedFolder).labelsHidden().toggleStyle(.switch)
            }
        }
    }
}

struct FileTypesPage: View {
    @ObservedObject var model: SettingsModel
    @State private var editing: FileTypeEntry?
    @State private var adding = false

    var body: some View {
        SettingsCard(nil, footer: "Checked types appear under New File in Finder and in the menu bar. Drag the handle to reorder. Double-click a row to edit it.") {
            ForEach($model.fileTypes) { $entry in
                FileTypeRow(entry: $entry, onEdit: { editing = entry }, onDrag: {
                    NSItemProvider(object: entry.id.uuidString as NSString)
                })
                .onDrop(of: [.text], delegate: ReorderDropDelegate(
                    item: entry, list: $model.fileTypes, dragging: $dragging))
            }
            Button {
                adding = true
            } label: {
                Label("Add File Type…", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SettingsTheme.cardPadding)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
        .sheet(item: $editing) { entry in
            FileTypeEditorSheet(entry: entry, isNew: false, onSave: model.save, onDelete: model.delete)
        }
        .sheet(isPresented: $adding) {
            FileTypeEditorSheet(
                entry: FileTypeEntry(ext: "", baseName: "", displayName: "", enabled: true),
                isNew: true, onSave: model.save, onDelete: nil)
        }
    }

    @State private var dragging: UUID?
}

private struct FileTypeRow: View {
    @Binding var entry: FileTypeEntry
    let onEdit: () -> Void
    let onDrag: () -> NSItemProvider
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.quaternary)
                    .frame(width: 14)
                    .onDrag(onDrag)
                    .help("Drag to reorder")
                Toggle("", isOn: $entry.enabled)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.menuTitle)
                    Text("\(entry.baseName).\(entry.ext)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !entry.template.isEmpty {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.tertiary)
                        .help("Has a starter template")
                }
                if !entry.isBuiltIn {
                    Text("Custom")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                        .foregroundStyle(.secondary)
                }
                Button("Edit…", action: onEdit)
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.accentColor)
                    .opacity(hovering ? 1 : 0.7)
            }
            .padding(.horizontal, SettingsTheme.cardPadding)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(hovering ? Color.primary.opacity(0.03) : .clear)
            .onHover { hovering = $0 }
            .onTapGesture(count: 2, perform: onEdit)
            Divider().padding(.leading, SettingsTheme.cardPadding)
        }
    }
}

/// Moves the dragged row as the cursor passes over other rows.
private struct ReorderDropDelegate: DropDelegate {
    let item: FileTypeEntry
    @Binding var list: [FileTypeEntry]
    @Binding var dragging: UUID?

    func dropEntered(info: DropInfo) {
        let id = dragging ?? list.first { _ in false }?.id
        guard let from = list.firstIndex(where: { $0.id == (id ?? item.id) }),
              let to = list.firstIndex(where: { $0.id == item.id }), from != to else { return }
        withAnimation {
            list.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func validateDrop(info: DropInfo) -> Bool {
        if dragging == nil, let provider = info.itemProviders(for: [.text]).first {
            provider.loadObject(ofClass: NSString.self) { object, _ in
                if let raw = object as? String, let id = UUID(uuidString: raw) {
                    DispatchQueue.main.async { dragging = id }
                }
            }
        }
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

struct AboutPage: View {
    var body: some View {
        SettingsCard(nil) {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nufi").font(.title3.weight(.semibold))
                    Text("Version \(NufiIdentity.marketingVersion)").foregroundStyle(.secondary)
                    Text("Paste copied text as a new file, right from Finder.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(SettingsTheme.cardPadding)
        }

        SettingsCard("Links") {
            SettingsRow(title: "Source and issues", caption: "github.com/slkiser/nufi") {
                Button("Open") { open("https://github.com/slkiser/nufi") }
            }
            SettingsRow(title: "License", caption: "MIT. Based on NewFile by mariusgm.", showsDivider: false) {
                Button("Open") { open("https://github.com/slkiser/nufi/blob/main/LICENSE") }
            }
        }

        SettingsCard("Maintenance") {
            SettingsRow(title: "Setup checklist", caption: "Re-check the Finder extension and permissions.") {
                Button("Open…") { Windows.shared.showOnboarding() }
            }
            SettingsRow(title: "Uninstall Nufi", caption: "Turns off the Finder extension so the app can be dragged to the Trash.", showsDivider: false) {
                Button("Uninstall…") { UninstallHelper.run() }
            }
        }
    }

    private func open(_ raw: String) {
        if let url = URL(string: raw) { NSWorkspace.shared.open(url) }
    }
}
