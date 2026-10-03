import Foundation

/// Robust heuristic and regular-expression engine for parsing bank SMS alerts,
/// UPI notifications, and transactional email snippets.
public struct ParsedBankingAlert {
    public var amount: Double
    public var type: TransactionType
    public var merchantOrPayee: String
    public var accountOrCardLast4: String?
    public var bankOrSource: String?
    public var referenceNumber: String?
    public var transactionDate: Date
    public var category: ExpenseCategory
    public var rawText: String
    public var isConfident: Bool
    
    public func toExpense(source: ExpenseImportSource = .smsShortcut) -> ExpenseTransaction {
        ExpenseTransaction(
            amount: amount,
            type: type,
            category: category,
            merchantOrPayee: merchantOrPayee,
            accountOrCardLast4: accountOrCardLast4,
            bankOrSource: bankOrSource,
            referenceNumber: referenceNumber,
            transactionDate: transactionDate,
            rawTextSnippet: rawText,
            importSource: source,
            isReviewed: isConfident
        )
    }
}

public struct BankingTextParser {
    
    /// Parses any input raw text (SMS, push notification body, or email text).
    /// Returns a `ParsedBankingAlert` if a valid financial transaction is recognized, or `nil` if irrelevant (e.g., OTP or promo).
    public static func parse(_ text: String) -> ParsedBankingAlert? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let lower = trimmed.lowercased()
        
        // 1. Guard against OTP / Authentication messages without transaction
        if isOtpMessage(lower) && !lower.contains("debited") && !lower.contains("spent") && !lower.contains("credited") {
            return nil
        }
        
        // 2. Determine Transaction Type (Debit vs Credit)
        guard let type = detectTransactionType(lower) else {
            return nil
        }
        
        // 3. Extract Amount
        guard let amount = extractAmount(from: trimmed) else {
            return nil
        }
        
        // 4. Extract Account / Card Last 4 Digits
        let accountOrCard = extractAccountOrCard(from: trimmed)
        
        // 5. Extract Bank or Payment Provider
        let bank = extractBankOrProvider(from: trimmed)
        
        // 6. Extract Merchant / Payee
        let merchant = extractMerchantOrPayee(from: trimmed, lower: lower) ?? (type == .credit ? "Received Funds" : "General Expense")
        
        // 7. Extract Reference / UTR Number
        let refNumber = extractReferenceNumber(from: trimmed)
        
        // 8. Extract or Infer Date
        let date = extractDate(from: trimmed) ?? Date()
        
        // 9. Predict Expense Category
        let category = predictCategory(merchant: merchant, rawText: lower)
        
        let isConfident = (amount > 0 && merchant != "General Expense")
        
        return ParsedBankingAlert(
            amount: amount,
            type: type,
            merchantOrPayee: merchant,
            accountOrCardLast4: accountOrCard,
            bankOrSource: bank,
            referenceNumber: refNumber,
            transactionDate: date,
            category: category,
            rawText: trimmed,
            isConfident: isConfident
        )
    }
    
    // MARK: - Sub-Parsers
    
    private static func isOtpMessage(_ lower: String) -> Bool {
        if lower.contains("is your otp") ||
           lower.contains("one time password") ||
           lower.contains("do not share this otp") ||
           lower.contains("secret otp") {
            return true
        }
        return false
    }
    
    private static func detectTransactionType(_ lower: String) -> TransactionType? {
        // High priority debit triggers
        let debitKeywords = ["debited", "spent", "paid", "transfer to", "transferred to", "withdrawn", "purchase of", "sent to", "deducted"]
        // High priority credit triggers
        let creditKeywords = ["credited", "received", "refund", "deposited", "cashback", "added to your"]
        
        for keyword in debitKeywords {
            if lower.contains(keyword) {
                return .debit
            }
        }
        
        for keyword in creditKeywords {
            if lower.contains(keyword) {
                return .credit
            }
        }
        
        // Fallback for UPI phrasing: "You paid ₹..." or "Paid to ..."
        if lower.contains("paid ") || lower.contains("payment to") || lower.contains("sent ") {
            return .debit
        }
        
        return nil
    }
    
    private static func extractAmount(from text: String) -> Double? {
        // Regex patterns for Indian & International currency formats:
        // Examples: Rs. 1,450.00, Rs 500, INR 12,000, ₹ 340.50, INR: 999.00
        let patterns = [
            #"(?:rs\.?|inr|₹)\s*[:\-]?\s*([0-9]+(?:,[0-9]+)*(?:\.[0-9]{1,2})?)"#,
            #"(?:amount|amt|debited|spent|paid|credited|for)\s*(?:of|is)?\s*(?:rs\.?|inr|₹)?\s*[:\-]?\s*([0-9]+(?:,[0-9]+)*(?:\.[0-9]{1,2})?)"#,
            #"([0-9]+(?:,[0-9]+)*(?:\.[0-9]{1,2})?)\s*(?:rs\.?|inr|₹)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range),
                   let amountRange = Range(match.range(at: 1), in: text) {
                    let rawAmountStr = String(text[amountRange]).replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
                    if let value = Double(rawAmountStr), value > 0 {
                        return value
                    }
                }
            }
        }
        return nil
    }
    
    private static func extractAccountOrCard(from text: String) -> String? {
        let patterns = [
            #"(?:a\/c|acct|account|card|ending\s+in|ending|xx)\s*(?:no\.?)?\s*[*xX\-]*([0-9]{3,4})"#,
            #"\*\*([0-9]{4})"#,
            #"card\s+([0-9]{4})"#,
            #"ending\s+([0-9]{4})"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range),
                   let numRange = Range(match.range(at: 1), in: text) {
                    return String(text[numRange])
                }
            }
        }
        return nil
    }
    
    private static func extractBankOrProvider(from text: String) -> String? {
        let lower = text.lowercased()
        
        let bankMap: [(String, String)] = [
            ("hdfc", "HDFC Bank"),
            ("sbi", "SBI"),
            ("state bank", "SBI"),
            ("icici", "ICICI Bank"),
            ("axis", "Axis Bank"),
            ("kotak", "Kotak Bank"),
            ("indusind", "IndusInd Bank"),
            ("idfc", "IDFC FIRST Bank"),
            ("pnb", "PNB"),
            ("punjab national", "PNB"),
            ("canara", "Canara Bank"),
            ("bob", "Bank of Baroda"),
            ("baroda", "Bank of Baroda"),
            ("yes bank", "Yes Bank"),
            ("federal bank", "Federal Bank"),
            ("standard chartered", "Standard Chartered"),
            ("amex", "American Express"),
            ("american express", "American Express"),
            ("citi", "Citibank"),
            ("cred", "CRED"),
            ("google pay", "Google Pay"),
            ("gpay", "Google Pay"),
            ("phonepe", "PhonePe"),
            ("paytm", "Paytm"),
            ("amazon pay", "Amazon Pay")
        ]
        
        for (keyword, name) in bankMap {
            if lower.contains(keyword) {
                return name
            }
        }
        return nil
    }
    
    private static func extractMerchantOrPayee(from text: String, lower: String) -> String? {
        // 1. Direct regex after known prepositions: "to", "at", "towards", "info/", "transfer to", "vpa/"
        let patterns = [
            #"(?:spent\s+at|paid\s+to|transfer\s+to|transferred\s+to|sent\s+to|towards)\s+([A-Za-z0-9\s\.\-_&@]+?)(?:\s+on|\s+ref|\s+utr|\s+avail|\s+avl|\s+bal|\s+balance|\s+date|\.|\n|$)"#,
            #"(?:to\s+vpa|vpa|upi\/vpa\/|upi:)\s*([A-Za-z0-9\.\-_@]+)"#,
            #"(?:info\/)\s*([A-Za-z0-9\s\.\-_]+)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range),
                   let mRange = Range(match.range(at: 1), in: text) {
                    var captured = String(text[mRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Clean UPI handles (e.g. "swiggy@icici" -> "Swiggy", "zomatoupi@hdfcbank" -> "Zomato")
                    if captured.contains("@") {
                        let handlePrefix = captured.components(separatedBy: "@").first ?? captured
                        captured = handlePrefix.replacingOccurrences(of: "upi", with: "", options: .caseInsensitive)
                    }
                    
                    captured = captured.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
                    if captured.count >= 2 && !captured.lowercased().hasPrefix("ref") {
                        return cleanMerchantName(captured)
                    }
                }
            }
        }
        
        // 2. Known brand keyword matchers in raw text
        let knownBrands = [
            "swiggy", "zomato", "blinkit", "zepto", "instamart", "amazon", "flipkart", "myntra", "ajio",
            "uber", "ola", "rapido", "shell", "hpcl", "bpcl", "iocl", "netflix", "spotify", "hotstar",
            "youtube", "apple.com", "apple services", "google", "airtel", "jio", "bescom", "tneb",
            "makemytrip", "irctc", "indigo", "zerodha", "groww", "tata 1mg", "apollo pharmacy", "mcdonalds",
            "starbucks", "dominos", "pizza hut", "reliance retail", "croma", "dmart"
        ]
        
        for brand in knownBrands {
            if lower.contains(brand) {
                return cleanMerchantName(brand)
            }
        }
        
        return nil
    }
    
    private static func cleanMerchantName(_ raw: String) -> String {
        let cleaned = raw.replacingOccurrences(of: "_", with: " ")
                         .replacingOccurrences(of: "-", with: " ")
                         .replacingOccurrences(of: "  ", with: " ")
                         .trimmingCharacters(in: .whitespaces)
        return cleaned.capitalized
    }
    
    private static func extractReferenceNumber(from text: String) -> String? {
        let patterns = [
            #"(?:ref(?:\s*no\.?)?|utr(?:\s*no\.?)?|txn(?:\s*id)?)\s*[:\-]?\s*([A-Za-z0-9]{6,16})"#,
            #"upi(?:\s*ref)?\s*[:\-]?\s*([0-9]{8,14})"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range),
                   let refRange = Range(match.range(at: 1), in: text) {
                    return String(text[refRange])
                }
            }
        }
        return nil
    }
    
    private static func extractDate(from text: String) -> Date? {
        // Matches "03-OCT-26", "03-10-26", "03/10/2026", "03Oct26"
        let patterns: [(String, String)] = [
            (#"([0-9]{1,2}-[A-Za-z]{3}-[0-9]{2,4})"#, "dd-MMM-yy"),
            (#"([0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4})"#, "dd-MM-yy"),
            (#"([0-9]{1,2}\/[0-9]{1,2}\/[0-9]{2,4})"#, "dd/MM/yy"),
            (#"([0-9]{1,2}[A-Za-z]{3}[0-9]{2,4})"#, "ddMMMyy")
        ]
        
        for (pattern, dateFormat) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range),
                   let dateRange = Range(match.range(at: 1), in: text) {
                    let dateStr = String(text[dateRange])
                    let formatter = DateFormatter()
                    formatter.dateFormat = dateFormat
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    if let parsed = formatter.date(from: dateStr) {
                        return parsed
                    }
                }
            }
        }
        return nil
    }
    
    public static func predictCategory(merchant: String, rawText: String) -> ExpenseCategory {
        let combined = "\(merchant) \(rawText)".lowercased()
        
        if combined.contains("swiggy") || combined.contains("zomato") || combined.contains("restaurant") ||
           combined.contains("cafe") || combined.contains("coffee") || combined.contains("mcdonald") ||
           combined.contains("starbucks") || combined.contains("pizza") || combined.contains("burger") ||
           combined.contains("dining") || combined.contains("chai") || combined.contains("tea") ||
           combined.contains("bakery") || combined.contains("bar") || combined.contains("pub") {
            return .foodDining
        }
        
        if combined.contains("blinkit") || combined.contains("zepto") || combined.contains("instamart") ||
           combined.contains("bigbasket") || combined.contains("bbdaily") || combined.contains("dmart") ||
           combined.contains("supermarket") || combined.contains("grocery") || combined.contains("kirana") ||
           combined.contains("vegetables") || combined.contains("fruits") {
            return .groceries
        }
        
        if combined.contains("petrol") || combined.contains("fuel") || combined.contains("shell") ||
           combined.contains("hpcl") || combined.contains("bpcl") || combined.contains("iocl") ||
           combined.contains("uber") || combined.contains("ola") || combined.contains("rapido") ||
           combined.contains("metro") || combined.contains("parking") || combined.contains("toll") ||
           combined.contains("fastag") {
            return .transportFuel
        }
        
        if combined.contains("amazon") || combined.contains("flipkart") || combined.contains("myntra") ||
           combined.contains("ajio") || combined.contains("zara") || combined.contains("h&m") ||
           combined.contains("croma") || combined.contains("reliance retail") || combined.contains("retail") ||
           combined.contains("shopping") || combined.contains("store") || combined.contains("apple store") {
            return .shopping
        }
        
        if combined.contains("electricity") || combined.contains("bescom") || combined.contains("tneb") ||
           combined.contains("airtel") || combined.contains("jio") || combined.contains("vodafone") ||
           combined.contains("vi ") || combined.contains("broadband") || combined.contains("water board") ||
           combined.contains("gas bill") || combined.contains("utility") || combined.contains("billdesk") {
            return .utilitiesBills
        }
        
        if combined.contains("netflix") || combined.contains("spotify") || combined.contains("hotstar") ||
           combined.contains("prime video") || combined.contains("bookmyshow") || combined.contains("pvr") ||
           combined.contains("inox") || combined.contains("cinema") || combined.contains("youtube") {
            return .entertainment
        }
        
        if combined.contains("pharmacy") || combined.contains("apollo") || combined.contains("1mg") ||
           combined.contains("pharmeasy") || combined.contains("hospital") || combined.contains("clinic") ||
           combined.contains("medplus") || combined.contains("diagnostic") || combined.contains("dr.") {
            return .healthMedical
        }
        
        if combined.contains("irctc") || combined.contains("makemytrip") || combined.contains("indigo") ||
           combined.contains("air india") || combined.contains("flight") || combined.contains("hotel") ||
           combined.contains("airbnb") || combined.contains("goibibo") || combined.contains("railway") {
            return .travel
        }
        
        if combined.contains("zerodha") || combined.contains("groww") || combined.contains("kuvera") ||
           combined.contains("mutual fund") || combined.contains("sip") || combined.contains("nse") ||
           combined.contains("bse") || combined.contains("stock") {
            return .investment
        }
        
        if combined.contains("credit card payment") || combined.contains("cred") ||
           combined.contains("transfer to a/c") || combined.contains("neft") || combined.contains("rtgs") ||
           combined.contains("imps") {
            return .transfer
        }
        
        return .other
    }
}
