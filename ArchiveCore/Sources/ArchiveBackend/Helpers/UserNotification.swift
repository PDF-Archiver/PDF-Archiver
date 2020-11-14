//
//  File.swift
//  
//
//  Created by Julian Kahnert on 14.09.20.
//

import UserNotifications

public enum UserNotification: Log {
    #if DEBUG
    public static func schedule(title: String, message: String) {
        let notificationCenter = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "[DEBUG] \(title)"
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "de.JulianKahnert.PDFArchiver.notifications.debug-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        notificationCenter.add(request) { error in
           if error != nil {
            Self.log.errorAndAssert("Notification could not be scheduled.")
           }
        }
    }
    #endif
}
