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
        let calendar = Calendar.current
        
        for task in tasks {
            guard task.status == .DUE || task.status == .UPCOMING else { continue }
            
            // due_date is "yyyy-MM-dd"; due_time is "HH:mm" (or "HH:mm:ss").
            let time = task.due_time.split(separator: ":").count == 2 ? "\(task.due_time):00" : task.due_time
            let dateString = "\(task.due_date)T\(time)"
            let localFormatter = DateFormatter()
            localFormatter.locale = Locale(identifier: "en_US_POSIX")
            localFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            localFormatter.timeZone = TimeZone.current
            
            guard let dueDate = localFormatter.date(from: dateString) else { continue }
            
            // Only schedule if it's in the future and within the next 24 hours to avoid spam
            guard dueDate > now, dueDate.timeIntervalSince(now) < 86400 else { continue }
            
            let content = UNMutableNotificationContent()
            content.title = "Care Plan Reminder"
            // Keep medication / task names off the lock screen.
            content.body = "You have a care plan task due."
            content.sound = .default
            
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            let request = UNNotificationRequest(identifier: "careplan-\(task.id)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
