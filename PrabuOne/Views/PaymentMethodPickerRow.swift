import SwiftUI

/// Universal Payment Method & Auto-Debit Instrument Selector.
/// Allows selecting from saved Credit Cards, Debit Cards, Bank Accounts, UPI IDs, or standard e-mandates.
public struct PaymentMethodPickerRow: View {
    let label: String
    @Binding var selectedMethod: String
    @ObservedObject var store: LifeStore
    
    @State private var showingSheet = false
    
    public init(
        label: String = "Payment Method",
        title: String? = nil,
        selectedMethod: Binding<String>,
        store: LifeStore
    ) {
        self.label = title ?? label
        self._selectedMethod = selectedMethod
        self.store = store
    }
    
    public init(
        title: String,
        selectedMethod: Binding<String>,
        store: LifeStore
    ) {
        self.label = title
        self._selectedMethod = selectedMethod
        self.store = store
    }
    
    private var iconName: String {
        let lower = selectedMethod.lowercased()
        if lower.contains("card") || lower.contains("visa") || lower.contains("mastercard") || lower.contains("rupay") || lower.contains("amex") {
            return "creditcard.fill"
        } else if lower.contains("bank") || lower.contains("a/c") || lower.contains("account") || lower.contains("salary") {
            return "building.columns.fill"
        } else if lower.contains("upi") || lower.contains("@") {
            return "arrow.triangle.2.circlepath.circle.fill"
        } else if lower.contains("cash") {
            return "banknote.fill"
        } else {
            return "indianrupeesign.circle.fill"
        }
    }
    
    public var body: some View {
        Button(action: {
            HapticManager.selection()
            showingSheet = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    if selectedMethod.isEmpty {
                        Text("Choose Card, Bank, or UPI")
                            .font(.system(size: 15))
                            .foregroundColor(.blue)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: iconName)
                                .font(.system(size: 13))
                                .foregroundColor(.blue)
                            Text(selectedMethod)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSheet) {
            PaymentInstrumentSelectorSheet(
                selectedMethod: $selectedMethod,
                store: store
            )
        }
    }
}

/// Modal selector sheet presenting all saved financial instruments for 1-tap auto-debit selection.
public struct PaymentInstrumentSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedMethod: String
    @ObservedObject var store: LifeStore
    
    @State private var customText = ""
    @State private var showingCustomField = false
    
    private var creditCards: [CreditCardAccount] {
        store.creditCards.filter { !$0.isDebit }
    }
    
    private var debitCards: [CreditCardAccount] {
        store.creditCards.filter { $0.isDebit }
    }
    
    private var uniqueUpiIds: [String] {
        var ids: [String] = []
        for acc in store.bankAccounts {
            let upi = acc.upiId.trimmingCharacters(in: .whitespaces)
            if !upi.isEmpty && !ids.contains(upi) {
                ids.append(upi)
            }
        }
        return ids
    }
    
    private func bankSubtitle(for acc: BankAccount) -> String {
        if acc.ifscCode.isEmpty {
            return "A/C •••• \(acc.lastFourDigits)"
        } else {
            return "A/C •••• \(acc.lastFourDigits) • \(acc.ifscCode)"
        }
    }
    
    public var body: some View {
        NavigationStack {
            List {
                // MARK: - Saved Credit Cards
                if !creditCards.isEmpty {
                    Section {
                        ForEach(creditCards) { card in
                            instrumentRow(
                                title: "\(card.bankName) \(card.cardName)",
                                subtitle: "\(card.cardNetwork) •••• \(card.lastFourDigits)",
                                icon: "creditcard.fill",
                                iconColor: .blue,
                                value: "\(card.bankName) \(card.cardName) (•••• \(card.lastFourDigits))"
                            )
                        }
                    } header: {
                        Label("Saved Credit Cards", systemImage: "creditcard.fill")
                    }
                }
                
                // MARK: - Saved Debit Cards
                if !debitCards.isEmpty {
                    Section {
                        ForEach(debitCards) { card in
                            instrumentRow(
                                title: "\(card.bankName) Debit Card",
                                subtitle: "\(card.cardNetwork) •••• \(card.lastFourDigits)",
                                icon: "creditcard.and.123",
                                iconColor: .teal,
                                value: "\(card.bankName) Debit (•••• \(card.lastFourDigits))"
                            )
                        }
                    } header: {
                        Label("Saved Debit Cards", systemImage: "creditcard.and.123")
                    }
                }
                
                // MARK: - Saved Bank Accounts
                if !store.bankAccounts.isEmpty {
                    Section {
                        ForEach(store.bankAccounts) { acc in
                            instrumentRow(
                                title: "\(acc.bankName) - \(acc.accountType)",
                                subtitle: bankSubtitle(for: acc),
                                icon: "building.columns.fill",
                                iconColor: .indigo,
                                value: "\(acc.bankName) \(acc.accountType) (•••• \(acc.lastFourDigits))"
                            )
                        }
                    } header: {
                        Label("Saved Bank Accounts (Auto-Debit)", systemImage: "building.columns.fill")
                    }
                }
                
                // MARK: - Saved UPI IDs
                if !uniqueUpiIds.isEmpty {
                    Section {
                        ForEach(uniqueUpiIds, id: \.self) { upi in
                            instrumentRow(
                                title: upi,
                                subtitle: "UPI AutoPay / e-Mandate",
                                icon: "arrow.triangle.2.circlepath.circle.fill",
                                iconColor: .green,
                                value: "UPI (\(upi))"
                            )
                        }
                    } header: {
                        Label("Saved UPI IDs", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                    }
                }
                
                // MARK: - Standard Payment Mandates
                Section {
                    instrumentRow(
                        title: "UPI AutoPay",
                        subtitle: "Recurring mandate via Google Pay, PhonePe, Paytm",
                        icon: "bolt.horizontal.fill",
                        iconColor: .purple,
                        value: "UPI AutoPay"
                    )
                    instrumentRow(
                        title: "Net Banking Standing Instruction (SI)",
                        subtitle: "Direct bank automatic recurring transfer",
                        icon: "arrow.triangle.swap",
                        iconColor: .orange,
                        value: "Net Banking SI"
                    )
                    instrumentRow(
                        title: "NACH / ECS Electronic Mandate",
                        subtitle: "National Automated Clearing House direct debit",
                        icon: "doc.badge.gearshape.fill",
                        iconColor: .brown,
                        value: "NACH / ECS Debit"
                    )
                    instrumentRow(
                        title: "Salary Deduction",
                        subtitle: "Direct employer payroll deduction",
                        icon: "person.crop.circle.badge.checkmark",
                        iconColor: .pink,
                        value: "Salary Deduction"
                    )
                    instrumentRow(
                        title: "Cash / Counter Payment",
                        subtitle: "Manual physical payment / counter slip",
                        icon: "banknote.fill",
                        iconColor: .secondary,
                        value: "Cash / Direct Counter"
                    )
                } header: {
                    Label("Standard AutoPay & Payment Modes", systemImage: "list.bullet.clipboard.fill")
                }
                
                // MARK: - Custom Write-In
                Section("Custom Payment Method") {
                    HStack {
                        TextField("e.g. Axis Flipkart Card, Work Expense A/c", text: $customText)
                        if !customText.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button("Apply") {
                                HapticManager.selection()
                                selectedMethod = customText.trimmingCharacters(in: .whitespaces)
                                dismiss()
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Payment Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func instrumentRow(title: String, subtitle: String, icon: String, iconColor: Color, value: String) -> some View {
        Button(action: {
            HapticManager.selection()
            selectedMethod = value
            dismiss()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.system(size: 16))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if selectedMethod == value {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
