import XCTest

final class CourseLinkUITests: XCTestCase {
    @MainActor func testSystemCourseLinksShowReadOnlySession() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.ithtelab.campustimetable")
        defer { app.terminate(); XCUIDevice.shared.appearance = .light }
        XCUIDevice.shared.appearance = .light
        app.terminate()
        app.open(try XCTUnwrap(URL(string: "campusschedule://course?id=math-mon&term=demo-term-v1")))
        confirmSystemOpenIfNeeded(app)
        assertSession(app, title: "高等数学", screenshot: "course-now-cold-light")
        app.open(try XCTUnwrap(URL(string: "campusschedule://course?id=english-mon&term=demo-term-v1")))
        confirmSystemOpenIfNeeded(app)
        assertSession(app, title: "大学英语", screenshot: "course-now-second-light")

        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            XCUIDevice.shared.appearance = dark ? .dark : .light
            app.terminate()
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
            XCTAssertTrue(app.alerts["课程安排已更新"].waitForExistence(timeout: 15))
            capture(app, name: "course-now-unavailable-\(suffix)")
            app.alerts.buttons["查看课表"].tap()
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
