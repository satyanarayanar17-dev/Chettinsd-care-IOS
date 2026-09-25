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
            
            // Assuming due_date is "YYYY-MM-DD" and due_time is "HH:MM"
            let dateString = "\(task.due_date)T\(task.due_time):00"
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            // Need a simpler formatter if it doesn't have fractional seconds / timezone.
            let localFormatter = DateFormatter()
            localFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            localFormatter.timeZone = TimeZone.current
            
            guard let dueDate = localFormatter.date(from: dateString) else { continue }
            
            // Only schedule if it's in the future and within the next 24 hours to avoid spam
            guard dueDate > now, dueDate.timeIntervalSince(now) < 86400 else { continue }
            
            let content = UNMutableNotificationContent()
            content.title = "Care Plan Reminder"
            content.body = "It's time for: \(task.title)"
            content.sound = .default
            
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            let request = UNNotificationRequest(identifier: "careplan-\(task.id)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
