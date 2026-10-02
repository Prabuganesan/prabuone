import Foundation

/// Specific details for a credit or debit card account stored securely in the digital wallet.
public struct CreditCardAccount: Identifiable, Codable, Equatable {
    public var id: UUID
    public var bankName: String          // e.g. HDFC Bank, ICICI Bank, SBI, Axis
    public var cardName: String          // e.g. Regalia Gold, Amazon Pay, Platinum Debit
    public var cardNumber: String        // Full card number (16 digits)
    public var cardHolderName: String    // e.g. PRABU GANESAN
    public var expiryDate: String        // MM/YY (e.g. "08/29")
    public var cvv: String               // e.g. "123"
    public var creditLimit: Double       // e.g. 500000 (0 for debit card or if not entered)
    public var statementDay: Int?        // e.g. 15th
    public var dueDay: Int?              // e.g. 5th
    public var cardNetwork: String       // Visa, Mastercard, RuPay, Amex
    public var cardTheme: String         // midnight, obsidian, emerald, titanium, purple, roseGold
    public var cardCategory: String      // "Credit" or "Debit"
    
    public init(
        id: UUID = UUID(),
        bankName: String,
        cardName: String,
        cardNumber: String,
        cardHolderName: String = "PRABU GANESAN",
        expiryDate: String = "",
        cvv: String = "",
        creditLimit: Double = 0,
        statementDay: Int? = nil,
        dueDay: Int? = nil,
        cardNetwork: String = "Visa",
        cardTheme: String = "midnight",
        cardCategory: String = "Credit"
    ) {
        self.id = id
        self.bankName = bankName
        self.cardName = cardName
        self.cardNumber = cardNumber
        self.cardHolderName = cardHolderName
        self.expiryDate = expiryDate
        self.cvv = cvv
        self.creditLimit = creditLimit
        self.statementDay = statementDay
        self.dueDay = dueDay
        self.cardNetwork = cardNetwork
        self.cardTheme = cardTheme
        self.cardCategory = cardCategory
    }
    
    public var isDebit: Bool {
        cardCategory.lowercased() == "debit"
    }
    
    public var lastFourDigits: String {
        let clean = cardNumber.filter { $0.isNumber }
        if clean.count >= 4 {
            return String(clean.suffix(4))
        }
        return clean.isEmpty ? "••••" : clean
    }
    
    public var formattedCardNumber: String {
        let clean = cardNumber.filter { $0.isNumber }
        guard !clean.isEmpty else { return "•••• •••• •••• ••••" }
        var result = ""
        for (index, char) in clean.enumerated() {
            if index > 0 && index % 4 == 0 {
                result.append(" ")
            }
            result.append(char)
        }
        return result
    }
    
    public var maskedCardNumber: String {
        let clean = cardNumber.filter { $0.isNumber }
        guard clean.count >= 4 else { return "•••• •••• •••• ••••" }
        let last4 = String(clean.suffix(4))
        return "•••• •••• •••• \(last4)"
    }
    
    public var maskedCVV: String {
        String(repeating: "•", count: max(cvv.count, 3))
    }
    
    public static func detectNetwork(from number: String) -> String {
        let clean = number.filter { $0.isNumber }
        if clean.hasPrefix("4") {
            return "Visa"
        } else if clean.hasPrefix("51") || clean.hasPrefix("52") || clean.hasPrefix("53") || clean.hasPrefix("54") || clean.hasPrefix("55") || clean.hasPrefix("2") {
            return "Mastercard"
        } else if clean.hasPrefix("60") || clean.hasPrefix("65") || clean.hasPrefix("81") || clean.hasPrefix("82") || clean.hasPrefix("508") {
            return "RuPay"
        } else if clean.hasPrefix("34") || clean.hasPrefix("37") {
            return "Amex"
        }
        return "Visa"
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, bankName, cardName, cardNumber, cardHolderName, expiryDate, cvv, creditLimit, statementDay, dueDay, cardNetwork, cardTheme, cardCategory
        case legacyLastFourDigits = "lastFourDigits"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(bankName, forKey: .bankName)
        try container.encode(cardName, forKey: .cardName)
        try container.encode(cardNumber, forKey: .cardNumber)
        try container.encode(cardHolderName, forKey: .cardHolderName)
        try container.encode(expiryDate, forKey: .expiryDate)
        try container.encode(cvv, forKey: .cvv)
        try container.encode(creditLimit, forKey: .creditLimit)
        try container.encodeIfPresent(statementDay, forKey: .statementDay)
        try container.encodeIfPresent(dueDay, forKey: .dueDay)
        try container.encode(cardNetwork, forKey: .cardNetwork)
        try container.encode(cardTheme, forKey: .cardTheme)
        try container.encode(cardCategory, forKey: .cardCategory)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        bankName = try container.decode(String.self, forKey: .bankName)
        cardName = try container.decode(String.self, forKey: .cardName)
        
        let fullNumber = try container.decodeIfPresent(String.self, forKey: .cardNumber)
        let oldLast4 = try container.decodeIfPresent(String.self, forKey: .legacyLastFourDigits)
        cardNumber = fullNumber ?? oldLast4 ?? ""
        
        cardHolderName = try container.decodeIfPresent(String.self, forKey: .cardHolderName) ?? "PRABU GANESAN"
        expiryDate = try container.decodeIfPresent(String.self, forKey: .expiryDate) ?? ""
        cvv = try container.decodeIfPresent(String.self, forKey: .cvv) ?? ""
        creditLimit = try container.decodeIfPresent(Double.self, forKey: .creditLimit) ?? 0
        statementDay = try container.decodeIfPresent(Int.self, forKey: .statementDay)
        dueDay = try container.decodeIfPresent(Int.self, forKey: .dueDay)
        cardNetwork = try container.decodeIfPresent(String.self, forKey: .cardNetwork) ?? "Visa"
        cardTheme = try container.decodeIfPresent(String.self, forKey: .cardTheme) ?? "midnight"
        cardCategory = try container.decodeIfPresent(String.self, forKey: .cardCategory) ?? "Credit"
    }
}

/// Secure Bank Account Details stored in the digital financial vault.
public struct BankAccount: Identifiable, Codable, Equatable {
    public var id: UUID
    public var bankName: String          // e.g. HDFC Bank, SBI, ICICI Bank, Axis Bank
    public var accountHolderName: String // e.g. PRABU GANESAN
    public var accountNumber: String     // Full Account Number (e.g. "50100432198765")
    public var ifscCode: String          // e.g. "HDFC0000060"
    public var accountType: String       // "Savings", "Current", "Salary"
    public var upiId: String             // e.g. "prabu@okhdfcbank"
    public var branchName: String        // e.g. "Anna Nagar Branch"
    public var accountTheme: String      // "blue", "green", "purple", "slate", "amber"
    
    public init(
        id: UUID = UUID(),
        bankName: String,
        accountHolderName: String = "PRABU GANESAN",
        accountNumber: String,
        ifscCode: String,
        accountType: String = "Savings",
        upiId: String = "",
        branchName: String = "",
        accountTheme: String = "blue"
    ) {
        self.id = id
        self.bankName = bankName
        self.accountHolderName = accountHolderName
        self.accountNumber = accountNumber
        self.ifscCode = ifscCode.uppercased()
        self.accountType = accountType
        self.upiId = upiId
        self.branchName = branchName
        self.accountTheme = accountTheme
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
}
