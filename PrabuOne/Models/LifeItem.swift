import Foundation

/// Core categories across the personal life OS.
public enum LifeCategory: String, Codable, CaseIterable, Identifiable {
    case creditCard = "Credit Card"
    case subscription = "Subscription"
    case mobileBill = "Mobile & Bill"
    case vehicle = "Vehicle"
    case birthday = "Birthday & Life"
    case document = "Document Vault"
    case asset = "Asset & Home"
    case loan = "Loan & EMI"
    case insurance = "LIC & Insurance"
    case custom = "Personal"
    
    public var id: String { rawValue }
    public var displayName: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .creditCard: return "creditcard.fill"
        case .subscription: return "arrow.triangle.2.circlepath.circle.fill"
        case .mobileBill: return "iphone.gen3"
        case .vehicle: return "car.side.fill"
        case .birthday: return "gift.fill"
        case .document: return "doc.text.fill"
        case .asset: return "house.fill"
        case .loan: return "building.columns.fill"
        case .insurance: return "shield.lefthalf.filled"
        case .custom: return "star.fill"
        }
    }
}

/// Frequency for recurring life events.
public enum RepeatFrequency: String, Codable, CaseIterable, Identifiable {
    case never = "One Time"
    case monthly = "Monthly"
    case yearly = "Yearly"
    
    public var id: String { rawValue }
}

/// Urgency status calculated relative to current date.
public enum UrgencyLevel: Comparable {
    case overdue
    case today
    case in3Days
    case in7Days
    case upcoming
    
    public var badgeText: String {
        switch self {
        case .overdue: return "OVERDUE"
        case .today: return "DUE TODAY"
        case .in3Days: return "DUE SOON"
        case .in7Days: return "THIS WEEK"
        case .upcoming: return "UPCOMING"
        }
    }
}

/// Universal Life Item representing any commitment, renewal, birthday, or vehicle event.
public struct LifeItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var subtitle: String
    public var category: LifeCategory
    public var dueDate: Date
    public var amount: Double?
    public var repeatFrequency: RepeatFrequency
    public var isCompleted: Bool
    public var notes: String?
    public var reminderDaysBefore: [Int] // e.g. [7, 3, 1, 0]
    
    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String = "",
        category: LifeCategory,
        dueDate: Date,
        amount: Double? = nil,
        repeatFrequency: RepeatFrequency = .never,
        isCompleted: Bool = false,
        notes: String? = nil,
        reminderDaysBefore: [Int] = [7, 3, 1, 0]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.dueDate = dueDate
        self.amount = amount
        self.repeatFrequency = repeatFrequency
        self.isCompleted = isCompleted
        self.notes = notes
        self.reminderDaysBefore = reminderDaysBefore
    }
    
    // MARK: - Computed Properties
    
    public var daysRemaining: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDue = calendar.startOfDay(for: dueDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfDue)
        return components.day ?? 0
    }
    
    public var urgency: UrgencyLevel {
        let days = daysRemaining
        if days < 0 { return .overdue }
        if days == 0 { return .today }
        if days <= 3 { return .in3Days }
        if days <= 7 { return .in7Days }
        return .upcoming
    }
    
    public var formattedAmount: String? {
        guard let amount = amount else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount))
    }
    
    public var formattedDueDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: dueDate)
    }
    
    public var daysRemainingText: String {
        let days = daysRemaining
        if days < 0 { return "\(abs(days))d overdue" }
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "in \(days) days"
    }
}
