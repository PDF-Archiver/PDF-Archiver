//
//  File.swift
//  
//
//  Created by Julian Kahnert on 14.09.20.
//

// Corona-Warn-App
//
// SAP SE and all other contributors
// copyright owners license this file to you under the Apache
// License, Version 2.0 (the "License"); you may not use this
// file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import BackgroundTasks

enum BackgroundTaskIdentifier: String, CaseIterable {
    // only one task identifier is allowed have the .exposure-notification suffix
    case pdfProcessing = "pdf-processing"

    var backgroundTaskSchedulerIdentifier: String {
        guard let bundleID = Bundle.main.bundleIdentifier else { return "invalid-task-id!" }
        return "\(bundleID).\(rawValue)"
    }
}

protocol BackgroundTaskExecutionDelegate: AnyObject {
    func executeBackgroundTask(completion: @escaping ((Bool) -> Void))
}

/// - NOTE: To simulate the execution of a background task, use the following:
///         e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"de.JulianKahnert.PDFArchiveViewer.pdf-processing"]
///         To simulate the expiration of a background task, use the following:
///         e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"de.JulianKahnert.PDFArchiveViewer.pdf-processing"]
@available(iOS 13.0, *)
@available(macOS, unavailable)
@MainActor
final class BackgroundTaskScheduler: Log {

    // MARK: - Static.

    static let shared = BackgroundTaskScheduler()

    // MARK: - Attributes.

    weak var delegate: (any BackgroundTaskExecutionDelegate)?

    // MARK: - Initializer.

    private init() {
        registerTask(with: .pdfProcessing)
    }

    // MARK: - Task registration.

    private func registerTask(with taskIdentifier: BackgroundTaskIdentifier) {
        let identifierString = taskIdentifier.backgroundTaskSchedulerIdentifier
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifierString, using: .main) { task in
            let backgroundTask = DispatchWorkItem {
                self.taskItem(task, with: taskIdentifier)
            }

            task.expirationHandler = {
                self.scheduleTask(with: taskIdentifier)
                backgroundTask.cancel()
                task.setTaskCompleted(success: false)
                Self.log.error("Task has expired.", metadata: ["identifier": "\(taskIdentifier.rawValue)"])
                #if DEBUG
                UserNotification.schedule(title: "Start Background Task", message: "")
                #endif
            }

            DispatchQueue.global().async(execute: backgroundTask)
        }
    }

    // MARK: - Task scheduling.

    func scheduleTask(with taskIdentifier: BackgroundTaskIdentifier) {
        do {
            let taskRequest = BGProcessingTaskRequest(identifier: taskIdentifier.backgroundTaskSchedulerIdentifier)
            taskRequest.requiresNetworkConnectivity = true
            taskRequest.requiresExternalPower = false
            taskRequest.earliestBeginDate = nil
            try BGTaskScheduler.shared.submit(taskRequest)
        } catch {
            Self.log.errorAndAssert("ERROR: scheduleTask() could NOT submit task request: \(error)")
        }
    }

    // MARK: - Task execution handlers.

    private func taskItem(_ task: BGTask, with taskIdentifier: BackgroundTaskIdentifier) {
        delegate?.executeBackgroundTask { success in
            task.setTaskCompleted(success: success)
            if !success {
                self.scheduleTask(with: taskIdentifier)
            }
            #if DEBUG
            UserNotification.schedule(title: "Background Task Completed 🎉", message: "Status: \(success ? "success" : "failed")")
            #endif
        }
    }
}
