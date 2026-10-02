import SwiftUI

fileprivate func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencySymbol = "₹"
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "₹0"
}

// MARK: - 1. Money & Cards Hub (Cards & Bank Accounts Vault)

public enum MoneyVaultSegment: String, CaseIterable {
    case cards = "Cards"
    case bankAccounts = "Bank Accounts"
}

/// Dedicated Financial Digital Vault.
/// Stores full 16-digit credit/debit card numbers, CVVs, expiry dates, and full bank account numbers, IFSC codes, and UPI IDs.
public struct MoneyHubView: View {
    @ObservedObject var store: LifeStore
    @State private var selectedSegment: MoneyVaultSegment = .cards
    
    // Card Sheets & Search
    @State private var showingAddCard = false
    @State private var selectedCardToEdit: CreditCardAccount? = nil
    @State private var cardSearchText = ""
    
    // Bank Account Sheets & Search
    @State private var showingAddBankAccount = false
    @State private var selectedAccountToEdit: BankAccount? = nil
    @State private var accountSearchText = ""
    
    // Toast Feedback
    @State private var copiedToast: String? = nil
    
    public init(store: LifeStore, initialTab: Int = 0) {
        self.store = store
    }
    
    private var totalLimit: Double {
        store.creditCards.reduce(0) { $0 + $1.creditLimit }
    }
    
    private var creditCardCount: Int {
        store.creditCards.filter { !$0.isDebit }.count
    }
    
    private var debitCardCount: Int {
        store.creditCards.filter { $0.isDebit }.count
    }
    
    private var filteredCards: [CreditCardAccount] {
        let query = cardSearchText.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty {
            return store.creditCards
        }
        return store.creditCards.filter {
            $0.bankName.lowercased().contains(query) ||
            $0.cardName.lowercased().contains(query) ||
            $0.cardHolderName.lowercased().contains(query) ||
            $0.lastFourDigits.contains(query) ||
            $0.cardNetwork.lowercased().contains(query) ||
            $0.cardCategory.lowercased().contains(query)
        }
    }
    
    private var filteredBankAccounts: [BankAccount] {
        let query = accountSearchText.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty {
            return store.bankAccounts
        }
        return store.bankAccounts.filter {
            $0.bankName.lowercased().contains(query) ||
            $0.accountHolderName.lowercased().contains(query) ||
            $0.ifscCode.lowercased().contains(query) ||
            $0.lastFourDigits.contains(query) ||
            $0.upiId.lowercased().contains(query) ||
            $0.accountType.lowercased().contains(query) ||
            $0.branchName.lowercased().contains(query)
        }
    }
    
    public var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Segmented Switcher: Cards vs Bank Accounts
                    Picker("Vault Category", selection: $selectedSegment) {
                        Text("Cards (\(store.creditCards.count))").tag(MoneyVaultSegment.cards)
                        Text("Bank Accounts (\(store.bankAccounts.count))").tag(MoneyVaultSegment.bankAccounts)
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)
                    
                    if selectedSegment == .cards {
                        cardsSection
                    } else {
                        bankAccountsSection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            
            // Toast HUD for 1-Tap Copy
            if let toast = copiedToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(toast)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.88))
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .shadow(radius: 6)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle(selectedSegment == .cards ? "Cards Wallet" : "Bank Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        HapticManager.light()
                        showingAddCard = true
                    } label: {
                        Label("Add Card (Credit / Debit)", systemImage: "creditcard")
                    }
                    
                    Button {
                        HapticManager.light()
                        showingAddBankAccount = true
                    } label: {
                        Label("Add Bank Account", systemImage: "building.columns")
                    }
                } label: {
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
        .sheet(isPresented: $showingAddBankAccount) {
            AddBankAccountSheet(store: store)
        }
        .sheet(item: $selectedAccountToEdit) { account in
            EditBankAccountSheet(store: store, account: account)
        }
    }
    
    // MARK: - Cards Section
    @ViewBuilder
    private var cardsSection: some View {
        // Vault Header
        if !store.creditCards.isEmpty {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.blue)
                            Text("CARD WALLET")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        Text("\(store.creditCards.count) Cards Stored")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Credit: \(creditCardCount) • Debit: \(debitCardCount)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if totalLimit > 0 {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("TOTAL LIMIT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(formatCurrency(totalLimit))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                    Text("Full 16-digit card numbers, CVVs & expiry dates stored encrypted on-device.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            
            // Search bar
            if store.creditCards.count >= 2 {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search cards by bank, name, or last 4...", text: $cardSearchText)
                        .font(.system(size: 14))
                    if !cardSearchText.isEmpty {
                        Button(action: { cardSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
        }
        
        // Cards List
        if store.creditCards.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "creditcard.and.123")
                    .font(.system(size: 46))
                    .foregroundColor(.blue)
                    .padding(.top, 30)
                Text("No Cards Stored")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Store all your credit & debit cards with full 16-digit card numbers, CVVs, and expiry dates for instant 1-tap copy during checkout.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                
                Button(action: {
                    HapticManager.light()
                    showingAddCard = true
                }) {
                    Label("Add Credit or Debit Card", systemImage: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top, 10)
            }
            .padding(.vertical, 28)
        } else {
            ForEach(filteredCards) { card in
                CreditCardView(
                    card: card,
                    onCopy: { text, label in
                        copyText(text, label: label)
                    },
                    onEdit: {
                        selectedCardToEdit = card
                    }
                )
                .contextMenu {
                    Button {
                        let cleanDigits = card.cardNumber.filter { $0.isNumber }
                        copyText(cleanDigits, label: "Card Number")
                    } label: {
                        Label("Copy Card Number", systemImage: "doc.on.doc")
                    }
                    
                    if !card.cvv.isEmpty {
                        Button {
                            copyText(card.cvv, label: "CVV")
                        } label: {
                            Label("Copy CVV", systemImage: "lock")
                        }
                    }
                    
                    if !card.expiryDate.isEmpty {
                        Button {
                            copyText(card.expiryDate, label: "Expiry Date")
                        } label: {
                            Label("Copy Expiry Date", systemImage: "calendar")
                        }
                    }
                    
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
    
    // MARK: - Bank Accounts Section
    @ViewBuilder
    private var bankAccountsSection: some View {
        // Vault Header
        if !store.bankAccounts.isEmpty {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.teal)
                            Text("BANKING VAULT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        Text("\(store.bankAccounts.count) Accounts Stored")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                    Text("Bank account numbers, IFSC codes & UPI IDs stored encrypted on-device.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            
            // Search bar
            if store.bankAccounts.count >= 2 {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search accounts by bank, IFSC, or UPI...", text: $accountSearchText)
                        .font(.system(size: 14))
                    if !accountSearchText.isEmpty {
                        Button(action: { accountSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
        }
        
        // Bank Accounts List
        if store.bankAccounts.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "building.columns.circle.fill")
                    .font(.system(size: 46))
                    .foregroundColor(.teal)
                    .padding(.top, 30)
                Text("No Bank Accounts Stored")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Store your savings, current, and salary bank accounts with IFSC codes and UPI IDs for instant 1-tap copy during bank transfers.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                
                Button(action: {
                    HapticManager.light()
                    showingAddBankAccount = true
                }) {
                    Label("Add First Bank Account", systemImage: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.teal)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top, 10)
            }
            .padding(.vertical, 28)
        } else {
            ForEach(filteredBankAccounts) { account in
                BankAccountCardView(
                    account: account,
                    onCopy: { text, label in
                        copyText(text, label: label)
                    },
                    onEdit: {
                        selectedAccountToEdit = account
                    }
                )
                .contextMenu {
                    Button {
                        let cleanDigits = account.accountNumber.filter { $0.isNumber }
                        copyText(cleanDigits.isEmpty ? account.accountNumber : cleanDigits, label: "Account Number")
                    } label: {
                        Label("Copy Account Number", systemImage: "doc.on.doc")
                    }
                    
                    if !account.ifscCode.isEmpty {
                        Button {
                            copyText(account.ifscCode, label: "IFSC Code")
                        } label: {
                            Label("Copy IFSC Code", systemImage: "building.columns")
                        }
                    }
                    
                    if !account.upiId.isEmpty {
                        Button {
                            copyText(account.upiId, label: "UPI ID")
                        } label: {
                            Label("Copy UPI ID", systemImage: "qrcode")
                        }
                    }
                    
                    Button {
                        selectedAccountToEdit = account
                    } label: {
                        Label("Edit Account Details", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        withAnimation {
                            store.deleteBankAccount(account)
                        }
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                    }
                }
            }
        }
    }
    
    private func copyText(_ text: String, label: String) {
        UIPasteboard.general.string = text
        HapticManager.success()
        withAnimation {
            copiedToast = "Copied \(label)"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedToast = nil
            }
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

/// Visual Credit Card Component with Realistic Design, Privacy Masking, and 1-Tap Copy Actions.
struct CreditCardView: View {
    let card: CreditCardAccount
    let onCopy: (_ text: String, _ label: String) -> Void
    var onEdit: (() -> Void)? = nil
    
    @State private var isRevealed: Bool = false
    
    private var cardGradient: LinearGradient {
        switch card.cardTheme {
        case "obsidian":
            return LinearGradient(
                colors: [Color(red: 0.12, green: 0.12, blue: 0.14), Color(red: 0.24, green: 0.24, blue: 0.26)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "emerald":
            return LinearGradient(
                colors: [Color(red: 0.05, green: 0.22, blue: 0.16), Color(red: 0.12, green: 0.42, blue: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "titanium":
            return LinearGradient(
                colors: [Color(red: 0.28, green: 0.30, blue: 0.34), Color(red: 0.48, green: 0.52, blue: 0.56)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "purple":
            return LinearGradient(
                colors: [Color(red: 0.22, green: 0.08, blue: 0.38), Color(red: 0.46, green: 0.16, blue: 0.68)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "roseGold":
            return LinearGradient(
                colors: [Color(red: 0.38, green: 0.14, blue: 0.22), Color(red: 0.62, green: 0.26, blue: 0.36)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default: // midnight
            return LinearGradient(
                colors: [Color(red: 0.08, green: 0.15, blue: 0.32), Color(red: 0.14, green: 0.32, blue: 0.58)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Main Physical Card
            VStack(alignment: .leading, spacing: 14) {
                // Top Header Row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(card.bankName.uppercased())
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .kerning(1.2)
                                .foregroundColor(.white)
                            
                            // Category Badge: DEBIT or CREDIT
                            Text(card.isDebit ? "DEBIT" : "CREDIT")
                                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                                .kerning(0.8)
                                .foregroundColor(card.isDebit ? Color(red: 0.4, green: 1.0, blue: 0.6) : Color(red: 0.6, green: 0.9, blue: 1.0))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.35))
                                .cornerRadius(4)
                        }
                        Text(card.cardName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            HapticManager.selection()
                            isRevealed.toggle()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                                Text(isRevealed ? "Hide" : "Show")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        if let onEdit = onEdit {
                            Button(action: onEdit) {
                                Image(systemName: "pencil.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Chip & Contactless & Network Icon Row
                HStack(spacing: 12) {
                    // Realistic EMV Chip
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.85, green: 0.72, blue: 0.45), Color(red: 0.70, green: 0.55, blue: 0.30)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 32, height: 24)
                        
                        // Chip circuit lines
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.black.opacity(0.3), lineWidth: 0.8)
                            .frame(width: 22, height: 16)
                    }
                    
                    Image(systemName: "wave.3.forward")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                    
                    Spacer()
                    
                    // Card Network
                    Text(card.cardNetwork.uppercased())
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .italic()
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.25))
                        .cornerRadius(6)
                }
                .padding(.top, 2)
                
                // Card Number Row (Tap to Copy)
                Button(action: {
                    let clean = card.cardNumber.filter { $0.isNumber }
                    onCopy(clean, "Card Number")
                }) {
                    HStack(spacing: 8) {
                        Text(isRevealed ? card.formattedCardNumber : card.maskedCardNumber)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .kerning(1.5)
                        
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                
                // Bottom Details Row (Holder, Expiry, CVV)
                HStack(alignment: .bottom) {
                    // Card Holder
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CARD HOLDER")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.65))
                        Text(card.cardHolderName.isEmpty ? "PRABU GANESAN" : card.cardHolderName.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Valid Thru / Expiry
                    Button(action: {
                        if !card.expiryDate.isEmpty {
                            onCopy(card.expiryDate, "Expiry Date")
                        }
                    }) {
                        VStack(alignment: .center, spacing: 2) {
                            Text("VALID THRU")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.65))
                            Text(card.expiryDate.isEmpty ? "••/••" : card.expiryDate)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // CVV
                    Button(action: {
                        if !card.cvv.isEmpty {
                            onCopy(card.cvv, "CVV")
                        }
                    }) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("CVV")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.65))
                            Text(isRevealed ? (card.cvv.isEmpty ? "•••" : card.cvv) : card.maskedCVV)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .background(cardGradient)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 5)
            
            // 1-Tap Copy Action Pills Below Card
            HStack(spacing: 8) {
                Button(action: {
                    let clean = card.cardNumber.filter { $0.isNumber }
                    onCopy(clean, "Card Number")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 10))
                        Text("Copy Number")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color(UIColor.secondarySystemBackground))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                if !card.cvv.isEmpty {
                    Button(action: {
                        onCopy(card.cvv, "CVV")
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 10))
                            Text("Copy CVV")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color(UIColor.secondarySystemBackground))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                if !card.expiryDate.isEmpty {
                    Button(action: {
                        onCopy(card.expiryDate, "Expiry")
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text("Copy Expiry")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color(UIColor.secondarySystemBackground))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                if let due = card.dueDay {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                        Text("Due \(due)th")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }
            }
        }
    }
}

/// Sheet for adding a new credit or debit card account with full card number, CVV, and expiry date.
struct AddCreditCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var cardCategory = "Credit"
    @State private var bankName = ""
    @State private var cardName = ""
    @State private var cardNumber = ""
    @State private var cardHolderName = "PRABU GANESAN"
    @State private var expiryDate = ""
    @State private var cvv = ""
    @State private var creditLimitText = ""
    @State private var hasDueDay = false
    @State private var dueDay = 5
    @State private var cardTheme = "midnight"
    
    let commonBanks = ["HDFC Bank", "ICICI Bank", "SBI", "Axis Bank", "Kotak", "Amex", "Standard Chartered", "IndusInd"]
    
    let themes: [(id: String, name: String, color: Color)] = [
        ("midnight", "Midnight", Color(red: 0.14, green: 0.32, blue: 0.58)),
        ("obsidian", "Obsidian", Color(red: 0.22, green: 0.22, blue: 0.24)),
        ("emerald", "Emerald", Color(red: 0.12, green: 0.42, blue: 0.28)),
        ("titanium", "Titanium", Color(red: 0.48, green: 0.52, blue: 0.56)),
        ("purple", "Purple", Color(red: 0.46, green: 0.16, blue: 0.68)),
        ("roseGold", "Rose Gold", Color(red: 0.62, green: 0.26, blue: 0.36))
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Card Type") {
                    Picker("Card Category", selection: $cardCategory) {
                        Text("Credit Card").tag("Credit")
                        Text("Debit Card").tag("Debit")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Card Details") {
                    TextField("Bank Name (e.g. HDFC Bank)", text: $bankName)
                    
                    // Quick Bank Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(commonBanks, id: \.self) { bank in
                                Button(action: {
                                    HapticManager.selection()
                                    bankName = bank
                                }) {
                                    Text(bank)
                                        .font(.system(size: 11, weight: .medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(bankName == bank ? Color.blue : Color(UIColor.secondarySystemBackground))
                                        .foregroundColor(bankName == bank ? .white : .primary)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    
                    TextField(cardCategory == "Debit" ? "Card Name (e.g. Platinum Debit, EasyPay)" : "Card Name (e.g. Regalia Gold, Millennia)", text: $cardName)
                    TextField("Cardholder Name", text: $cardHolderName)
                }
                
                Section("Card Number, Expiry & CVV") {
                    HStack {
                        TextField("Card Number (16 Digits)", text: $cardNumber)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: cardNumber) { newValue in
                                cardNumber = formatCardNumber(newValue)
                            }
                        
                        let network = CreditCardAccount.detectNetwork(from: cardNumber)
                        Text(network)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(6)
                    }
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("EXPIRY DATE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            TextField("MM/YY", text: $expiryDate)
                                .keyboardType(.numberPad)
                                .font(.system(.body, design: .monospaced))
                                .onChange(of: expiryDate) { newValue in
                                    expiryDate = formatExpiry(newValue)
                                }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CVV")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            TextField("3 or 4 digits", text: $cvv)
                                .keyboardType(.numberPad)
                                .font(.system(.body, design: .monospaced))
                                .onChange(of: cvv) { newValue in
                                    let clean = newValue.filter { $0.isNumber }
                                    cvv = String(clean.prefix(4))
                                }
                        }
                    }
                }
                
                Section("Card Theme Color") {
                    HStack(spacing: 16) {
                        ForEach(themes, id: \.id) { theme in
                            Button(action: {
                                HapticManager.selection()
                                cardTheme = theme.id
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(theme.color)
                                        .frame(width: 32, height: 32)
                                    
                                    if cardTheme == theme.id {
                                        Circle()
                                            .stroke(Color.primary, lineWidth: 2.5)
                                            .frame(width: 38, height: 38)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
                
                Section(cardCategory == "Debit" ? "Debit Card Settings" : "Credit Limit & Due Date") {
                    if cardCategory == "Credit" {
                        TextField("Credit Limit (₹, Optional)", text: $creditLimitText)
                            .keyboardType(.numberPad)
                        
                        Toggle("Track Monthly Due Date", isOn: $hasDueDay)
                        if hasDueDay {
                            Stepper("Payment Due Day: \(dueDay)th of month", value: $dueDay, in: 1...31)
                        }
                    } else {
                        TextField("Daily Limit / ATM Limit (₹, Optional)", text: $creditLimitText)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle(cardCategory == "Debit" ? "Add Debit Card" : "Add Credit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCard()
                    }
                    .fontWeight(.bold)
                    .disabled(bankName.trimmingCharacters(in: .whitespaces).isEmpty || cardName.trimmingCharacters(in: .whitespaces).isEmpty || cardNumber.filter { $0.isNumber }.isEmpty)
                }
            }
        }
    }
    
    private func formatCardNumber(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        let trimmed = String(digits.prefix(16))
        var formatted = ""
        for (index, char) in trimmed.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted.append(" ")
            }
            formatted.append(char)
        }
        return formatted
    }
    
    private func formatExpiry(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        let trimmed = String(digits.prefix(4))
        if trimmed.count > 2 {
            let month = trimmed.prefix(2)
            let year = trimmed.suffix(trimmed.count - 2)
            return "\(month)/\(year)"
        }
        return trimmed
    }
    
    private func saveCard() {
        let cleanDigits = cardNumber.filter { $0.isNumber }
        let network = CreditCardAccount.detectNetwork(from: cleanDigits)
        let limit = Double(creditLimitText.replacingOccurrences(of: ",", with: "")) ?? 0
        
        let card = CreditCardAccount(
            bankName: bankName.trimmingCharacters(in: .whitespaces),
            cardName: cardName.trimmingCharacters(in: .whitespaces),
            cardNumber: cleanDigits,
            cardHolderName: cardHolderName.trimmingCharacters(in: .whitespaces),
            expiryDate: expiryDate.trimmingCharacters(in: .whitespaces),
            cvv: cvv.trimmingCharacters(in: .whitespaces),
            creditLimit: limit,
            statementDay: nil,
            dueDay: (cardCategory == "Credit" && hasDueDay) ? dueDay : nil,
            cardNetwork: network,
            cardTheme: cardTheme,
            cardCategory: cardCategory
        )
        store.addCreditCard(card)
        dismiss()
    }
}

/// Sheet for editing an existing credit or debit card account.
struct EditCreditCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    let card: CreditCardAccount
    
    @State private var cardCategory = "Credit"
    @State private var bankName = ""
    @State private var cardName = ""
    @State private var cardNumber = ""
    @State private var cardHolderName = ""
    @State private var expiryDate = ""
    @State private var cvv = ""
    @State private var creditLimitText = ""
    @State private var hasDueDay = false
    @State private var dueDay = 5
    @State private var cardTheme = "midnight"
    
    let themes: [(id: String, name: String, color: Color)] = [
        ("midnight", "Midnight", Color(red: 0.14, green: 0.32, blue: 0.58)),
        ("obsidian", "Obsidian", Color(red: 0.22, green: 0.22, blue: 0.24)),
        ("emerald", "Emerald", Color(red: 0.12, green: 0.42, blue: 0.28)),
        ("titanium", "Titanium", Color(red: 0.48, green: 0.52, blue: 0.56)),
        ("purple", "Purple", Color(red: 0.46, green: 0.16, blue: 0.68)),
        ("roseGold", "Rose Gold", Color(red: 0.62, green: 0.26, blue: 0.36))
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Card Type") {
                    Picker("Card Category", selection: $cardCategory) {
                        Text("Credit Card").tag("Credit")
                        Text("Debit Card").tag("Debit")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Card Details") {
                    TextField("Bank Name", text: $bankName)
                    TextField("Card Name", text: $cardName)
                    TextField("Cardholder Name", text: $cardHolderName)
                }
                
                Section("Card Number, Expiry & CVV") {
                    HStack {
                        TextField("Card Number", text: $cardNumber)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: cardNumber) { newValue in
                                cardNumber = formatCardNumber(newValue)
                            }
                        
                        let network = CreditCardAccount.detectNetwork(from: cardNumber)
                        Text(network)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(6)
                    }
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("EXPIRY DATE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            TextField("MM/YY", text: $expiryDate)
                                .keyboardType(.numberPad)
                                .font(.system(.body, design: .monospaced))
                                .onChange(of: expiryDate) { newValue in
                                    expiryDate = formatExpiry(newValue)
                                }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CVV")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            TextField("CVV", text: $cvv)
                                .keyboardType(.numberPad)
                                .font(.system(.body, design: .monospaced))
                                .onChange(of: cvv) { newValue in
                                    let clean = newValue.filter { $0.isNumber }
                                    cvv = String(clean.prefix(4))
                                }
                        }
                    }
                }
                
                Section("Card Theme Color") {
                    HStack(spacing: 16) {
                        ForEach(themes, id: \.id) { theme in
                            Button(action: {
                                HapticManager.selection()
                                cardTheme = theme.id
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(theme.color)
                                        .frame(width: 32, height: 32)
                                    
                                    if cardTheme == theme.id {
                                        Circle()
                                            .stroke(Color.primary, lineWidth: 2.5)
                                            .frame(width: 38, height: 38)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
                
                Section(cardCategory == "Debit" ? "Debit Card Settings" : "Credit Limit & Due Date") {
                    if cardCategory == "Credit" {
                        TextField("Credit Limit (₹, Optional)", text: $creditLimitText)
                            .keyboardType(.numberPad)
                        
                        Toggle("Track Monthly Due Date", isOn: $hasDueDay)
                        if hasDueDay {
                            Stepper("Payment Due Day: \(dueDay)th of month", value: $dueDay, in: 1...31)
                        }
                    } else {
                        TextField("Daily Limit / ATM Limit (₹, Optional)", text: $creditLimitText)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle(cardCategory == "Debit" ? "Edit Debit Card" : "Edit Credit Card")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                cardCategory = card.cardCategory.isEmpty ? "Credit" : card.cardCategory
                bankName = card.bankName
                cardName = card.cardName
                cardNumber = card.formattedCardNumber
                cardHolderName = card.cardHolderName
                expiryDate = card.expiryDate
                cvv = card.cvv
                creditLimitText = card.creditLimit > 0 ? "\(Int(card.creditLimit))" : ""
                hasDueDay = card.dueDay != nil
                dueDay = card.dueDay ?? 5
                cardTheme = card.cardTheme
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveUpdatedCard()
                    }
                    .fontWeight(.bold)
                    .disabled(bankName.trimmingCharacters(in: .whitespaces).isEmpty || cardName.trimmingCharacters(in: .whitespaces).isEmpty || cardNumber.filter { $0.isNumber }.isEmpty)
                }
            }
        }
    }
    
    private func formatCardNumber(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        let trimmed = String(digits.prefix(16))
        var formatted = ""
        for (index, char) in trimmed.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted.append(" ")
            }
            formatted.append(char)
        }
        return formatted
    }
    
    private func formatExpiry(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        let trimmed = String(digits.prefix(4))
        if trimmed.count > 2 {
            let month = trimmed.prefix(2)
            let year = trimmed.suffix(trimmed.count - 2)
            return "\(month)/\(year)"
        }
        return trimmed
    }
    
    private func saveUpdatedCard() {
        let cleanDigits = cardNumber.filter { $0.isNumber }
        let network = CreditCardAccount.detectNetwork(from: cleanDigits)
        let limit = Double(creditLimitText.replacingOccurrences(of: ",", with: "")) ?? 0
        
        var updated = card
        updated.cardCategory = cardCategory
        updated.bankName = bankName.trimmingCharacters(in: .whitespaces)
        updated.cardName = cardName.trimmingCharacters(in: .whitespaces)
        updated.cardNumber = cleanDigits
        updated.cardHolderName = cardHolderName.trimmingCharacters(in: .whitespaces)
        updated.expiryDate = expiryDate.trimmingCharacters(in: .whitespaces)
        updated.cvv = cvv.trimmingCharacters(in: .whitespaces)
        updated.creditLimit = limit
        updated.dueDay = (cardCategory == "Credit" && hasDueDay) ? dueDay : nil
        updated.cardNetwork = network
        updated.cardTheme = cardTheme
        
        store.updateCreditCard(updated)
        dismiss()
    }
}

// MARK: - Bank Account Card & Sheets

/// Visual Bank Account Card Component with Passbook / Modern Bank Card Aesthetics and 1-Tap Copy Actions.
struct BankAccountCardView: View {
    let account: BankAccount
    let onCopy: (_ text: String, _ label: String) -> Void
    var onEdit: (() -> Void)? = nil
    
    @State private var isRevealed: Bool = false
    
    private var accountGradient: LinearGradient {
        switch account.accountTheme {
        case "emerald":
            return LinearGradient(
                colors: [Color(red: 0.06, green: 0.28, blue: 0.18), Color(red: 0.12, green: 0.48, blue: 0.32)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "purple":
            return LinearGradient(
                colors: [Color(red: 0.24, green: 0.08, blue: 0.38), Color(red: 0.44, green: 0.18, blue: 0.64)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "slate":
            return LinearGradient(
                colors: [Color(red: 0.16, green: 0.18, blue: 0.22), Color(red: 0.32, green: 0.34, blue: 0.40)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "amber":
            return LinearGradient(
                colors: [Color(red: 0.38, green: 0.22, blue: 0.08), Color(red: 0.62, green: 0.38, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default: // blue
            return LinearGradient(
                colors: [Color(red: 0.08, green: 0.20, blue: 0.42), Color(red: 0.14, green: 0.36, blue: 0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Main Bank Account Passbook Card
            VStack(alignment: .leading, spacing: 14) {
                // Top Header Row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                            
                            Text(account.bankName.uppercased())
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .kerning(1.0)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        
                        if !account.branchName.isEmpty {
                            Text(account.branchName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 10) {
                        // Account Type Badge
                        Text(account.accountType.uppercased())
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .kerning(0.8)
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.22))
                            .cornerRadius(6)
                        
                        // Eye Reveal / Hide
                        Button(action: {
                            HapticManager.selection()
                            isRevealed.toggle()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                                Text(isRevealed ? "Hide" : "Show")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        if let onEdit = onEdit {
                            Button(action: onEdit) {
                                Image(systemName: "pencil.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Account Number Section (Tap to Copy)
                VStack(alignment: .leading, spacing: 3) {
                    Text("ACCOUNT NUMBER")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.65))
                        .kerning(0.5)
                    
                    Button(action: {
                        let clean = account.accountNumber.filter { $0.isNumber }
                        onCopy(clean.isEmpty ? account.accountNumber : clean, "Account Number")
                    }) {
                        HStack(spacing: 8) {
                            Text(isRevealed ? account.formattedAccountNumber : account.maskedAccountNumber)
                                .font(.system(size: 19, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .kerning(1.2)
                            
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
                
                // Bottom Details Row: Holder Name, IFSC, UPI ID
                HStack(alignment: .bottom, spacing: 14) {
                    // Account Holder
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ACCOUNT HOLDER")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.65))
                        Text(account.accountHolderName.isEmpty ? "PRABU GANESAN" : account.accountHolderName.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // IFSC Code (Tap to Copy)
                    Button(action: {
                        if !account.ifscCode.isEmpty {
                            onCopy(account.ifscCode, "IFSC Code")
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("IFSC CODE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.65))
                            HStack(spacing: 4) {
                                Text(account.ifscCode)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if !account.upiId.isEmpty {
                        Spacer()
                        
                        // UPI ID (Tap to Copy)
                        Button(action: {
                            onCopy(account.upiId, "UPI ID")
                        }) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("UPI ID")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white.opacity(0.65))
                                HStack(spacing: 4) {
                                    Text(account.upiId)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
            .background(accountGradient)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 5)
            
            // 1-Tap Copy Quick Action Pills
            HStack(spacing: 8) {
                Button(action: {
                    let clean = account.accountNumber.filter { $0.isNumber }
                    onCopy(clean.isEmpty ? account.accountNumber : clean, "Account Number")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 10))
                        Text("Copy A/C No")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color(UIColor.secondarySystemBackground))
                    .foregroundColor(.teal)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                if !account.ifscCode.isEmpty {
                    Button(action: {
                        onCopy(account.ifscCode, "IFSC Code")
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 10))
                            Text("Copy IFSC")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color(UIColor.secondarySystemBackground))
                        .foregroundColor(.teal)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                if !account.upiId.isEmpty {
                    Button(action: {
                        onCopy(account.upiId, "UPI ID")
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 10))
                            Text("Copy UPI")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color(UIColor.secondarySystemBackground))
                        .foregroundColor(.teal)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Sheet for adding a new bank account with full details.
struct AddBankAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var bankName = ""
    @State private var accountHolderName = "PRABU GANESAN"
    @State private var accountNumber = ""
    @State private var ifscCode = ""
    @State private var accountType = "Savings"
    @State private var upiId = ""
    @State private var branchName = ""
    @State private var accountTheme = "blue"
    
    let commonBanks = ["HDFC Bank", "ICICI Bank", "SBI", "Axis Bank", "Kotak", "Canara Bank", "Bank of Baroda", "PNB"]
    let accountTypes = ["Savings", "Current", "Salary"]
    
    let themes: [(id: String, name: String, color: Color)] = [
        ("blue", "Royal Blue", Color(red: 0.14, green: 0.36, blue: 0.65)),
        ("emerald", "Emerald", Color(red: 0.12, green: 0.48, blue: 0.32)),
        ("purple", "Purple", Color(red: 0.44, green: 0.18, blue: 0.64)),
        ("slate", "Obsidian Slate", Color(red: 0.32, green: 0.34, blue: 0.40)),
        ("amber", "Warm Bronze", Color(red: 0.62, green: 0.38, blue: 0.16))
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Bank Details") {
                    TextField("Bank Name (e.g. HDFC Bank)", text: $bankName)
                    
                    // Quick Bank Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(commonBanks, id: \.self) { bank in
                                Button(action: {
                                    HapticManager.selection()
                                    bankName = bank
                                }) {
                                    Text(bank)
                                        .font(.system(size: 11, weight: .medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(bankName == bank ? Color.teal : Color(UIColor.secondarySystemBackground))
                                        .foregroundColor(bankName == bank ? .white : .primary)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    
                    TextField("Branch Name (Optional)", text: $branchName)
                    TextField("Account Holder Name", text: $accountHolderName)
                    
                    Picker("Account Type", selection: $accountType) {
                        ForEach(accountTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Account Number & IFSC") {
                    TextField("Account Number", text: $accountNumber)
                        .keyboardType(.numberPad)
                        .font(.system(.body, design: .monospaced))
                    
                    TextField("IFSC Code (e.g. HDFC0000060)", text: $ifscCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: ifscCode) { newValue in
                            ifscCode = newValue.uppercased()
                        }
                }
                
                Section("UPI ID (Optional)") {
                    TextField("UPI ID (e.g. name@okhdfcbank)", text: $upiId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.emailAddress)
                }
                
                Section("Theme Color") {
                    HStack(spacing: 16) {
                        ForEach(themes, id: \.id) { theme in
                            Button(action: {
                                HapticManager.selection()
                                accountTheme = theme.id
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(theme.color)
                                        .frame(width: 32, height: 32)
                                    
                                    if accountTheme == theme.id {
                                        Circle()
                                            .stroke(Color.primary, lineWidth: 2.5)
                                            .frame(width: 38, height: 38)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Add Bank Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAccount()
                    }
                    .fontWeight(.bold)
                    .disabled(bankName.trimmingCharacters(in: .whitespaces).isEmpty || accountNumber.trimmingCharacters(in: .whitespaces).isEmpty || ifscCode.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveAccount() {
        let cleanNumber = accountNumber.filter { $0.isNumber }
        let account = BankAccount(
            bankName: bankName.trimmingCharacters(in: .whitespaces),
            accountHolderName: accountHolderName.trimmingCharacters(in: .whitespaces),
            accountNumber: cleanNumber.isEmpty ? accountNumber.trimmingCharacters(in: .whitespaces) : cleanNumber,
            ifscCode: ifscCode.trimmingCharacters(in: .whitespaces).uppercased(),
            accountType: accountType,
            upiId: upiId.trimmingCharacters(in: .whitespaces),
            branchName: branchName.trimmingCharacters(in: .whitespaces),
            accountTheme: accountTheme
        )
        store.addBankAccount(account)
        dismiss()
    }
}

/// Sheet for editing an existing bank account.
struct EditBankAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    let account: BankAccount
    
    @State private var bankName = ""
    @State private var accountHolderName = ""
    @State private var accountNumber = ""
    @State private var ifscCode = ""
    @State private var accountType = "Savings"
    @State private var upiId = ""
    @State private var branchName = ""
    @State private var accountTheme = "blue"
    
    let commonBanks = ["HDFC Bank", "ICICI Bank", "SBI", "Axis Bank", "Kotak", "Canara Bank", "Bank of Baroda", "PNB"]
    let accountTypes = ["Savings", "Current", "Salary"]
    
    let themes: [(id: String, name: String, color: Color)] = [
        ("blue", "Royal Blue", Color(red: 0.14, green: 0.36, blue: 0.65)),
        ("emerald", "Emerald", Color(red: 0.12, green: 0.48, blue: 0.32)),
        ("purple", "Purple", Color(red: 0.44, green: 0.18, blue: 0.64)),
        ("slate", "Obsidian Slate", Color(red: 0.32, green: 0.34, blue: 0.40)),
        ("amber", "Warm Bronze", Color(red: 0.62, green: 0.38, blue: 0.16))
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Bank Details") {
                    TextField("Bank Name", text: $bankName)
                    TextField("Branch Name (Optional)", text: $branchName)
                    TextField("Account Holder Name", text: $accountHolderName)
                    
                    Picker("Account Type", selection: $accountType) {
                        ForEach(accountTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Account Number & IFSC") {
                    TextField("Account Number", text: $accountNumber)
                        .keyboardType(.numberPad)
                        .font(.system(.body, design: .monospaced))
                    
                    TextField("IFSC Code", text: $ifscCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: ifscCode) { newValue in
                            ifscCode = newValue.uppercased()
                        }
                }
                
                Section("UPI ID (Optional)") {
                    TextField("UPI ID", text: $upiId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.emailAddress)
                }
                
                Section("Theme Color") {
                    HStack(spacing: 16) {
                        ForEach(themes, id: \.id) { theme in
                            Button(action: {
                                HapticManager.selection()
                                accountTheme = theme.id
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(theme.color)
                                        .frame(width: 32, height: 32)
                                    
                                    if accountTheme == theme.id {
                                        Circle()
                                            .stroke(Color.primary, lineWidth: 2.5)
                                            .frame(width: 38, height: 38)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Edit Bank Account")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                bankName = account.bankName
                accountHolderName = account.accountHolderName
                accountNumber = account.accountNumber
                ifscCode = account.ifscCode
                accountType = account.accountType
                upiId = account.upiId
                branchName = account.branchName
                accountTheme = account.accountTheme
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveUpdatedAccount()
                    }
                    .fontWeight(.bold)
                    .disabled(bankName.trimmingCharacters(in: .whitespaces).isEmpty || accountNumber.trimmingCharacters(in: .whitespaces).isEmpty || ifscCode.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveUpdatedAccount() {
        let cleanNumber = accountNumber.filter { $0.isNumber }
        var updated = account
        updated.bankName = bankName.trimmingCharacters(in: .whitespaces)
        updated.accountHolderName = accountHolderName.trimmingCharacters(in: .whitespaces)
        updated.accountNumber = cleanNumber.isEmpty ? accountNumber.trimmingCharacters(in: .whitespaces) : cleanNumber
        updated.ifscCode = ifscCode.trimmingCharacters(in: .whitespaces).uppercased()
        updated.accountType = accountType
        updated.upiId = upiId.trimmingCharacters(in: .whitespaces)
        updated.branchName = branchName.trimmingCharacters(in: .whitespaces)
        updated.accountTheme = accountTheme
        
        store.updateBankAccount(updated)
        dismiss()
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
