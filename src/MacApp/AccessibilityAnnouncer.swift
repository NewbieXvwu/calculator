// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 对应原版 NarratorAnnouncement/NarratorNotifier
// (src/CalcViewModel/Common/Automation/NarratorAnnouncement.cpp):
// 以 NSAccessibility announcementRequested 通知向 VoiceOver 播报。
// high 优先级对应原版 ImportantMostRecent,medium 对应 MostRecent。

import AppKit

enum AccessibilityAnnouncer {
    static func announce(_ message: String, highPriority: Bool = true) {
        guard !message.isEmpty, let app = NSApp else { return }
        let element: Any = app.mainWindow ?? app
        NSAccessibility.post(
            element: element,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: (highPriority ? NSAccessibilityPriorityLevel.high : .medium).rawValue,
            ])
    }
}
