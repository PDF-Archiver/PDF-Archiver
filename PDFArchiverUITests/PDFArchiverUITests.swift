////
////  PDFArchiverUITests.swift
////  PDFArchiverUITests
////
////  Created by Julian Kahnert on 29.12.17.
////  Copyright © 2017 Julian Kahnert. All rights reserved.
////
//
//import XCTest
//
//class PDFArchiverUITests: XCTestCase {
//
//    override func setUp() {
//        super.setUp()
//
//        // Put setup code here. This method is called before the invocation of each test method in the class.
//
//        // In UI tests it is usually best to stop immediately when a failure occurs.
//        continueAfterFailure = false
//        // UI tests must launch the application that they test.
//        // Doing this in setup will make sure it happens for each test method.
////        XCUIApplication().launch()
//
//        // In UI tests it’s important to set the initial state - such as interface orientation -
//        // required for your tests before they run. The setUp method is a good place to do this.
//    }
//
//    override func tearDown() {
//        // Put teardown code here. This method is called after the invocation of each test method in the class.
//        super.tearDown()
//    }
//
////    func testOnboarding() {
////
////        let app = XCUIApplication()
////        app.launch()
////        let menuBarsQuery = app.menuBars
////        menuBarsQuery.menuBarItems["PDF Archiver"].click()
////        menuBarsQuery/*@START_MENU_TOKEN@*/.menuItems["prefrencesMenu"]/*[[".menuBarItems[\"PDF Archiver\"]",".menus",".menuItems[\"Preferences…\"]",".menuItems[\"prefrencesMenu\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.click()
////        app/*@START_MENU_TOKEN@*/.buttons["Change"]/*[[".dialogs[\"Preferences\"].buttons[\"Change\"]",".buttons[\"Change\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
////        app/*@START_MENU_TOKEN@*/.sheets["choose an archive folder"].outlines["sidebar"].staticTexts["Downloads"]/*[[".dialogs[\"Preferences\"].sheets[\"choose an archive folder\"]",".splitGroups",".scrollViews.outlines[\"sidebar\"]",".outlineRows",".cells.staticTexts[\"Downloads\"]",".staticTexts[\"Downloads\"]",".outlines[\"sidebar\"]",".sheets[\"choose an archive folder\"]"],[[[-1,7,1],[-1,0,1]],[[-1,6,3],[-1,2,3],[-1,1,2]],[[-1,6,3],[-1,2,3]],[[-1,5],[-1,4],[-1,3,4]],[[-1,5],[-1,4]]],[0,0,0]]@END_MENU_TOKEN@*/.click()
////        app/*@START_MENU_TOKEN@*/.sheets["choose an archive folder"].outlines["ListView"]/*[[".dialogs[\"Preferences\"].sheets[\"choose an archive folder\"]",".splitGroups",".scrollViews",".outlines[\"list view\"]",".outlines[\"ListView\"]",".sheets[\"choose an archive folder\"]"],[[[-1,5,1],[-1,0,1]],[[-1,4],[-1,3],[-1,2,3],[-1,1,2]],[[-1,4],[-1,3],[-1,2,3]],[[-1,4],[-1,3]]],[0,0]]@END_MENU_TOKEN@*/.children(matching: .outlineRow).element(boundBy: 7).cells.containing(.disclosureTriangle, identifier:"NSOutlineViewDisclosureButtonKey").children(matching: .textField).element.click()
////        app/*@START_MENU_TOKEN@*/.sheets["choose an archive folder"]/*[[".dialogs[\"Preferences\"].sheets[\"choose an archive folder\"]",".sheets[\"choose an archive folder\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.buttons["Open"].click()
////        app.dialogs["Preferences"].buttons[XCUIIdentifierCloseWindow].click()
////        app.windows["PDF Archiver"].buttons[XCUIIdentifierCloseWindow].click()
////
////    }
//
////    func testTmp() {
////
////        let app = XCUIApplication()
////        let pdfArchiverWindow = app.windows["PDF Archiver"]
////        pdfArchiverWindow.click()
////        pdfArchiverWindow/*@START_MENU_TOKEN@*/.tables["DocumentTableView"]/*[[".scrollViews.tables[\"DocumentTableView\"]",".tables[\"DocumentTableView\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.typeKey(",", modifierFlags:.command)
////        app/*@START_MENU_TOKEN@*/.buttons["Ändern"]/*[[".dialogs[\"Einstellungen\"].buttons[\"Ändern\"]",".buttons[\"Ändern\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
////
////        let einstellungenDialog = app.dialogs["Einstellungen"]
////        einstellungenDialog.click()
////        einstellungenDialog.buttons[XCUIIdentifierCloseWindow].click()
////        pdfArchiverWindow.buttons[XCUIIdentifierCloseWindow].click()
////
////    }
//    
////    func testSaveArchivePath() {
//
////        // reset user settings
////        let app = XCUIApplication()
////        app.launch()
////        let menuBarsQuery = app.menuBars
////        menuBarsQuery.menuBarItems["Help"].click()
////        menuBarsQuery.menuBarItems["Help"].menus.menuItems["Reset Settings"].click()
////
////        // open preferences
////        let app2 = XCUIApplication()
////        app2.launch()
////        app2.typeKey(",", modifierFlags:.command)
////
////        // get changed archive path
////        print(app2.children(matching: .button))
////        let clearTextFieldValue = app2.dialogs["Preferences"].textFields["archivePathTextField"].value as? String
////        XCTAssertEqual(clearTextFieldValue, "")
////
////        // change archive path and get the archive path value
////        app2.buttons["Change"].click()
////        let cells2 = app2.sheets["choose an archive folder"].outlines["ListView"].children(matching: .outlineRow).element(boundBy: 1).cells
////        cells2.containing(.disclosureTriangle, identifier:"NSOutlineViewDisclosureButtonKey").children(matching: .image).element.click()
////        app2.sheets["choose an archive folder"].buttons["Open"].click()
////        let changedTextFieldValue = app2.textFields["archivePathTextField"].value as? String
////
////        // close preferences panel and app
////        app2.dialogs["Preferences"].buttons[XCUIIdentifierCloseWindow].click()
////        app2.windows["PDF Archiver"].buttons[XCUIIdentifierCloseWindow].click()
////
////        // open preferences again and get the archive path value
////        let menuBarsQuery2 = app2.menuBars
////        menuBarsQuery2.menuBarItems["PDF Archiver"].click()
////        menuBarsQuery2.menuBarItems["PDF Archiver"].menus.menuItems["Preferences…"].click()
////        let reopenedTextFieldValue = app2.textFields["archivePathTextField"].value as? String
////
////        XCTAssertEqual(changedTextFieldValue, reopenedTextFieldValue)
////
////    }
//
//}
//
