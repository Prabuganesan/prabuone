import SwiftUI

fileprivate func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencySymbol = "₹"
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "₹0"
}

// MARK: - 1. Money & Cards Hub (Credit Cards Only)

/// Dedicated Credit Cards Hub.
/// Displays card visualizers, limits, outstandings, utilization, and billing cycles.
public struct MoneyHubView: View {
    @ObservedObject var store: LifeStore
    @State private var showingAddCard = false
    @State private var selectedCardToEdit: CreditCardAccount? = nil
    
    public init(store: LifeStore, initialTab: Int = 0) {
        self.store = store
    }
    
    private var totalLimit: Double {
        store.creditCards.reduce(0) { $0 + $1.creditLimit }
    }
    
    private var totalOutstanding: Double {
        store.creditCards.filter { !$0.isPaidThisMonth }.reduce(0) { $0 + $1.outstandingAmount }
    }
    
    private var totalAvailable: Double {
        max(0, totalLimit - totalOutstanding)
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Credit Health Summary Header
                if !store.creditCards.isEmpty {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TOTAL OUTSTANDING")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(formatCurrency(totalOutstanding))
                                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                                    .foregroundColor(totalOutstanding > 0 ? .red : .green)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("AVAILABLE CREDIT")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(formatCurrency(totalAvailable))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Total Credit Limit: \(formatCurrency(totalLimit))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(store.creditCards.count) Active Cards")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                }
                
                // Credit Cards List
                if store.creditCards.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                            .padding(.top, 24)
                        Text("No Credit Cards Added")
                            .font(.headline)
                        Text("Tap + above to track statement dates, payment dues, and limits.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            HapticManager.light()
                            showingAddCard = true
                        }) {
                            Label("Add First Credit Card", systemImage: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 32)
                } else {
                    ForEach(store.creditCards) { card in
                        CreditCardView(card: card, onTogglePaid: {
                            withAnimation {
                                store.toggleCardPaid(card)
                            }
                        }, onEdit: {
                            selectedCardToEdit = card
                        })
                        .contextMenu {
                            Button {
                                selectedCardToEdit = card
                            } label: {
                                Label("Edit Card Details", systemImage: "pencil")
                            }
                            
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
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .navigationTitle("Money & Cards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    HapticManager.light()
                    showingAddCard = true
                }) {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingAddCard) {
            AddCreditCardSheet(store: store)
        }
        .sheet(item: $selectedCardToEdit) { card in
            EditCreditCardSheet(store: store, card: card)
        }
    }
}

// MARK: - 2. Subscriptions Hub (Subscriptions Only)

/// Dedicated Subscriptions Hub.
/// Displays monthly recurring burn rate, yearly run-rate, and individual subscriptions.
public struct SubscriptionsHubView: View {
    @ObservedObject var store: LifeStore
    @State private var showingAddSubscription = false
    @State private var selectedItemToEdit: LifeItem? = nil
    
    public init(store: LifeStore) {
        self.store = store
    }
    
    private var subs: [LifeItem] {
        store.items(for: .subscription)
    }
    
    private var monthlySum: Double {
        subs.compactMap { $0.amount }.reduce(0, +)
    }
    
    private var yearlySum: Double {
        monthlySum * 12
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
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
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.triangle.2.circlepath.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.purple.opacity(0.7))
                            .padding(.top, 24)
                        Text("No Subscriptions Tracked")
                            .font(.headline)
                        Text("Track OTT, Cloud, AI tools, memberships, and renewal dates.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            HapticManager.light()
                            showingAddSubscription = true
                        }) {
                            Label("Add Subscription", systemImage: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 32)
                } else {
                    VStack(spacing: 10) {
                        ForEach(subs) { item in
                            HStack {
                                LifeItemRow(item: item, onTogglePaid: {
                                    withAnimation {
                                        HapticManager.success()
                                        store.toggleCompleted(item)
                                    }
                                })
                                
                                Button(action: {
                                    selectedItemToEdit = item
                                }) {
                                    Image(systemName: "pencil.circle")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 18))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(14)
                            .contextMenu {
                                Button {
                                    selectedItemToEdit = item
                                } label: {
                                    Label("Edit Subscription", systemImage: "pencil")
                                }
                                
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
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .navigationTitle("Subscriptions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    HapticManager.light()
                    showingAddSubscription = true
                }) {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingAddSubscription) {
            AddLifeItemView(store: store, initialCategory: .subscription)
        }
        .sheet(item: $selectedItemToEdit) { item in
            EditLifeItemSheet(store: store, item: item)
        }
    }
}

// MARK: - 3. Mobile & Bills Hub (Bills Only)

/// Dedicated Mobile & Utility Bills Hub.
/// Displays mobile recharge validity, broadband plans, electricity, and utility commitments.
public struct MobileBillsHubView: View {
    @ObservedObject var store: LifeStore
    @State private var showingAddBill = false
    @State private var selectedItemToEdit: LifeItem? = nil
    
    public init(store: LifeStore) {
        self.store = store
    }
    
    private var bills: [LifeItem] {
        store.items(for: .mobileBill)
    }
    
    private var totalOutflow: Double {
        bills.compactMap { $0.amount }.reduce(0, +)
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Banner
                if !bills.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MONTHLY UTILITY COMMITMENT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(formatCurrency(totalOutflow))
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        Spacer()
                        Image(systemName: "iphone.gen3")
                            .font(.system(size: 32))
                            .foregroundColor(.green)
                    }
                    .padding(16)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(16)
                }
                
                // List of Bills
                if bills.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "iphone.gen3")
                            .font(.system(size: 40))
                            .foregroundColor(.green.opacity(0.7))
                            .padding(.top, 24)
                        Text("No Bills Added Yet")
                            .font(.headline)
                        Text("Track mobile SIM recharges, Wi-Fi fiber, electricity, and water bills.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            HapticManager.light()
                            showingAddBill = true
                        }) {
                            Label("Add Mobile or Utility Bill", systemImage: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 32)
                } else {
                    VStack(spacing: 10) {
                        ForEach(bills) { item in
                            HStack {
                                LifeItemRow(item: item, onTogglePaid: {
                                    withAnimation {
                                        HapticManager.success()
                                        store.toggleCompleted(item)
                                    }
                                })
                                
                                Button(action: {
                                    selectedItemToEdit = item
                                }) {
                                    Image(systemName: "pencil.circle")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 18))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(14)
                            .contextMenu {
                                Button {
                                    selectedItemToEdit = item
                                } label: {
                                    Label("Edit Bill", systemImage: "pencil")
                                }
                                
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
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .navigationTitle("Mobile & Bills")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    HapticManager.light()
                    showingAddBill = true
                }) {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingAddBill) {
            AddLifeItemView(store: store, initialCategory: .mobileBill)
        }
        .sheet(item: $selectedItemToEdit) { item in
            EditLifeItemSheet(store: store, item: item)
        }
    }
}

/// Visual Credit Card Component.
struct CreditCardView: View {
    let card: CreditCardAccount
    let onTogglePaid: () -> Void
    var onEdit: (() -> Void)? = nil
    
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
                
                if let onEdit = onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                
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

/// Sheet for editing an existing credit card account.
struct EditCreditCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    let card: CreditCardAccount
    
    @State private var bankName = ""
    @State private var cardName = ""
    @State private var lastFourDigits = ""
    @State private var creditLimitText = ""
    @State private var outstandingText = ""
    @State private var statementDay = 15
    @State private var dueDay = 5
    @State private var rewardPointsText = "0"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Card Details") {
                    TextField("Bank Name", text: $bankName)
                    TextField("Card Name", text: $cardName)
                    TextField("Last 4 Digits", text: $lastFourDigits)
                        .keyboardType(.numberPad)
                }
                
                Section("Limits & Balances") {
                    TextField("Total Credit Limit (₹)", text: $creditLimitText)
                        .keyboardType(.numberPad)
                    TextField("Current Outstanding (₹)", text: $outstandingText)
                        .keyboardType(.numberPad)
                    TextField("Reward Points", text: $rewardPointsText)
                        .keyboardType(.numberPad)
                }
                
                Section("Billing Cycle") {
                    Stepper("Statement Date: \(statementDay)th", value: $statementDay, in: 1...31)
                    Stepper("Payment Due Date: \(dueDay)th", value: $dueDay, in: 1...31)
                }
            }
            .navigationTitle("Edit Credit Card")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                bankName = card.bankName
                cardName = card.cardName
                lastFourDigits = card.lastFourDigits
                creditLimitText = "\(Int(card.creditLimit))"
                outstandingText = "\(Int(card.outstandingAmount))"
                statementDay = card.statementDay
                dueDay = card.dueDay
                rewardPointsText = "\(card.rewardPoints)"
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = card
                        updated.bankName = bankName
                        updated.cardName = cardName
                        updated.lastFourDigits = lastFourDigits
                        if let lim = Double(creditLimitText) { updated.creditLimit = lim }
                        if let out = Double(outstandingText) { updated.outstandingAmount = out }
                        if let pts = Int(rewardPointsText) { updated.rewardPoints = pts }
                        updated.statementDay = statementDay
                        updated.dueDay = dueDay
                        store.updateCreditCard(updated)
                        dismiss()
                    }
                    .disabled(bankName.isEmpty || cardName.isEmpty)
                }
            }
        }
    }
}

/// Sheet for editing an existing subscription, bill, or life item.
struct EditLifeItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    let item: LifeItem
    
    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var category: LifeCategory = .subscription
    @State private var dueDate: Date = Date()
    @State private var amountText: String = ""
    @State private var repeatFrequency: RepeatFrequency = .monthly
    @State private var notes: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Title", text: $title)
                    TextField("Subtitle", text: $subtitle)
                    Picker("Category", selection: $category) {
                        ForEach(LifeCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.iconName).tag(cat)
                        }
                    }
                }
                
                Section("Timeline & Amount") {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])
                    HStack {
                        Text("₹").foregroundColor(.secondary)
                        TextField("Amount", text: $amountText)
                            .keyboardType(.numberPad)
                    }
                    Picker("Repeat", selection: $repeatFrequency) {
                        ForEach(RepeatFrequency.allCases) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Notes & details", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Edit Commitment")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                title = item.title
                subtitle = item.subtitle
                category = item.category
                dueDate = item.dueDate
                amountText = item.amount != nil ? "\(Int(item.amount!))" : ""
                repeatFrequency = item.repeatFrequency
                notes = item.notes ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = item
                        updated.title = title.trimmingCharacters(in: .whitespaces)
                        updated.subtitle = subtitle.trimmingCharacters(in: .whitespaces)
                        updated.category = category
                        updated.dueDate = dueDate
                        updated.amount = Double(amountText.replacingOccurrences(of: ",", with: ""))
                        updated.repeatFrequency = repeatFrequency
                        updated.notes = notes.isEmpty ? nil : notes
                        store.updateItem(updated)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
