import Foundation

/// What a press of the Record-App shortcut should do.
enum QuickRecordAction: Equatable {
    case record(pid: pid_t, appName: String)
    case showPicker
}

/// Pure decision logic for the Record-App shortcut: with a default app
/// configured *and* running, record it immediately; in every other case
/// fall back to the picker window (which shows the actual running apps,
/// so a missing default degrades to the no-default behaviour instead of
/// a dead-ended notification).
enum QuickRecordResolver {
    static func resolve(
        defaultBundleID: String,
        running: [RunningApp],
    ) -> QuickRecordAction {
        guard !defaultBundleID.isEmpty,
              let app = running.first(where: { $0.bundleIdentifier == defaultBundleID })
        else { return .showPicker }
        return .record(pid: app.id, appName: app.name)
    }
}
