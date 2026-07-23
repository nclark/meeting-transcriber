@testable import MeetingTranscriber
import XCTest

final class QuickRecordResolverTests: XCTestCase {
    private let running = [
        RunningApp(id: 100, name: "Microsoft Teams", bundleIdentifier: "com.microsoft.teams2", icon: nil),
        RunningApp(id: 200, name: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap", icon: nil),
        RunningApp(id: 300, name: "NoBundleApp", bundleIdentifier: nil, icon: nil),
    ]

    func testNoDefaultShowsPicker() {
        XCTAssertEqual(
            QuickRecordResolver.resolve(defaultBundleID: "", running: running),
            .showPicker,
        )
    }

    func testDefaultNotRunningFallsBackToPicker() {
        XCTAssertEqual(
            QuickRecordResolver.resolve(defaultBundleID: "us.zoom.xos", running: running),
            .showPicker,
        )
    }

    func testDefaultRunningRecordsImmediately() {
        XCTAssertEqual(
            QuickRecordResolver.resolve(defaultBundleID: "com.tinyspeck.slackmacgap", running: running),
            .record(pid: 200, appName: "Slack"),
        )
    }

    func testEmptyRunningListShowsPicker() {
        XCTAssertEqual(
            QuickRecordResolver.resolve(defaultBundleID: "com.tinyspeck.slackmacgap", running: []),
            .showPicker,
        )
    }
}
