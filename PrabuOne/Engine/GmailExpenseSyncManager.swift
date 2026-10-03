import Foundation
import Combine

/// Manager responsible for syncing and importing bank alert emails and statements
/// via Gmail filters or batch email paste.
@MainActor
public final class GmailExpenseSyncManager: ObservableObject {
    public static let shared = GmailExpenseSyncManager()
    
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncDate: Date? = nil
    @Published public var lastSyncCount: Int = 0
    @Published public var syncStatusMessage: String = "Ready to sync bank emails"
    
    /// The optimal Gmail search query for transaction alert emails.
    public static let recommendedGmailSearchQuery = """
    from:(alerts@hdfcbank.net OR alert@icicibank.com OR alerts@sbi.co.in OR no-reply@axisbank.com OR alerts@kotak.com OR auto-message@paytm.com OR transaction@phonepe.com OR alerts@cred.club) AND (debited OR spent OR credited OR "INR" OR "Rs.")
    """
    
    private init() {
        let timestamp = UserDefaults.standard.double(forKey: "prabuone_last_gmail_sync_time")
        if timestamp > 0 {
            self.lastSyncDate = Date(timeIntervalSince1970: timestamp)
        }
    }
    
    /// Parses a batch of email text snippets (separated by newlines or email boundaries).
    public func importRawEmailBatch(text: String, into store: LifeStore) -> (imported: Int, skippedDuplicates: Int) {
        let lines = text.components(separatedBy: "\n---")
        let snippets = lines.isEmpty ? [text] : lines
        
        var imported = 0
        var skipped = 0
        
        for snippet in snippets {
            let clean = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }
            
            if let parsed = BankingTextParser.parse(clean) {
                let expense = parsed.toExpense(source: .gmailSync)
                if store.containsDuplicateExpense(expense) {
                    skipped += 1
                } else {
                    store.addExpense(expense)
                    imported += 1
                }
            }
        }
        
        self.lastSyncDate = Date()
        self.lastSyncCount = imported
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "prabuone_last_gmail_sync_time")
        
        return (imported, skipped)
    }
    
    /// Simulates/Syncs real-world bank alert email feeds (HDFC, SBI, ICICI, Axis, Swiggy, Amazon, Shell).
    /// Used for initial seeding and testing without requiring immediate live Google Cloud OAuth credentials.
    public func syncSimulatedGmailAlerts(into store: LifeStore) -> (imported: Int, skippedDuplicates: Int) {
        let sampleAlerts = [
            "HDFC Bank Alert: Rs. 640.00 debited from A/c **4921 to SWIGGY on 03-OCT-26. UPI Ref: 4278190281. Avl Bal: Rs 48,250.00",
            "Alert: Update on your ICICI Bank Credit Card ending 8124 for INR 2,499.00 spent at AMAZON INDIA on 02-OCT-26. Avl Limit: INR 1,45,000.00",
            "Axis Bank: INR 350.00 debited from A/c no. XX5678 on 02-10-26 towards UBER INDIA. Ref: AXIS882190",
            "Dear SBI User, your A/C 9876 debited by Rs.2,100.00 on 01-OCT-26 transfer to SHELL PETROL BUNK via UPI. Ref 99128301",
            "Kotak Bank: Rs 899.00 spent on your Card ending 3311 at BLINKIT GROCERIES on 01-OCT-26.",
            "HDFC Bank: Salary credited! INR 85,000.00 credited to A/C **4921 by TECH CORP on 30-SEP-26. Avl Bal: INR 1,32,000.00",
            "CRED Alert: Payment of Rs 14,500.00 towards your HDFC Credit Card successful via CRED UPI. Ref: CRD88123"
        ]
        
        var imported = 0
        var skipped = 0
        
        for alert in sampleAlerts {
            if let parsed = BankingTextParser.parse(alert) {
                let expense = parsed.toExpense(source: .gmailSync)
                if store.containsDuplicateExpense(expense) {
                    skipped += 1
                } else {
                    store.addExpense(expense)
                    imported += 1
                }
            }
        }
        
        self.lastSyncDate = Date()
        self.lastSyncCount = imported
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "prabuone_last_gmail_sync_time")
        
        return (imported, skipped)
    }
}
