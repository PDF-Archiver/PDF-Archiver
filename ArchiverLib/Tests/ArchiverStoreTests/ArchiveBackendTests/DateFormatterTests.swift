//
//  DateFormatterTests.swift
//  ArchiverLib
//

import ArchiverModels
import Foundation
import Testing

/// Every filename goes through `yyyyMMdd`. A device set to the Buddhist or Japanese calendar
/// would otherwise write `2569-10-04--…` and read Gregorian names as the year 2569.
struct DateFormatterTests {
    @Test
    func filenameDatesAreGregorianWhateverTheDeviceCalendar() {
        let formatter = DateFormatter.yyyyMMdd

        #expect(formatter.locale.identifier == "en_US_POSIX")
        #expect(formatter.calendar.identifier == .gregorian)
    }
}
