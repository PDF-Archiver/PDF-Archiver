//
//  SupportMail.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 23.05.24.
//

import Foundation

func sendMail(recipient: String, subject: String, body: String = "") {
    let url = URL(string: "mailto:\(recipient)?subject=\(subject)&body=\(body)")!
    open(url)
}
