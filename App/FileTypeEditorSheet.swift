import SwiftUI

struct FileTypeEditorSheet: View {
    @State private var draft: FileTypeEntry
    let isNew: Bool
    let onSave: (FileTypeEntry) -> Void
    let onDelete: ((FileTypeEntry) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var extError: String?

    init(entry: FileTypeEntry, isNew: Bool,
         onSave: @escaping (FileTypeEntry) -> Void,
         onDelete: ((FileTypeEntry) -> Void)?) {
        _draft = State(initialValue: entry)
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isNew ? "New File Type" : "Edit \(draft.menuTitle)")
                .font(.title3.weight(.semibold))
                .padding(.bottom, 16)

            Form {
                if draft.isBuiltIn {
                    LabeledContent("Extension") {
                        Text(".\(draft.ext)").monospaced()
                    }
                } else {
                    TextField("Extension", text: $draft.ext, prompt: Text("md"))
                        .monospaced()
                        .onChange(of: draft.ext) { validate($0) }
                    if let extError {
                        Text(extError).font(.caption).foregroundStyle(.red)
                    }
                }
                TextField("Menu label", text: $draft.displayName,
                          prompt: Text(FileTypeEntry.derivedDisplayName(ext: draft.ext)))
                TextField("Filename", text: $draft.baseName,
                          prompt: Text(draft.ext.isEmpty ? "Untitled" : "Untitled (blank makes .\(draft.ext))"))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Starter template")
                    TextEditor(text: $draft.template)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                    Text("Written into every new file of this type. Leave empty for a blank file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.columns)

            HStack {
                if let onDelete, !draft.isBuiltIn, !isNew {
                    Button("Delete", role: .destructive) {
                        onDelete(draft)
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? "Add" : "Save") {
                    onSave(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(.top, 16)
        }
        .padding(20)
        .frame(width: 440)
    }

    private var canSave: Bool {
        draft.isBuiltIn || (try? FileTypeEntry.validateExtension(draft.ext)) != nil
    }

    private func validate(_ value: String) {
        do {
            let normalized = try FileTypeEntry.validateExtension(value)
            if normalized != draft.ext { draft.ext = normalized }
            extError = nil
        } catch FileTypeEntry.ValidationError.empty {
            extError = nil
        } catch FileTypeEntry.ValidationError.tooLong {
            extError = "Extension too long (max 16 characters)"
        } catch {
            extError = "Allowed: a-z, 0-9, . _ -"
        }
    }
}
