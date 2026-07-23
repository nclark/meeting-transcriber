import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var settings: AppSettings
    var updateChecker: UpdateChecker?
    /// Feeds the quick-record "Default app" picker. Injectable for tests;
    /// production uses the same provider as the Record App window.
    var appsProvider: any RunningAppsProvider = SystemRunningAppsProvider()

    @State private var runningApps: [RunningApp] = []

    var body: some View {
        // swiftlint:disable:next closure_body_length
        Form {
            Section("Mode") {
                Toggle("Record-only mode", isOn: $settings.recordOnly)
                    .accessibilityIdentifier(A11yID.recordOnlyToggle)
                if settings.recordOnly {
                    recordOnlyBanner
                }
            }

            Section("Global Hotkey") {
                globalHotkeyRows
            }

            Section("Apps to Watch") {
                Toggle("Microsoft Teams", isOn: $settings.watchTeams)
                Toggle("Zoom", isOn: $settings.watchZoom)
                Toggle("Webex", isOn: $settings.watchWebex)
            }

            Section("Detection") {
                HStack {
                    Text("Poll Interval")
                    Spacer()
                    TextField("", value: $settings.pollInterval, format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                    Stepper("", value: $settings.pollInterval, in: 1 ... 30, step: 0.5)
                        .labelsHidden()
                    Text("seconds").foregroundStyle(.secondary)
                }

                HStack {
                    Text("Grace Period")
                    Spacer()
                    TextField("", value: $settings.endGrace, format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                    Stepper("", value: $settings.endGrace, in: 1 ... 120, step: 1)
                        .labelsHidden()
                    Text("seconds").foregroundStyle(.secondary)
                }
            }

            if let updateChecker {
                updatesSection(updateChecker: updateChecker)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private var globalHotkeyRows: some View {
        HStack {
            Toggle(
                "Open \"Record App\" window",
                isOn: $settings.recordAppHotkeyEnabled,
            )
            .accessibilityIdentifier(A11yID.recordAppHotkeyToggle)
            Spacer()
            if settings.recordAppHotkeyEnabled {
                Text("Shortcut")
                    .foregroundStyle(.secondary)
                ShortcutRecorderView(combo: $settings.recordAppHotkeyCombo) { armed in
                    settings.hotkeyCaptureActive = armed
                }
                .accessibilityIdentifier(A11yID.recordAppHotkeyRecorder)
                Button("Reset") {
                    settings.recordAppHotkeyCombo = .recordAppDefault
                }
                .disabled(settings.recordAppHotkeyCombo == .recordAppDefault)
                .accessibilityIdentifier(A11yID.recordAppHotkeyReset)
            }
        }
        if settings.recordAppHotkeyEnabled {
            defaultAppRow
            Text(
                "Must include ⌘, ⌃, or ⌥. Works system-wide while Meeting Transcriber is running. " +
                    "With a default app set, the shortcut starts recording it immediately " +
                    "instead of opening the window.",
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    /// Indented sub-row of the hotkey toggle: which app the shortcut records
    /// without showing the picker. The stored default stays selectable even
    /// while its app isn't running (extra "(not running)" entry), so opening
    /// this menu never silently drops the saved choice.
    private var defaultAppRow: some View {
        Picker(selection: defaultAppSelection) {
            Text("None — ask every time").tag("")
            if !settings.quickRecordBundleID.isEmpty,
               !runningApps.contains(where: { $0.bundleIdentifier == settings.quickRecordBundleID }) {
                appMenuItem(
                    name: "\(settings.quickRecordAppName) (not running)",
                    icon: Self.installedAppIcon(bundleID: settings.quickRecordBundleID),
                )
                .tag(settings.quickRecordBundleID)
            }
            ForEach(runningApps.filter { $0.bundleIdentifier != nil }) { app in
                appMenuItem(name: app.name, icon: app.icon)
                    .tag(app.bundleIdentifier ?? "")
            }
        } label: {
            Text("Default app")
                .padding(.leading, 20)
        }
        .onAppear {
            runningApps = appsProvider.runningApps()
        }
    }

    /// Menu row mirroring the Record App window's icon + name layout.
    private func appMenuItem(name: String, icon: NSImage?) -> some View {
        HStack(spacing: 6) {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            }
            Text(name)
        }
    }

    /// Icon for an app that is installed but not running (the saved default
    /// after its app quit) — resolved from the app bundle on disk, since
    /// there is no NSRunningApplication to ask.
    private static func installedAppIcon(bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    /// Writes the display name alongside the bundle ID so the "(not
    /// running)" entry can render after relaunch.
    private var defaultAppSelection: Binding<String> {
        Binding(
            get: { settings.quickRecordBundleID },
            set: { newID in
                settings.quickRecordBundleID = newID
                settings.quickRecordAppName = newID.isEmpty
                    ? ""
                    : runningApps.first { $0.bundleIdentifier == newID }?.name ?? settings.quickRecordAppName
            },
        )
    }

    private var recordOnlyBanner: some View {
        let display = OutputSettingsLogic.displayPath(
            for: settings.effectiveOutputDir.appendingPathComponent("recordings"),
            home: FileManager.default.homeDirectoryForCurrentUser,
        )
        return Label {
            VStack(alignment: .leading, spacing: 4) {
                Text("Record-only mode is active.")
                    .font(.callout.weight(.semibold))
                Text(
                    "Files land in `\(display)`. Each recording gets a `<timestamp>_meta.json` " +
                        "sidecar next to its WAVs. No transcription, diarization, or protocol " +
                        "generation runs on this device.",
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
        }
        .padding(8)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        .accessibilityIdentifier(A11yID.recordOnlyBanner)
    }

    private func updatesSection(updateChecker: UpdateChecker) -> some View {
        // swiftlint:disable:next closure_body_length
        Section("Updates") {
            Toggle("Check for Updates", isOn: $settings.checkForUpdates)

            if settings.checkForUpdates {
                Toggle("Include Pre-Releases", isOn: $settings.includePreReleases)
            }

            HStack {
                Button {
                    updateChecker.checkNow(
                        includePreReleases: settings.includePreReleases,
                    )
                } label: {
                    HStack(spacing: 4) {
                        if updateChecker.isChecking {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Check Now")
                    }
                }
                .disabled(updateChecker.isChecking)

                if let error = updateChecker.lastError {
                    Label(error, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                } else if let update = updateChecker.availableUpdate {
                    Label(
                        "Update available: \(update.tagName)",
                        systemImage: "arrow.down.circle.fill",
                    )
                    .foregroundStyle(.blue)
                    .font(.caption)
                } else if updateChecker.lastCheckDate != nil {
                    Label("Up to date", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }

            if let update = updateChecker.availableUpdate {
                Button {
                    NSWorkspace.shared.open(update.dmgURL ?? update.htmlURL)
                } label: {
                    Label(
                        "Download \(update.tagName)",
                        systemImage: "arrow.down.to.line",
                    )
                }
            }
        }
    }
}
