//
//  UNUserNotificationCenter.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 01.11.25.
//

import OSLog
import UserNotifications

public extension UNUserNotificationCenter {
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
            Logger.notificationCenter.info("Local notification scheduled: \(title)")
        } catch {
            Logger.notificationCenter.error("Failed to schedule local notification: \(error)")
        }
    }
}
