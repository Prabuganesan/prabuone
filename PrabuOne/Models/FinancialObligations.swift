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
        self.theme = theme
        self.notes = notes
    }
    
    public var paidPrincipal: Double {
        max(0, totalPrincipal - remainingPrincipal)
    }
    
    public var progressPercentage: Double {
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
