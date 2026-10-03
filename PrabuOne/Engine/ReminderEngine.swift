import Foundation
import UserNotifications
import os

/// The Universal Reminder Engine for My One.
/// Schedules multi-stage local notifications (30d, 7d, 3d, 1d, 0d) for any LifeItem without external servers.
public final class ReminderEngine: NSObject {
    public static let shared = ReminderEngine()
    private let logger = Logger(subsystem: "com.prabuganesan.prabuone", category: "ReminderEngine")
    
    private override init() {
        super.init()
    }
    
    /// Requests notification permissions from the user.
    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                self.logger.info("Notification permissions granted")
            } else if let error = error {
                self.logger.error("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Schedules multi-stage reminder alerts for a life item.
    public func scheduleReminders(for item: LifeItem) {
        // Cancel existing notifications for this item first
        cancelReminders(for: item)
        
        guard !item.isCompleted else { return }
        
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        
        for daysBefore in item.reminderDaysBefore {
            guard let triggerDate = calendar.date(byAdding: .day, value: -daysBefore, to: item.dueDate) else { continue }
            
            // Set alert to 9:00 AM on the target morning
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: triggerDate)
            dateComponents.hour = 9
            dateComponents.minute = 0
            
            guard let scheduledFireDate = calendar.date(from: dateComponents), scheduledFireDate > Date() else {
                continue
            }
            
            let content = UNMutableNotificationContent()
            content.title = "\(item.category.rawValue): \(item.title)"
            
            if daysBefore == 0 {
                content.body = item.amount != nil ? "\(item.title) of \(item.formattedAmount ?? "") is due today!" : "\(item.title) is today!"
            } else if daysBefore == 1 {
                content.body = item.amount != nil ? "\(item.title) of \(item.formattedAmount ?? "") is due tomorrow!" : "\(item.title) is tomorrow!"
            } else {
                content.body = item.amount != nil ? "\(item.title) (\(item.formattedAmount ?? "")) is due in \(daysBefore) days." : "\(item.title) is in \(daysBefore) days."
            }
            
            content.sound = .default
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let identifier = "prabuone-\(item.id.uuidString)-\(daysBefore)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            center.add(request) { error in
                if let error = error {
                    self.logger.error("Failed to schedule alert for \(item.title): \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Cancels all scheduled notification stages for an item.
    public func cancelReminders(for item: LifeItem) {
        let center = UNUserNotificationCenter.current()
        let identifiers = item.reminderDaysBefore.map { "prabuone-\(item.id.uuidString)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    // MARK: - Quick Note Reminders
    
    /// Schedules a dedicated timed alert for a quick note.
    public func scheduleNoteReminder(for note: QuickNote) {
        cancelNoteReminder(for: note.id)
        
        guard let fireDate = note.reminderDate, !note.isReminderCompleted, fireDate > Date() else {
            return
        }
        
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        
        let content = UNMutableNotificationContent()
        content.title = "Reminder: \(note.displayTitle)"
        let bodySnippet = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        content.body = bodySnippet.isEmpty ? "Tap to open your note." : bodySnippet
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let identifier = "prabuone-note-\(note.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                self.logger.error("Failed to schedule note reminder for \(note.displayTitle): \(error.localizedDescription)")
            } else {
                self.logger.info("Successfully scheduled note reminder for \(note.displayTitle) at \(fireDate)")
            }
        }
    }
    
    /// Cancels the scheduled alert for a quick note.
    public func cancelNoteReminder(for noteId: UUID) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["prabuone-note-\(noteId.uuidString)"])
    }
    
    /// Cancels all pending notifications across the app.
    public func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
