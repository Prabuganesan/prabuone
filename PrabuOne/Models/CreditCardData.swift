import Foundation

/// Specific details for a credit card account.
public struct CreditCardAccount: Identifiable, Codable, Equatable {
    public var id: UUID
    public var bankName: String      // e.g. HDFC Bank
    public var cardName: String      // e.g. Regalia Gold
    public var lastFourDigits: String // e.g. 4821
    public var creditLimit: Double   // e.g. 500000
    public var outstandingAmount: Double // e.g. 42350
    public var statementDay: Int     // e.g. 15 (15th of every month)
    public var dueDay: Int           // e.g. 5 (5th of following month)
    public var isPaidThisMonth: Bool
    public var rewardPoints: Int
    public var cardNetwork: String   // Visa, Mastercard, RuPay
    
    public init(
        id: UUID = UUID(),
        bankName: String,
        cardName: String,
        lastFourDigits: String,
        creditLimit: Double,
        outstandingAmount: Double,
        statementDay: Int,
        dueDay: Int,
        isPaidThisMonth: Bool = false,
        rewardPoints: Int = 0,
        cardNetwork: String = "Visa"
    ) {
        self.id = id
        self.bankName = bankName
        self.cardName = cardName
        self.lastFourDigits = lastFourDigits
        self.creditLimit = creditLimit
        self.outstandingAmount = outstandingAmount
        self.statementDay = statementDay
        self.dueDay = dueDay
        self.isPaidThisMonth = isPaidThisMonth
        self.rewardPoints = rewardPoints
        self.cardNetwork = cardNetwork
    }
    
    public var availableLimit: Double {
        max(0, creditLimit - outstandingAmount)
    }
    
    public var utilizationPercentage: Double {
        guard creditLimit > 0 else { return 0 }
        return (outstandingAmount / creditLimit) * 100
    }
}
