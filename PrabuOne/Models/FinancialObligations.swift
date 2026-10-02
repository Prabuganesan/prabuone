import Foundation

/// Represents a formal loan or EMI obligation (e.g. Home Loan, Car Loan, Personal Loan).
public struct LoanAccount: Identifiable, Codable, Equatable {
    public var id: UUID
    public var loanName: String          // e.g. "Kia Sonet Auto Loan", "SBI Home Loan"
    public var lenderName: String        // e.g. "HDFC Bank", "SBI", "ICICI Bank", "Bajaj Finserv"
    public var accountNumber: String      // Loan Account Number
    public var loanType: String          // Personal Loan, Home Loan, Car Loan, Gold Loan, Education Loan, Business Loan, Others
    public var totalPrincipal: Double    // Original Sanctioned Amount
    public var remainingPrincipal: Double // Current Outstanding Balance
    public var emiAmount: Double         // Monthly EMI Amount
    public var interestRate: Double      // e.g. 8.75%
    public var dueDay: Int               // Day of the month (1-31)
    public var tenureMonths: Int         // e.g. 60
    public var startDate: Date           // Disbursement date
    public var endDate: Date?            // Closure date
    public var emisPaidOverride: Int?    // Optional manual override for EMIs paid
    public var theme: String             // Color accent: midnight, navy, sapphire, emerald, amber, ruby
    public var notes: String?
    
    public init(
        id: UUID = UUID(),
        loanName: String,
        lenderName: String,
        accountNumber: String,
        loanType: String = "Personal Loan",
        totalPrincipal: Double,
        remainingPrincipal: Double,
        emiAmount: Double,
        interestRate: Double = 8.5,
        dueDay: Int = 5,
        tenureMonths: Int = 36,
        startDate: Date = Date(),
        endDate: Date? = nil,
        emisPaidOverride: Int? = nil,
        theme: String = "sapphire",
        notes: String? = nil
    ) {
        self.id = id
        self.loanName = loanName
        self.lenderName = lenderName
        self.accountNumber = accountNumber
        self.loanType = loanType
        self.totalPrincipal = totalPrincipal
        self.remainingPrincipal = remainingPrincipal
        self.emiAmount = emiAmount
        self.interestRate = interestRate
        self.dueDay = dueDay
        self.tenureMonths = tenureMonths
        self.startDate = startDate
        self.endDate = endDate
        self.emisPaidOverride = emisPaidOverride
        self.theme = theme
        self.notes = notes
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, loanName, lenderName, accountNumber, loanType, totalPrincipal, remainingPrincipal, emiAmount, interestRate, dueDay, tenureMonths, startDate, endDate, emisPaidOverride, theme, notes
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        loanName = try container.decodeIfPresent(String.self, forKey: .loanName) ?? ""
        lenderName = try container.decodeIfPresent(String.self, forKey: .lenderName) ?? ""
        accountNumber = try container.decodeIfPresent(String.self, forKey: .accountNumber) ?? ""
        loanType = try container.decodeIfPresent(String.self, forKey: .loanType) ?? "Personal Loan"
        totalPrincipal = try container.decodeIfPresent(Double.self, forKey: .totalPrincipal) ?? 0.0
        remainingPrincipal = try container.decodeIfPresent(Double.self, forKey: .remainingPrincipal) ?? 0.0
        emiAmount = try container.decodeIfPresent(Double.self, forKey: .emiAmount) ?? 0.0
        interestRate = try container.decodeIfPresent(Double.self, forKey: .interestRate) ?? 8.5
        dueDay = try container.decodeIfPresent(Int.self, forKey: .dueDay) ?? 5
        tenureMonths = try container.decodeIfPresent(Int.self, forKey: .tenureMonths) ?? 36
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate) ?? Date()
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        emisPaidOverride = try container.decodeIfPresent(Int.self, forKey: .emisPaidOverride)
        theme = try container.decodeIfPresent(String.self, forKey: .theme) ?? "sapphire"
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
    
    /// Automatic calculation of EMIs paid based on the loan start date and the current date/due day.
    public var calculatedEmisPaid: Int {
        let calendar = Calendar.current
        let today = Date()
        guard startDate <= today else { return 0 }
        
        let startComponents = calendar.dateComponents([.year, .month], from: startDate)
        let currentComponents = calendar.dateComponents([.year, .month], from: today)
        
        guard let startMonthDate = calendar.date(from: startComponents),
              let currentMonthDate = calendar.date(from: currentComponents) else {
            return 0
        }
        
        let monthDiff = calendar.dateComponents([.month], from: startMonthDate, to: currentMonthDate).month ?? 0
        let currentDay = calendar.component(.day, from: today)
        let thisMonthBilled = currentDay >= dueDay ? 1 : 0
        let total = monthDiff + thisMonthBilled
        return min(max(total, 0), tenureMonths)
    }
    
    /// Effective EMIs paid: uses manual override if set, otherwise automatically calculated from start date.
    public var emisPaid: Int {
        if let override = emisPaidOverride {
            return min(max(override, 0), tenureMonths)
        }
        return calculatedEmisPaid
    }
    
    /// Remaining EMIs left to pay.
    public var remainingEmis: Int {
        max(0, tenureMonths - emisPaid)
    }
    
    /// Estimated closure date for this loan based on start date and tenure.
    public var calculatedEndDate: Date {
        if let end = endDate { return end }
        let calendar = Calendar.current
        return calendar.date(byAdding: .month, value: tenureMonths, to: startDate) ?? startDate
    }
    
    /// Cumulative EMI amount paid so far.
    public var totalEmiPaidAmount: Double {
        Double(emisPaid) * emiAmount
    }
    
    /// Remaining EMI obligation amount left to pay.
    public var remainingEmiAmount: Double {
        Double(remainingEmis) * emiAmount
    }
    
    public var paidPrincipal: Double {
        if totalPrincipal > 0 && remainingPrincipal > 0 {
            return max(0, totalPrincipal - remainingPrincipal)
        }
        return totalEmiPaidAmount
    }
    
    public var progressPercentage: Double {
        if tenureMonths > 0 {
            return min(max((Double(emisPaid) / Double(tenureMonths)) * 100.0, 0), 100.0)
        }
        guard totalPrincipal > 0 else { return 0 }
        let ratio = paidPrincipal / totalPrincipal
        return min(max(ratio * 100.0, 0), 100.0)
    }
    
    public var lastFourDigits: String {
        let clean = accountNumber.filter { $0.isNumber }
        if clean.count >= 4 {
            return String(clean.suffix(4))
        }
        return clean.isEmpty ? "••••" : clean
    }
    
    public var maskedAccountNumber: String {
        let clean = accountNumber.filter { $0.isNumber }
        guard clean.count >= 4 else { return "•••• ••••" }
        let last4 = String(clean.suffix(4))
        let prefix = String(repeating: "•", count: max(clean.count - 4, 4))
        return "\(prefix) \(last4)"
    }
    
    public var formattedAccountNumber: String {
        let clean = accountNumber.filter { $0.isNumber }
        guard !clean.isEmpty else { return accountNumber }
        var result = ""
        for (index, char) in clean.enumerated() {
            if index > 0 && index % 4 == 0 {
                result.append(" ")
            }
            result.append(char)
        }
        return result
    }
    
    public var nextDueDate: Date {
        let calendar = Calendar.current
        let today = Date()
        var components = calendar.dateComponents([.year, .month], from: today)
        components.day = dueDay
        
        if let candidate = calendar.date(from: components), candidate >= calendar.startOfDay(for: today) {
            return candidate
        } else {
            components.month = (components.month ?? 1) + 1
            return calendar.date(from: components) ?? today
        }
    }
    
    public var daysUntilDue: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDue = calendar.startOfDay(for: nextDueDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfDue)
        return components.day ?? 0
    }
    
    public var isDueSoon: Bool {
        daysUntilDue <= 7 && daysUntilDue >= 0
    }
}

/// Represents an Insurance Policy (LIC, Term Life, Health, Vehicle, etc.).
public struct InsurancePolicyRecord: Identifiable, Codable, Equatable {
    public var id: UUID
    public var policyName: String        // e.g. "LIC Jeevan Labh", "Star Health Comprehensive", "Kia Sonet Zero Dep"
    public var insurerName: String       // e.g. "Life Insurance Corporation of India (LIC)", "HDFC Life", "Star Health"
    public var policyNumber: String      // Policy / Contract number
    public var policyType: String        // Life Insurance, Term Life, Health / Mediclaim, Vehicle Insurance, Endowment Plan, Pension / Annuity, ULIP, Others
    public var sumAssured: Double        // Coverage Sum
    public var premiumAmount: Double     // Premium amount per cycle
    public var premiumFrequency: String  // Yearly, Half-Yearly, Quarterly, Monthly
    public var nextDueDate: Date         // Next premium due date
    public var maturityDate: Date?       // Policy maturity date
    public var policyHolderName: String  // e.g. "PRABU GANESAN"
    public var theme: String             // Color accent: emerald, sapphire, ruby, amber, midnight, purple
    public var notes: String?
    
    public init(
        id: UUID = UUID(),
        policyName: String,
        insurerName: String,
        policyNumber: String,
        policyType: String = "Life Insurance",
        sumAssured: Double,
        premiumAmount: Double,
        premiumFrequency: String = "Yearly",
        nextDueDate: Date,
        maturityDate: Date? = nil,
        policyHolderName: String = "PRABU GANESAN",
        theme: String = "emerald",
        notes: String? = nil
    ) {
        self.id = id
        self.policyName = policyName
        self.insurerName = insurerName
        self.policyNumber = policyNumber
        self.policyType = policyType
        self.sumAssured = sumAssured
        self.premiumAmount = premiumAmount
        self.premiumFrequency = premiumFrequency
        self.nextDueDate = nextDueDate
        self.maturityDate = maturityDate
        self.policyHolderName = policyHolderName
        self.theme = theme
        self.notes = notes
    }
    
    public var daysUntilDue: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDue = calendar.startOfDay(for: nextDueDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfDue)
        return components.day ?? 0
    }
    
    public var isOverdue: Bool {
        daysUntilDue < 0
    }
    
    public var isDueSoon: Bool {
        daysUntilDue <= 30 && daysUntilDue >= 0
    }
    
    public var formattedPolicyNumber: String {
        policyNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
