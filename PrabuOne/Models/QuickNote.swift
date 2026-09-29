import Foundation

/// Fast-capture sudden thought, scratchpad, or critical memo.
public struct QuickNote: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var content: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isPinned: Bool
    public var colorTag: String // e.g. "yellow", "blue", "green", "purple", "rose"
    public var reminderDate: Date?
    public var isReminderCompleted: Bool
    
    public var hasReminder: Bool {
        reminderDate != nil
    }
    
    public var isReminderActive: Bool {
        guard reminderDate != nil else { return false }
        return !isReminderCompleted
    }
    
    public var isReminderOverdue: Bool {
        guard let reminder = reminderDate, !isReminderCompleted else { return false }
        return reminder < Date()
    }
    
    public var formattedReminder: String? {
        guard let reminder = reminderDate else { return nil }
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = timeFormatter.string(from: reminder)
        
        if calendar.isDateInToday(reminder) {
            return "Today, \(timeString)"
        } else if calendar.isDateInTomorrow(reminder) {
            return "Tomorrow, \(timeString)"
        } else if calendar.isDateInYesterday(reminder) {
            return "Yesterday, \(timeString)"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "d MMM, h:mm a"
            return dateFormatter.string(from: reminder)
        }
    }
    
    public init(
        id: UUID = UUID(),
        title: String = "",
        content: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPinned: Bool = false,
        colorTag: String = "yellow",
        reminderDate: Date? = nil,
        isReminderCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.colorTag = colorTag
        self.reminderDate = reminderDate
        self.isReminderCompleted = isReminderCompleted
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, title, content, createdAt, updatedAt, isPinned, colorTag, reminderDate, isReminderCompleted
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        colorTag = try container.decodeIfPresent(String.self, forKey: .colorTag) ?? "yellow"
        reminderDate = try container.decodeIfPresent(Date.self, forKey: .reminderDate)
        isReminderCompleted = try container.decodeIfPresent(Bool.self, forKey: .isReminderCompleted) ?? false
    }
    
    public var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }
        let firstLine = content.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return firstLine.isEmpty ? "Quick Note" : firstLine
    }
    
    public var previewSnippet: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let lines = content.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if lines.count > 1 {
            return lines.dropFirst().joined(separator: " ")
        }
        return ""
    }
}
