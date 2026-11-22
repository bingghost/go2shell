import AppKit
import Go2ShellCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: SettingsModel
    var testAction: () -> Void

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section(L("settings.section.terminal")) {
                if model.configuredTerminalMissing {
                    Label(L("settings.terminalMissing", model.terminal.displayName), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                Picker(L("settings.terminal"), selection: $model.terminal) {
                    ForEach(model.installedTerminals, id: \.self) { kind in
                        HStack {
                            if let icon = model.icon(for: kind) {
                                Image(nsImage: icon)
                            }
                            Text(verbatim: kind.displayName)
                        }
                        .tag(kind)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section(L("settings.section.command")) {
                HStack {
                    TextField(L("settings.command"), text: $model.commandTemplate)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                    Button(L("settings.command.reset")) { model.resetCommand() }
                }
                .disabled(!model.terminal.supportsCommand)
                if model.terminal.supportsCommand {
                    Text(L("settings.command.help"))
                        .font(.caption).foregroundStyle(.secondary)
                    LabeledContent(L("settings.command.preview")) {
                        Text(verbatim: model.commandPreview)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                } else {
                    Text(L("settings.command.unsupported", model.terminal.displayName))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section(L("settings.section.openMode")) {
                Picker(L("settings.openMode"), selection: $model.openMode) {
                    Text(L("settings.openMode.newWindow")).tag(OpenMode.newWindow)
                    Text(L("settings.openMode.newTab")).tag(OpenMode.newTab)
                }
                .pickerStyle(.segmented)
                .disabled(!model.terminal.supportsNewTab)
                if model.terminal.newTabIsExperimental && model.openMode == .newTab {
                    Text(L("settings.openMode.experimental"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle(L("settings.preferSelectedFolder"), isOn: $model.preferSelectedFolder)
            }

            Section(L("settings.section.toolbar")) {
                Text(L("settings.toolbar.instructions"))
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(L("settings.toolbar.reveal")) {
                        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                    }
                    ToolbarInstallButtons()
                }
            }

            Section {
                HStack {
                    Button(L("settings.test"), action: testAction)
                    Spacer()
                    Text(L("settings.version", version))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Placeholder until ToolbarInstaller lands in M7.
struct ToolbarInstallButtons: View {
    var body: some View { EmptyView() }
}
