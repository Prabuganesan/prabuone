import SwiftUI

/// Dedicated Money & Financial Obligations Hub.
/// Manages Credit Cards, Subscriptions, and Mobile / Utility Bills.
public struct MoneyHubView: View {
    @ObservedObject var store: LifeStore
    public var initialTab: Int = 0
    
    @State private var selectedTab: Int = 0
    @State private var showingAddCard = false
    @State private var showingAddSubscription = false
    
    public init(store: LifeStore, initialTab: Int = 0) {
        self.store = store
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            Picker("Pillar Segment", selection: $selectedTab) {
                Text("Cards").tag(0)
                Text("Subscriptions").tag(1)
                Text("Bills & Plans").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            ScrollView {
                VStack(spacing: 20) {
                    if selectedTab == 0 {
                        creditCardsSection
                    } else if selectedTab == 1 {
                        subscriptionsSection
                    } else {
                        billsSection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Money & Cards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    if selectedTab == 0 {
                        showingAddCard = true
                    } else {
                        showingAddSubscription = true
                    }
                }) {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingAddCard) {
            AddCreditCardSheet(store: store)
        }
        .sheet(isPresented: $showingAddSubscription) {
            AddLifeItemView(store: store)
        }
    }
    
    // MARK: - Credit Cards View
    
    // MARK: - Credit Cards View
    
    private var creditCardsSection: some View {
        VStack(spacing: 16) {
            if store.creditCards.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No Credit Cards Added")
                        .font(.headline)
                    Text("Tap + above to add your first credit card.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 32)
            } else {
                ForEach(store.creditCards) { card in
                    CreditCardView(card: card, onTogglePaid: {
                        withAnimation {
                            store.toggleCardPaid(card)
                        }
                    })
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation {
                                store.deleteCreditCard(card)
                            }
                        } label: {
                            Label("Delete Card", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Subscriptions View
    
    private var subscriptionsSection: some View {
        let subs = store.items(for: .subscription)
        let monthlySum = subs.compactMap { $0.amount }.reduce(0, +)
        let yearlySum = monthlySum * 12
        
        return VStack(spacing: 18) {
            // Analytics Summary
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MONTHLY RECURRING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(formatCurrency(monthlySum))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("YEARLY RUN-RATE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(formatCurrency(yearlySum))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(.purple)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
            }
            
            // List of Subscriptions
            if subs.isEmpty {
                Text("No subscriptions tracked yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(subs) { item in
                        LifeItemRow(item: item, onTogglePaid: {
                            withAnimation {
                                HapticManager.success()
                                store.toggleCompleted(item)
                            }
                        })
                        .padding(12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(14)
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation {
                                    store.deleteItem(item)
                                }
                            } label: {
                                Label("Delete Subscription", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Bills & Plans View
    
    private var billsSection: some View {
        let bills = store.items(for: .mobileBill)
        
        return VStack(spacing: 12) {
            if bills.isEmpty {
                Text("No mobile or utility bills added yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 24)
            } else {
                ForEach(bills) { item in
                    LifeItemRow(item: item, onTogglePaid: {
                        withAnimation {
                            HapticManager.success()
                            store.toggleCompleted(item)
                        }
                    })
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation {
                                store.deleteItem(item)
                            }
                        } label: {
                            Label("Delete Bill", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹0"
    }
}

/// Visual Credit Card Component.
struct CreditCardView: View {
    let card: CreditCardAccount
    let onTogglePaid: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.bankName.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                    Text(card.cardName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("•••• \(card.lastFourDigits)")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OUTSTANDING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                    Text(card.isPaidThisMonth ? "₹0 (Paid)" : "₹\(Int(card.outstandingAmount))")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("DUE DATE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(card.dueDay)th of month")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            // Progress Bar (Utilization)
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: card.utilizationPercentage, total: 100)
                    .tint(card.utilizationPercentage > 30 ? .orange : .white)
                
                HStack {
                    Text("Limit: ₹\(Int(card.creditLimit))")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text("Avail: ₹\(Int(card.availableLimit))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            HStack {
                Text("Reward Points: \(card.rewardPoints)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                
                Spacer()
                
                Button(action: onTogglePaid) {
                    HStack(spacing: 6) {
                        Image(systemName: card.isPaidThisMonth ? "checkmark.circle.fill" : "circle")
                        Text(card.isPaidThisMonth ? "Paid" : "Mark as Paid")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding(18)
        .background(LinearGradient(
            colors: [Color(red: 0.1, green: 0.2, blue: 0.45), Color(red: 0.15, green: 0.35, blue: 0.65)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
    }
}

/// Sheet for adding a new credit card account.
struct AddCreditCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var bankName = ""
    @State private var cardName = ""
    @State private var lastFourDigits = ""
    @State private var creditLimitText = ""
    @State private var outstandingText = ""
    @State private var statementDay = 15
    @State private var dueDay = 5
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Card Details") {
                    TextField("Bank Name (e.g. HDFC Bank)", text: $bankName)
                    TextField("Card Name (e.g. Regalia Gold)", text: $cardName)
                    TextField("Last 4 Digits", text: $lastFourDigits)
                        .keyboardType(.numberPad)
                }
                
                Section("Limits & Balances") {
                    TextField("Total Credit Limit (₹)", text: $creditLimitText)
                        .keyboardType(.numberPad)
                    TextField("Current Outstanding (₹)", text: $outstandingText)
                        .keyboardType(.numberPad)
                }
                
                Section("Billing Cycle") {
                    Stepper("Statement Date: \(statementDay)th", value: $statementDay, in: 1...31)
                    Stepper("Payment Due Date: \(dueDay)th", value: $dueDay, in: 1...31)
                }
            }
            .navigationTitle("Add Credit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let limit = Double(creditLimitText) ?? 100000
                        let outstanding = Double(outstandingText) ?? 0
                        let card = CreditCardAccount(
                            bankName: bankName,
                            cardName: cardName,
                            lastFourDigits: lastFourDigits,
                            creditLimit: limit,
                            outstandingAmount: outstanding,
                            statementDay: statementDay,
                            dueDay: dueDay
                        )
                        store.addCreditCard(card)
                        dismiss()
                    }
                    .disabled(bankName.isEmpty || cardName.isEmpty)
                }
            }
        }
    }
}
