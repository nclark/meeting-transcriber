@testable import MeetingTranscriber
import XCTest

@MainActor
final class MeetingTranscriberAppTests: XCTestCase {
    // MARK: - shouldAutoWatch

    func testAutoWatchWithFlag() {
        let result = MeetingTranscriberApp.shouldAutoWatch(
            commandLineArgs: ["app", "--auto-watch"],
            autoWatchSetting: false,
        )
        XCTAssertTrue(result)
    }

    func testAutoWatchWithSetting() {
        let result = MeetingTranscriberApp.shouldAutoWatch(
            commandLineArgs: [],
            autoWatchSetting: true,
        )
        XCTAssertTrue(result)
    }

    func testAutoWatchBothFalse() {
        let result = MeetingTranscriberApp.shouldAutoWatch(
            commandLineArgs: [],
            autoWatchSetting: false,
        )
        XCTAssertFalse(result)
    }

    // MARK: - lastCompletedProtocolPath

    func testLastProtocolPathReturnsLatestJob() {
        let url = URL(fileURLWithPath: "/tmp/protocol.md")
        var job = PipelineJob(
            meetingTitle: "Test",
            appName: "Zoom",
            mixPath: URL(fileURLWithPath: "/tmp/mix.wav"),
            appPath: nil,
            micPath: nil,
            micDelay: 0,
        )
        job.protocolPath = url

        let result = MeetingTranscriberApp.lastCompletedProtocolPath(completedJobs: [job])
        XCTAssertEqual(result, url)
    }

    func testLastProtocolPathEmptyJobsReturnsNil() {
        let result = MeetingTranscriberApp.lastCompletedProtocolPath(completedJobs: [])
        XCTAssertNil(result)
    }

    // MARK: - recordAppHotkeyShouldOpen

    func testHotkeyOpensWhenIdle() {
        XCTAssertTrue(MeetingTranscriberApp.recordAppHotkeyShouldOpen(
            isManualRecording: false,
            state: .idle,
        ))
    }

    func testHotkeyOpensWhileWatching() {
        XCTAssertTrue(MeetingTranscriberApp.recordAppHotkeyShouldOpen(
            isManualRecording: false,
            state: .watching,
        ))
    }

    func testHotkeyBlockedWhileRecording() {
        // Mirrors the menu bar, which hides "Record App..." mid-recording.
        XCTAssertFalse(MeetingTranscriberApp.recordAppHotkeyShouldOpen(
            isManualRecording: false,
            state: .recording,
        ))
    }

    func testHotkeyBlockedDuringManualRecording() {
        XCTAssertFalse(MeetingTranscriberApp.recordAppHotkeyShouldOpen(
            isManualRecording: true,
            state: .idle,
        ))
    }

    func testLastProtocolPathNoProtocolReturnsNil() {
        let job = PipelineJob(
            meetingTitle: "Test",
            appName: "Zoom",
            mixPath: URL(fileURLWithPath: "/tmp/mix.wav"),
            appPath: nil,
            micPath: nil,
            micDelay: 0,
        )
        let result = MeetingTranscriberApp.lastCompletedProtocolPath(completedJobs: [job])
        XCTAssertNil(result)
    }
}
