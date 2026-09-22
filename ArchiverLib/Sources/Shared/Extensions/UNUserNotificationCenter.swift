//
//  UNUserNotificationCenter.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 01.11.25.
//

import ArchiverModels
import OSLog
import UserNotifications

public extension UNUserNotificationCenter {
    /// `title` and `body` must never carry document data - they are logged verbatim.
    func showLocalNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await requestAuthorization(options: [.provisional])

            try await add(request)
            Logger.notificationCenter.info("Local notification scheduled: \(title, privacy: .public)")
        } catch {
            Logger.notificationCenter.error("Failed to schedule local notification: \(LogRedact.describe(error), privacy: .public)")
        }
    }
}
