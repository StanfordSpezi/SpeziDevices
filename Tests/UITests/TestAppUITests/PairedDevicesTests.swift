//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import XCTest
import XCTestExtensions


class PairedDevicesTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()

        continueAfterFailure = false
    }


    @MainActor
    func testTipsView() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--testTips"]
        app.launch()

        XCTAssert(app.buttons["Devices"].waitForExistence(timeout: 2.0))
        app.buttons["Devices"].tap()


        XCTAssert(app.staticTexts["Fully Unpair Device"].waitForExistence(timeout: 0.5))
        XCTAssert(app.buttons["Open Settings"].exists)
        app.buttons["Open Settings"].tap()

        let settingsApp = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        XCTAssertEqual(settingsApp.state, .runningForeground)
    }

    @MainActor
    func testDiscoveringView() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssert(app.buttons["Devices"].waitForExistence(timeout: 2.0))
        app.buttons["Devices"].tap()


        XCTAssert(app.staticTexts["No Devices"].exists)
        XCTAssert(app.buttons["Pair New Device"].exists)
        app.buttons["Pair New Device"].tap()

        XCTAssert(app.staticTexts["Discovering"].waitForExistence(timeout: 0.5))
        XCTAssert(app.navigationBars.buttons["Dismiss"].exists)
        app.navigationBars.buttons["Dismiss"].tap()

        XCTAssert(app.staticTexts["No Devices"].waitForExistence(timeout: 0.5))
        // TODO: customize the pairing hint!
    }

    @MainActor
    func testPairDevice() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssert(app.buttons["Devices"].waitForExistence(timeout: 2.0))
        app.buttons["Devices"].tap()

        XCTAssert(app.navigationBars.buttons["More"].exists)
        app.navigationBars.buttons["More"].tap()

        XCTAssert(app.buttons["Discover Device"].waitForExistence(timeout: 0.5))
        app.buttons["Discover Device"].tap()

        XCTAssert(app.staticTexts["Pair Accessory"].waitForExistence(timeout: 2.0))
        XCTAssert(app.staticTexts["Do you want to pair \"Mock Device\" with the TestApp app?"].exists)
        XCTAssert(app.buttons["Pair"].exists)
        app.buttons["Pair"].tap()

        XCTAssert(app.staticTexts["Accessory Paired"].waitForExistence(timeout: 5.0))
        XCTAssert(app.staticTexts["\"Mock Device\" was successfully paired with the TestApp app."].exists)
        XCTAssert(app.buttons["Done"].exists)
        app.buttons["Done"].tap()

        XCTAssert(app.buttons["Mock Device, 85 %"].waitForExistence(timeout: 0.5))
        app.buttons["Mock Device, 85 %"].tap()

        XCTAssert(app.navigationBars.staticTexts["Device Details"].waitForExistence(timeout: 2.0))
        XCTAssert(app.buttons["Name, Mock Device"].exists)
        XCTAssert(app.staticTexts["Model, MD1"].exists)
        XCTAssert(app.staticTexts["Battery, 85 %"].exists)
        XCTAssert(app.buttons["Forget This Device"].exists)
        XCTAssert(app.staticTexts["Synchronizing ..."].exists) // assert device currently connected

        app.buttons["Name, Mock Device"].tap()

        XCTAssert(app.textFields["enter device name"].exists)
        app.textFields["enter device name"].tap()
        app.typeText("2")

        app.dismissKeyboard()

        XCTAssert(app.navigationBars.buttons["Done"].waitForExistence(timeout: 0.5))
        app.navigationBars.buttons["Done"].tap()

        XCTAssert(app.staticTexts["Name, Mock Device2"].waitForExistence(timeout: 0.5))
        XCTAssert(app.navigationBars.buttons["Devices"].exists)
        app.navigationBars.buttons["Devices"].tap()

        XCTAssert(app.buttons["Mock Device2, 85 %"].waitForExistence(timeout: 2.0))

        XCTAssert(app.navigationBars.buttons["More"].exists)
        app.navigationBars.buttons["More"].tap()
        XCTAssert(app.buttons["Disconnect"].waitForExistence(timeout: 0.5))
        app.buttons["Disconnect"].tap()
        sleep(1)

        app.buttons["Mock Device2, 85 %"].tap()
        XCTAssert(app.navigationBars.buttons["Devices"].waitForExistence(timeout: 2.0))
        app.navigationBars.buttons["Devices"].tap()

        XCTAssert(app.navigationBars.buttons["More"].exists)
        app.navigationBars.buttons["More"].tap()
        XCTAssert(app.buttons["Connect"].waitForExistence(timeout: 0.5))
        app.buttons["Connect"].tap()
        sleep(3)


        XCTAssert(app.buttons["Mock Device2, 85 %"].waitForExistence(timeout: 0.5))
        app.buttons["Mock Device2, 85 %"].tap()

        XCTAssert(app.buttons["Forget This Device"].waitForExistence(timeout: 2.0))
        app.buttons["Forget This Device"].tap()

        XCTAssert(app.buttons["Forget Device"].waitForExistence(timeout: 2.0))
        app.buttons["Forget Device"].tap()


        XCTAssert(app.staticTexts["Fully Unpair Device"].waitForExistence(timeout: 2.0))
    }

    @MainActor
    func testPlusButton() {
        let app = XCUIApplication()
        app.launch()

        XCTAssert(app.buttons["Devices"].waitForExistence(timeout: 2.0))
        app.buttons["Devices"].tap()

        XCTAssert(app.navigationBars.buttons["More"].exists)
        app.navigationBars.buttons["More"].tap()

        XCTAssert(app.buttons["Discover Device"].waitForExistence(timeout: 0.5))
        app.buttons["Discover Device"].tap()

        XCTAssert(app.staticTexts["Pair Accessory"].waitForExistence(timeout: 2.0))
        XCTAssert(app.buttons["Dismiss"].exists)
        app.buttons["Dismiss"].tap()

        XCTAssert(app.navigationBars.buttons["Add Device"].exists)
        app.navigationBars.buttons["Add Device"].tap()

        XCTAssert(app.staticTexts["Pair Accessory"].waitForExistence(timeout: 2.0))
    }

    // TODO: forget devices test
}
