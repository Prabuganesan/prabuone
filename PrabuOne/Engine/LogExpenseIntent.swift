import Foundation
import AppIntents
import SwiftUI

/// Native iOS AppIntent allowing iOS Shortcuts Personal Automations to log incoming bank SMS
/// and push notifications directly in the background without needing user interaction.
public struct LogExpenseFromTextIntent: AppIntent {
    public static var title: LocalizedStringResource = "Log Bank Expense from SMS"
    public static var description = IntentDescription("Parses incoming bank SMS, UPI, or notification text and records the transaction in My One.")
    
    @Parameter(title: "SMS or Notification Text")
    public var text: String
    
    public init() {
        self.text = ""
    }
    
    public init(text: String) {
        self.text = text
    }
    
    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let parsed = BankingTextParser.parse(text) else {
            return .result(dialog: "My One: Text does not appear to contain a recognized bank transaction.")
        }
        
        let expense = parsed.toExpense(source: .smsShortcut)
        LifeStore.shared.addExpense(expense)
        
        let feedback = "Logged \(expense.formattedSignedAmount) to \(expense.merchantOrPayee) (\(expense.category.rawValue))"
        return .result(dialog: "\(feedback)")
    }
}

/// Registers standard iOS Shortcuts for Siri and Shortcuts app
public struct MyOneShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseFromTextIntent(),
            phrases: [
                "Log bank SMS in \(.applicationName)",
                "Track expense in \(.applicationName)"
            ],
            shortTitle: "Log Bank SMS",
            systemImageName: "indianrupeesign.circle.fill"
        )
    }
}

// Backwards-compatible alias
public typealias PrabuOneShortcuts = MyOneShortcuts
