import XCTest
import UIKit

final class CourseLinkUITests: XCTestCase {
    @MainActor func testAppearanceSwitchesAndDarkImport() {
        continueAfterFailure = false
        let app = XCUIApplication()
        XCUIDevice.shared.appearance = .light
        app.launch()
        app.tabBars.buttons["设置"].tap()
        selectAppearance("深色", in: app)
        assertBackground(dark: true, in: app)

        app.tabBars.buttons["课表"].tap()
        let importButton = app.buttons["schedule.empty.import"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 8))
        assertBackground(dark: true, in: app)
        capture(app, name: "dark-empty-import-button")
        importButton.tap()
        XCTAssertTrue(app.navigationBars["导入课表"].waitForExistence(timeout: 8))
        assertBackground(dark: true, in: app)
        capture(app, name: "dark-import-sheet")
        app.navigationBars["导入课表"].buttons["取消"].tap()

        app.tabBars.buttons["设置"].tap()
        let themes = app.buttons["人物与主题"]
        reveal(themes, in: app)
        themes.tap()
        XCTAssertTrue(app.buttons["appearance.persona.girl"].waitForExistence(timeout: 8))
        reveal(app.buttons["appearance.theme.notebook"], in: app)
        app.buttons["appearance.theme.notebook"].tap()
        capture(app, name: "dark-theme-swatches")
        app.navigationBars["人物与主题"].buttons.firstMatch.tap()

        selectAppearance("跟随系统", in: app)
        assertBackground(dark: false, in: app)
        capture(app, name: "appearance-follows-light-system")
        selectAppearance("深色", in: app)
        assertBackground(dark: true, in: app)
        selectAppearance("浅色", in: app)
        assertBackground(dark: false, in: app)
        capture(app, name: "appearance-explicit-light")
    }

    @MainActor private func selectAppearance(_ option: String, in app: XCUIApplication) {
        let picker = app.buttons["settings.appearance"]
        reveal(picker, in: app)
        picker.tap()
        let choice = app.buttons[option].firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
    }

    @MainActor private func assertBackground(dark: Bool, in app: XCUIApplication) {
        for _ in 0..<8 {
            if let image = app.screenshot().image.cgImage,
               let pixel = image.cropping(to: CGRect(x: Double(image.width) * 0.014,
                                                     y: Double(image.height) * 0.56, width: 1, height: 1)) {
                var rgba = [UInt8](repeating: 0, count: 4)
                let sampled = rgba.withUnsafeMutableBytes { buffer in
                    guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1,
                                                  bitsPerComponent: 8, bytesPerRow: 4,
                                                  space: CGColorSpaceCreateDeviceRGB(),
                                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                    context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                    return true
                }
                if sampled && (dark ? rgba[0] < 65 : rgba[0] > 180) { return }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        capture(app, name: "unexpected-interface-style")
        XCTFail("Expected a \(dark ? "dark" : "light") screen background")
    }

    @MainActor func testReleaseStartsEmptyAndHasPrivacyPolicy() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment = [:]
        app.launchArguments = ["-appAppearance", "light"]
        app.launch()
        XCTAssertTrue(app.staticTexts["还没有课程"].waitForExistence(timeout: 15))
        capture(app, name: "release-empty-timetable")
        app.tabBars.buttons["设置"].tap()
        let sync = app.switches["settings.icloud"]
        reveal(sync, in: app)
        XCTAssertTrue(sync.isEnabled)
        let about = app.buttons["settings.about"]
        reveal(about, in: app)
        about.tap()
        XCTAssertTrue(app.navigationBars["关于课间册"].waitForExistence(timeout: 8))
        capture(app, name: "release-about")
        app.buttons["about.privacy"].tap()
        XCTAssertTrue(app.staticTexts["设备上的数据"].waitForExistence(timeout: 8))
        capture(app, name: "release-privacy")
    }

    @MainActor func testAppearanceRehearsalAndStaticMode() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-appAppearance", "light"]
        app.launchEnvironment = ["CAMPUS_PREVIEW_TAB": "settings", "CAMPUS_PREVIEW_SHEET": "appearance"]
        app.launch()

        let theme = app.staticTexts["appearance.preview.theme"]
        XCTAssertTrue(theme.waitForExistence(timeout: 15))
        let character = app.buttons["appearance.preview.character"]
        XCTAssertTrue(character.exists)
        character.tap()
        let response = app.staticTexts["appearance.preview.response"]
        XCTAssertTrue(response.wait(for: \.label, toEqual: "刚刚 · 翻一页", timeout: 6))
        capture(app, name: "appearance-rehearsal-light")

        app.buttons["appearance.persona.boy"].tap()
        XCTAssertTrue(app.buttons["appearance.persona.boy"].isSelected)
        reveal(app.buttons["appearance.theme.notebook"], in: app)
        app.buttons["appearance.theme.notebook"].tap()
        app.swipeDown()
        XCTAssertEqual(theme.label, "校园手账")
        capture(app, name: "appearance-notebook-light")

        let staticMode = app.buttons["静态"]
        reveal(staticMode, in: app)
        staticMode.tap()
        app.swipeDown()
        app.swipeDown()
        XCTAssertFalse(character.exists)
        XCTAssertFalse(response.exists)
    }

    @MainActor func testMilestonePreviewAndPin() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-appAppearance", "dark"]
        app.launchEnvironment = ["CAMPUS_PREVIEW_TAB": "settings", "CAMPUS_PREVIEW_SHEET": "milestones"]
        app.launch()
        let add = app.buttons["milestone.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        add.tap()
        app.buttons["milestone.template.relationship"].tap()
        let title = app.textFields["milestone.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        XCTAssertEqual(title.value as? String, "我们的恋爱日")
        XCTAssertEqual(app.staticTexts["milestone.counter"].label, "今天")
        XCTAssertTrue(app.staticTexts["距离百日纪念还有 100 天"].exists)
        capture(app, name: "relationship-editor-dark")
        app.buttons["保存"].tap()

        let item = app.staticTexts["我们的恋爱日"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 8))
        item.tap()
        let pin = app.buttons["milestone.pin"]
        XCTAssertTrue(pin.waitForExistence(timeout: 8))
        let heart = app.buttons["milestone.heart"]
        XCTAssertTrue(heart.isHittable)
        heart.tap()
        XCTAssertEqual(heart.value as? String, "收到啦")
        pin.tap()
        XCTAssertEqual(pin.label, "取消置顶")
        capture(app, name: "relationship-detail-dark")
        app.tabBars.buttons["今日"].tap()
        let pinned = app.buttons["我们的恋爱日就是今天"]
        reveal(pinned, in: app)
        capture(app, name: "relationship-today-dark")
        pinned.tap()
        XCTAssertTrue(pin.waitForExistence(timeout: 8))
        pin.tap()
        XCTAssertEqual(pin.label, "置顶到今日页")
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor func testSystemCourseLinksShowReadOnlySession() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.ithtelab.campustimetable")
        defer { app.terminate(); XCUIDevice.shared.appearance = .light }
        XCUIDevice.shared.appearance = .light
        app.terminate()
        app.open(try XCTUnwrap(URL(string: "campusschedule://course?id=removed-course")))
        confirmSystemOpenIfNeeded(app)
        XCTAssertTrue(app.staticTexts["课程安排已更新"].waitForExistence(timeout: 15))
        app.launchEnvironment = ["CAMPUS_PREVIEW_TAB": "today"]
        app.launch()
        app.open(try XCTUnwrap(URL(string: "campusschedule://course?id=english-mon&term=preview-term")))
        confirmSystemOpenIfNeeded(app)
        assertSession(app, title: "大学英语", screenshot: "course-now-second-light")

        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            XCUIDevice.shared.appearance = dark ? .dark : .light
            app.terminate()
            // Exercise the real AppStorage appearance preference; the simulator's device override may be ignored.
            app.launchArguments = ["-appAppearance", dark ? "dark" : "light"]
            app.launchEnvironment = ["CAMPUS_PREVIEW_TAB": "today", "CAMPUS_PREVIEW_SHEET": "course"]
            app.launch()
            XCTAssertTrue(app.navigationBars["添加课程"].waitForExistence(timeout: 15))
            capture(app, name: "course-now-editor-before-\(suffix)")
            app.open(try XCTUnwrap(URL(string: "campusschedule://course?id=english-mon")))
            confirmSystemOpenIfNeeded(app)
            assertSession(app, title: "大学英语", screenshot: "course-now-from-editor-\(suffix)")
            app.open(try XCTUnwrap(URL(string: "campusschedule://course?id=math-mon")))
            confirmSystemOpenIfNeeded(app)
            assertSession(app, title: "高等数学", screenshot: "course-now-repeated-\(suffix)")
            app.open(try XCTUnwrap(URL(string: "campusschedule://course?id=removed-course")))
            confirmSystemOpenIfNeeded(app)
            XCTAssertTrue(app.staticTexts["课程安排已更新"].waitForExistence(timeout: 15))
            capture(app, name: "course-now-unavailable-\(suffix)")
            app.buttons["查看课表"].tap()
        }
    }

    @MainActor private func assertSession(_ app: XCUIApplication, title: String, screenshot: String) {
        XCTAssertTrue(app.navigationBars["本次课程"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["course.now.title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["course.now.title"].label, title)
        XCTAssertEqual(app.textFields.count, 0, "The system entry must not display a course editor")
        XCTAssertFalse(app.buttons["编辑"].exists)
        capture(app, name: screenshot)
    }

    @MainActor private func confirmSystemOpenIfNeeded(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.alerts.buttons["Open"]
        if open.waitForExistence(timeout: 2) { open.tap() }
        else if app.alerts.buttons["Open"].exists { app.alerts.buttons["Open"].tap() }
    }

    @MainActor private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
