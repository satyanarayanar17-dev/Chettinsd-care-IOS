import Foundation
import UserNotifications

public final class NotificationManager: Sendable {
    public static let shared = NotificationManager()
    
    private init() {}
    
    public func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }
    
    public func scheduleCarePlanReminders(tasks: [CarePlanOccurrenceDTO]) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        
        let now = Date()
        for task in tasks {
            guard let dueDate = Self.reminderDate(for: task, now: now) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Care Plan Reminder"
            // Keep medication / task names off the lock screen.
            content.body = "You have a care plan task due."
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: dueDate.timeIntervalSince(now), repeats: false)

            let request = UNNotificationRequest(identifier: "careplan-\(task.id)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
    /// Use the API's absolute instant, so a phone outside India does not shift clinic tasks.
    public static func reminderDate(for task: CarePlanOccurrenceDTO, now: Date = Date()) -> Date? {
        guard task.status == .DUE || task.status == .UPCOMING,
              let due = ISODate.parse(task.scheduled_for), due > now,
              due.timeIntervalSince(now) < 86400 else { return nil }
        return due
    }

}

/// Today occurrences omit reminder flags; read the existing care-plan route before scheduling.
public struct CarePlanReminderPolicy: Codable, Sendable {
    public struct Plan: Codable, Sendable { public let id: String }
    public struct Task: Codable, Sendable {
        public let id: String
        public let plan_id: String
        public let status: String
        public let reminder_enabled: Bool
        private enum CodingKeys: String, CodingKey { case id, plan_id, status, reminder_enabled }
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try values.decode(String.self, forKey: .id)
            plan_id = try values.decode(String.self, forKey: .plan_id)
            status = try values.decode(String.self, forKey: .status)
            if let enabled = try? values.decode(Bool.self, forKey: .reminder_enabled) { reminder_enabled = enabled }
            else { reminder_enabled = (try? values.decode(Int.self, forKey: .reminder_enabled)) == 1 }
        }
    }
    public let plan: Plan?
    public let tasks: [Task]
    public func eligible(_ occurrences: [CarePlanOccurrenceDTO]) -> [CarePlanOccurrenceDTO] {
        guard let plan else { return [] }
        let enabled = Set(tasks.filter { $0.plan_id == plan.id && $0.status == "ACTIVE" && $0.reminder_enabled }.map(\.id))
        return occurrences.filter { $0.plan_id == plan.id && enabled.contains($0.task_id) && $0.medication_source?.outdated != true }
    }
}
