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
    case quarterly = "Quarterly"
    case halfYearly = "Half-Yearly"
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
    
    // Rich subscription & recurring service metadata (OTT, AI, Cloud, Memberships)
    public var planTier: String?         // e.g. "Premium 4K", "Family Plan", "VIP Annual"
    public var billingCycle: String?      // e.g. "Monthly", "Quarterly", "Half-Yearly", "Yearly"
    public var paymentMethod: String?    // e.g. "HDFC Regalia Card", "ICICI UPI AutoPay", "Apple ID"
    public var accountEmail: String?     // e.g. "name@example.com" or phone number
    public var sharedWith: String?       // e.g. "4 Screens • Family"
    public var autoRenew: Bool?          // true if recurring e-mandate/auto-debit active
    public var serviceBrand: String?     // e.g. "Netflix", "Prime Video", "Hotstar", "YouTube", "Spotify"
    public var linkedDocumentId: UUID?   // Linked document from Document Vault
    
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
        reminderDaysBefore: [Int] = [7, 3, 1, 0],
        planTier: String? = nil,
        billingCycle: String? = nil,
        paymentMethod: String? = nil,
        accountEmail: String? = nil,
        sharedWith: String? = nil,
        autoRenew: Bool? = nil,
        serviceBrand: String? = nil,
        linkedDocumentId: UUID? = nil
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
        self.planTier = planTier
        self.billingCycle = billingCycle
        self.paymentMethod = paymentMethod
        self.accountEmail = accountEmail
        self.sharedWith = sharedWith
        self.autoRenew = autoRenew
        self.serviceBrand = serviceBrand
        self.linkedDocumentId = linkedDocumentId
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, category, dueDate, amount, repeatFrequency, isCompleted, notes, reminderDaysBefore
        case planTier, billingCycle, paymentMethod, accountEmail, sharedWith, autoRenew, serviceBrand, linkedDocumentId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        category = try container.decodeIfPresent(LifeCategory.self, forKey: .category) ?? .custom
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate) ?? Date()
        amount = try container.decodeIfPresent(Double.self, forKey: .amount)
        repeatFrequency = try container.decodeIfPresent(RepeatFrequency.self, forKey: .repeatFrequency) ?? .never
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        reminderDaysBefore = try container.decodeIfPresent([Int].self, forKey: .reminderDaysBefore) ?? [7, 3, 1, 0]
        planTier = try container.decodeIfPresent(String.self, forKey: .planTier)
        billingCycle = try container.decodeIfPresent(String.self, forKey: .billingCycle)
        paymentMethod = try container.decodeIfPresent(String.self, forKey: .paymentMethod)
        accountEmail = try container.decodeIfPresent(String.self, forKey: .accountEmail)
        sharedWith = try container.decodeIfPresent(String.self, forKey: .sharedWith)
        autoRenew = try container.decodeIfPresent(Bool.self, forKey: .autoRenew)
        serviceBrand = try container.decodeIfPresent(String.self, forKey: .serviceBrand)
        linkedDocumentId = try container.decodeIfPresent(UUID.self, forKey: .linkedDocumentId)
    }
    
    // MARK: - Computed Properties
    
    /// Converts any frequency (e.g. ₹1499/year or ₹699/quarter) to an accurate monthly burn amount.
    public var normalizedMonthlyAmount: Double {
        guard let amount = amount, amount > 0 else { return 0 }
        switch repeatFrequency {
        case .monthly:
            return amount
        case .quarterly:
            return amount / 3.0
        case .halfYearly:
            return amount / 6.0
        case .yearly:
            return amount / 12.0
        case .never:
            // One-time payment: if due in current month, consider it for monthly pulse
            let calendar = Calendar.current
            let isCurrentMonth = calendar.isDate(dueDate, equalTo: Date(), toGranularity: .month)
            return isCurrentMonth ? amount : 0
        }
    }
    
    /// Annual run rate for this commitment.
    public var normalizedAnnualAmount: Double {
        guard let amount = amount, amount > 0 else { return 0 }
        switch repeatFrequency {
        case .monthly:
            return amount * 12.0
        case .quarterly:
            return amount * 4.0
        case .halfYearly:
            return amount * 2.0
        case .yearly:
            return amount
        case .never:
            return amount
        }
    }
    
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
