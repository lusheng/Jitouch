import Foundation
import XCTest

@testable import Jitouch

final class LegacySettingsStoreTests: XCTestCase {
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

    func testLoadReturnsDefaultSettingsWhenPreferencesFileIsMissing() {
        let store = makeStore(named: "missing.plist")

        let settings = store.load()

        XCTAssertEqual(settings.isEnabled, CommandCatalog.defaultSettings.isEnabled)
        XCTAssertEqual(settings.trackpadCommands, CommandCatalog.defaultSettings.trackpadCommands)
        XCTAssertFalse(store.preferencesFileExists)
    }

    func testLoadParsesLegacyValueTypesAndCommandSets() throws {
        let store = makeStore(named: "legacy-values.plist")

        try write(
            [
                "enAll": "0",
                "ClickSpeed": "0.40",
                "Sensitivity": NSNumber(value: 5.5),
                "ShowIcon": NSNumber(value: 0),
                "LogLevel": "2",
                "enTPAll": "1",
                "Handed": "1",
                "enMMAll": 0,
                "MMHanded": 0,
                "enCharRegTP": "1",
                "enCharRegMM": "0",
                "charRegIndexRingDistance": "0.41",
                "charRegMouseButton": "1",
                "enOneDrawing": "1",
                "enTwoDrawing": "0",
                "TrackpadCommands": [
                    [
                        "Application": "All Applications",
                        "Path": "",
                        "Gestures": [
                            [
                                "Gesture": "Three-Finger Tap",
                                "Command": "Middle Click",
                                "IsAction": true,
                                "ModifierFlags": 0,
                                "KeyCode": 0,
                                "Enable": "1",
                            ],
                        ],
                    ],
                ],
            ],
            to: store.preferencesURL
        )

        let settings = store.load()

        XCTAssertFalse(settings.isEnabled)
        XCTAssertEqual(settings.clickSpeed, 0.40, accuracy: 0.0001)
        XCTAssertEqual(settings.sensitivity, 5.5, accuracy: 0.0001)
        XCTAssertFalse(settings.showMenuBarIcon)
        XCTAssertEqual(settings.logLevel, .debug)
        XCTAssertEqual(settings.trackpadHandedness, .left)
        XCTAssertTrue(settings.trackpadCharacterRecognitionEnabled)
        XCTAssertEqual(settings.characterRecognitionMouseButton, 1)
        XCTAssertTrue(settings.oneFingerDrawingEnabled)
        XCTAssertFalse(settings.twoFingerDrawingEnabled)
        XCTAssertEqual(settings.trackpadCommands.first?.gestures.first?.gesture, "Three-Finger Tap")
        XCTAssertEqual(settings.trackpadCommands.first?.gestures.first?.command, "Middle Click")
    }

    func testSaveAndReloadRoundTripsSettings() throws {
        let store = makeStore(named: "roundtrip.plist")
        var settings = CommandCatalog.defaultSettings
        settings.isEnabled = false
        settings.clickSpeed = 0.33
        settings.sensitivity = 5.2
        settings.trackpadEnabled = false
        settings.magicMouseEnabled = false
        settings.trackpadCharacterRecognitionEnabled = true
        settings.magicMouseCharacterRecognitionEnabled = true
        settings.characterRecognitionMouseButton = 1
        settings.trackpadCommands = [
            ApplicationCommandSet(
                application: "All Applications",
                gestures: [
                    GestureCommand(gesture: "Four-Finger Tap", command: "Mission Control"),
                ]
            ),
        ]

        try store.save(settings)
        let reloaded = store.load()

        XCTAssertFalse(reloaded.isEnabled)
        XCTAssertEqual(reloaded.clickSpeed, 0.33, accuracy: 0.0001)
        XCTAssertEqual(reloaded.sensitivity, 5.2, accuracy: 0.0001)
        XCTAssertFalse(reloaded.trackpadEnabled)
        XCTAssertFalse(reloaded.magicMouseEnabled)
        XCTAssertTrue(reloaded.trackpadCharacterRecognitionEnabled)
        XCTAssertTrue(reloaded.magicMouseCharacterRecognitionEnabled)
        XCTAssertEqual(reloaded.characterRecognitionMouseButton, 1)
        XCTAssertEqual(reloaded.trackpadCommands, settings.trackpadCommands)
        XCTAssertTrue(store.preferencesFileExists)
    }

    private func makeStore(named fileName: String) -> LegacySettingsStore {
        LegacySettingsStore(
            domainIdentifier: "com.jitouch.tests.\(UUID().uuidString)",
            preferencesURLOverride: temporaryDirectoryURL.appendingPathComponent(fileName)
        )
    }

    private func write(_ propertyList: [String: Any], to url: URL) throws {
        let data = try PropertyListSerialization.data(
            fromPropertyList: propertyList,
            format: .xml,
            options: 0
        )
        try data.write(to: url, options: .atomic)
    }
}
