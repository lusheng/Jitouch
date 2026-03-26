import Foundation
import XCTest

@testable import Jitouch

final class JitouchAppModelRuleEditingTests: XCTestCase {
    private var temporaryDirectoryURL: URL!

    override func setUpWithError() throws {
        let baseURL = FileManager.default.temporaryDirectory
        temporaryDirectoryURL = baseURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectoryURL {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
    }

    @MainActor
    func testAddGestureRuleEnablesDefaultProfileGestureWithRecommendedAction() throws {
        let model = try makeModel(named: "default-add.plist")

        model.addGestureRule(
            for: .trackpad,
            setID: "All Applications",
            gesture: "Three-Swipe-Left",
            defaultSetID: "All Applications"
        )

        let command = model.gestureCommand(
            for: .trackpad,
            setID: "All Applications",
            gesture: "Three-Swipe-Left"
        )

        XCTAssertTrue(command.isEnabled)
        XCTAssertEqual(command.command, "Mission Control")
    }

    @MainActor
    func testRemoveGestureRuleClearsDefaultProfileMapping() throws {
        let model = try makeModel(named: "default-remove.plist")

        model.removeGestureRule(
            for: .trackpad,
            setID: "All Applications",
            gesture: "Three-Finger Tap",
            defaultSetID: "All Applications"
        )

        let command = model.gestureCommand(
            for: .trackpad,
            setID: "All Applications",
            gesture: "Three-Finger Tap"
        )

        XCTAssertFalse(command.isEnabled)
        XCTAssertEqual(command.command, "-")
        XCTAssertFalse(
            model.commandSets(for: .trackpad)
                .first(where: { $0.id == "All Applications" })?
                .gestures
                .contains(where: { $0.gesture == "Three-Finger Tap" }) ?? true
        )
    }

    @MainActor
    func testAddGestureRuleToOverrideSeedsFromAllApplications() throws {
        let model = try makeModel(named: "override-add.plist")
        let overrideID = "/Applications/Safari.app"

        model.addApplicationOverride(
            for: .trackpad,
            application: "Safari",
            path: overrideID
        )

        model.addGestureRule(
            for: .trackpad,
            setID: overrideID,
            gesture: "Three-Finger Tap",
            defaultSetID: "All Applications"
        )

        let overrideCommand = model.gestureCommand(
            for: .trackpad,
            setID: overrideID,
            gesture: "Three-Finger Tap"
        )
        let defaultCommand = model.gestureCommand(
            for: .trackpad,
            setID: "All Applications",
            gesture: "Three-Finger Tap"
        )

        XCTAssertEqual(overrideCommand, defaultCommand)
        XCTAssertTrue(overrideCommand.isEnabled)
    }

    @MainActor
    func testRemoveGestureRuleFromOverrideClearsStoredOverrideRule() throws {
        let model = try makeModel(named: "override-remove.plist")
        let overrideID = "/Applications/Safari.app"

        model.addApplicationOverride(
            for: .trackpad,
            application: "Safari",
            path: overrideID
        )

        model.updateGestureCommand(
            GestureCommand(
                gesture: "Three-Finger Tap",
                command: "Refresh"
            ),
            for: .trackpad,
            setID: overrideID
        )

        model.removeGestureRule(
            for: .trackpad,
            setID: overrideID,
            gesture: "Three-Finger Tap",
            defaultSetID: "All Applications"
        )

        let storedGestures = model.commandSets(for: .trackpad)
            .first(where: { $0.id == overrideID })?
            .gestures ?? []

        XCTAssertFalse(storedGestures.contains(where: { $0.gesture == "Three-Finger Tap" }))
        XCTAssertEqual(
            model.gestureCommand(
                for: .trackpad,
                setID: "All Applications",
                gesture: "Three-Finger Tap"
            ).command,
            "Middle Click"
        )
    }

    @MainActor
    func testAddAndRemoveApplicationOverridePreservesDuplicateProtection() throws {
        let model = try makeModel(named: "override-roundtrip.plist")
        let initialCount = model.commandSets(for: .magicMouse).count

        model.addApplicationOverride(
            for: .magicMouse,
            application: "Safari",
            path: "/Applications/Safari.app"
        )

        XCTAssertEqual(model.commandSets(for: .magicMouse).count, initialCount + 1)

        model.addApplicationOverride(
            for: .magicMouse,
            application: "Safari",
            path: "/Applications/Safari.app"
        )

        XCTAssertEqual(model.commandSets(for: .magicMouse).count, initialCount + 1)
        XCTAssertEqual(model.lastError, "An override already exists for Safari.")

        model.removeApplicationOverride(for: .magicMouse, setID: "/Applications/Safari.app")

        XCTAssertEqual(model.commandSets(for: .magicMouse).count, initialCount)
    }

    @MainActor
    private func makeModel(named fileName: String) throws -> JitouchAppModel {
        let store = LegacySettingsStore(
            domainIdentifier: "com.jitouch.tests.\(UUID().uuidString)",
            preferencesURLOverride: temporaryDirectoryURL.appendingPathComponent(fileName)
        )
        try store.save(CommandCatalog.defaultSettings)
        return JitouchAppModel(
            settingsStore: store,
            shouldStartRuntimeServices: false
        )
    }
}
