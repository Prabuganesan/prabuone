import Foundation
import SwiftUI

// MARK: - Transaction Direction
public enum TransactionType: String, Codable, CaseIterable {
    case debit = "Debit"
    case credit = "Credit"
    
    public var sign: String {
        switch self {
        case .debit: return "-"
        case .credit: return "+"
        }
    }
    
    public var color: Color {
        switch self {
        case .debit: return .red
        case .credit: return .green
        }
    }
}

// MARK: - Expense Categories
public enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case foodDining = "Food & Dining"
    case groceries = "Groceries & Supermarket"
    case shopping = "Shopping & Retail"
    case transportFuel = "Fuel & Transport"
    case utilitiesBills = "Bills & Utilities"
    case entertainment = "Entertainment & OTT"
    case healthMedical = "Health & Pharmacy"
    case travel = "Travel & Hotels"
    case investment = "Investments & Stocks"
    case transfer = "Transfers & CC Bill"
    case education = "Education & Books"
    case personal = "Personal & Lifestyle"
    case other = "General / Other"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .foodDining: return "fork.knife"
        case .groceries: return "cart.fill"
        case .shopping: return "bag.fill"
        case .transportFuel: return "fuelpump.fill"
        case .utilitiesBills: return "bolt.fill"
        case .entertainment: return "film.fill"
        case .healthMedical: return "cross.case.fill"
        case .travel: return "airplane"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .transfer: return "arrow.left.arrow.right"
        case .education: return "book.closed.fill"
        case .personal: return "sparkles"
        case .other: return "tag.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .foodDining: return Color.orange
        case .groceries: return Color.green
        case .shopping: return Color.pink
        case .transportFuel: return Color.yellow
        case .utilitiesBills: return Color.blue
        case .entertainment: return Color.purple
        case .healthMedical: return Color.red
        case .travel: return Color.cyan
        case .investment: return Color.emeraldAccent
        case .transfer: return Color.indigo
        case .education: return Color.teal
        case .personal: return Color.mint
        case .other: return Color.secondary
        }
    }
}

// MARK: - Import Source
public enum ExpenseImportSource: String, Codable, CaseIterable {
    case smsShortcut = "SMS Shortcut"
    case gmailSync = "Gmail Sync"
    case clipboardPaste = "Parsed Paste"
    case manual = "Manual Entry"
    
    public var iconName: String {
        switch self {
        case .smsShortcut: return "message.badge.filled.fill"
        case .gmailSync: return "envelope.fill"
        case .clipboardPaste: return "doc.on.clipboard.fill"
        case .manual: return "square.and.pencil"
        }
    }
    
    public var badgeColor: Color {
        switch self {
        case .smsShortcut: return .green
        case .gmailSync: return .red
        case .clipboardPaste: return .blue
        case .manual: return .secondary
        }
    }
}

// MARK: - Expense Transaction Model
public struct ExpenseTransaction: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var amount: Double
    public var type: TransactionType
    public var category: ExpenseCategory
    public var merchantOrPayee: String
    public var accountOrCardLast4: String?
    public var bankOrSource: String?
    public var referenceNumber: String?
    public var transactionDate: Date
    public var rawTextSnippet: String?
    public var importSource: ExpenseImportSource
    public var isReviewed: Bool
    public var notes: String?
    
    public init(
        id: UUID = UUID(),
        amount: Double,
        type: TransactionType = .debit,
        category: ExpenseCategory = .other,
        merchantOrPayee: String,
        accountOrCardLast4: String? = nil,
        bankOrSource: String? = nil,
        referenceNumber: String? = nil,
        transactionDate: Date = Date(),
        rawTextSnippet: String? = nil,
        importSource: ExpenseImportSource = .manual,
        isReviewed: Bool = true,
        notes: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.type = type
        self.category = category
        self.merchantOrPayee = merchantOrPayee.trimmingCharacters(in: .whitespacesAndNewlines)
        self.accountOrCardLast4 = accountOrCardLast4
        self.bankOrSource = bankOrSource
        self.referenceNumber = referenceNumber
        self.transactionDate = transactionDate
        self.rawTextSnippet = rawTextSnippet
        self.importSource = importSource
        self.isReviewed = isReviewed
        self.notes = notes
    }
    
    public var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = (amount.truncatingRemainder(dividingBy: 1) == 0) ? 0 : 2
        return formatter.string(from: NSNumber(value: amount)) ?? "₹\(Int(amount))"
    }
    
    public var formattedSignedAmount: String {
        "\(type.sign)\(formattedAmount)"
    }
    
    public var relativeDateString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(transactionDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today, " + formatter.string(from: transactionDate)
        } else if calendar.isDateInYesterday(transactionDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Yesterday, " + formatter.string(from: transactionDate)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM, h:mm a"
            return formatter.string(from: transactionDate)
        }
    }
    
    public var accountLabel: String {
        var parts: [String] = []
        if let bank = bankOrSource, !bank.isEmpty {
            parts.append(bank)
        }
        if let last4 = accountOrCardLast4, !last4.isEmpty {
            parts.append("••\(last4)")
        }
        return parts.isEmpty ? "Payment" : parts.joined(separator: " ")
    }
}
