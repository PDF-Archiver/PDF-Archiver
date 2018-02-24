//
//  TagHandling.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 21.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation
import Quartz

func dialogOK(message_key: String, info_key: String, style: NSAlert.Style) {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString(message_key, comment: "")
    alert.informativeText = NSLocalizedString(info_key, comment: "")
    alert.alertStyle = style
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

func regex_matches(for regex: String, in text: String) -> [String]? {

    do {
        let regex = try NSRegularExpression(pattern: regex)
        let results = regex.matches(in: text,
                                    range: NSRange(text.startIndex..., in: text))
        let output = results.map({ String(text[Range($0.range, in: text)!]) })
        if output.count == 0 {
            return nil
        } else {
            return output
        }
    } catch let error {
        print("invalid regex: \(error.localizedDescription)")
        return nil
    }
}

func getSubstring(_ raw: String, startIdx: Int, endIdx: Int) -> String {
    let start = raw.index(raw.startIndex, offsetBy: startIdx)
    let end = raw.index(raw.endIndex, offsetBy: endIdx)
    return String(describing: raw[start..<end])
}

func slugifyTag(_ rawIn: String) -> String {
    // normalize description
    var raw = rawIn.lowercased()
    raw = raw.replacingOccurrences(of: "[:;.,!?/\\^+<>#@|]", with: "",
                                   options: .regularExpression, range: nil)
    raw = raw.replacingOccurrences(of: " ", with: "")
    // german umlaute
    raw = raw.replacingOccurrences(of: "ä", with: "ae")
    raw = raw.replacingOccurrences(of: "ö", with: "oe")
    raw = raw.replacingOccurrences(of: "ü", with: "ue")
    return raw.replacingOccurrences(of: "ß", with: "ss")
}
