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
    case creditCards = "Credit Cards"
    case debitCards = "Debit Cards"
    case bankAccounts = "Bank Accounts"
}

/// Dedicated Financial Digital Vault.
/// Stores full 16-digit credit and debit card numbers, CVVs, expiry dates, ATM PIN, TPIN, and full bank account numbers, IFSC codes, and UPI IDs.
public struct MoneyHubView: View {
    @ObservedObject var store: LifeStore
    @State private var selectedSegment: MoneyVaultSegment = .creditCards
    
    // Card Sheets & Search
    @State private var showingAddCard = false
    @State private var addCardCategory: String = "Credit"
    @State private var selectedCardToEdit: CreditCardAccount? = nil
    @State private var creditSearchText = ""
    @State private var debitSearchText = ""
    
    // Bank Account Sheets & Search
    @State private var showingAddBankAccount = false
    @State private var selectedAccountToEdit: BankAccount? = nil
    @State private var accountSearchText = ""
    
    // Toast Feedback
    @State private var copiedToast: String? = nil
    
    public init(store: LifeStore, initialTab: Int = 0) {
        self.store = store
    }
    
    private var creditCardCount: Int {
        store.creditCards.filter { !$0.isDebit }.count
    }
    
    private var debitCardCount: Int {
        store.creditCards.filter { $0.isDebit }.count
    }
    
    private var totalCreditLimit: Double {
        store.creditCards.filter { !$0.isDebit }.reduce(0) { $0 + $1.creditLimit }
    }
    
    private var filteredCreditCards: [CreditCardAccount] {
        let cards = store.creditCards.filter { !$0.isDebit }
        let query = creditSearchText.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty { return cards }
        return cards.filter {
            $0.bankName.lowercased().contains(query) ||
            $0.cardName.lowercased().contains(query) ||
            $0.cardHolderName.lowercased().contains(query) ||
            $0.lastFourDigits.contains(query) ||
            $0.cardNetwork.lowercased().contains(query)
        }
    }
    
    private var filteredDebitCards: [CreditCardAccount] {
        let cards = store.creditCards.filter { $0.isDebit }
        let query = debitSearchText.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty { return cards }
        return cards.filter {
            $0.bankName.lowercased().contains(query) ||
            $0.cardName.lowercased().contains(query) ||
            $0.cardHolderName.lowercased().contains(query) ||
            $0.lastFourDigits.contains(query) ||
            $0.cardNetwork.lowercased().contains(query)
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
    
    private var navigationTitleForSegment: String {
        switch selectedSegment {
        case .creditCards: return "Credit Cards"
        case .debitCards: return "Debit Cards"
        case .bankAccounts: return "Bank Accounts"
        }
    }
    
    public var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Segmented Switcher: Credit Cards vs Debit Cards vs Bank Accounts
                    Picker("Vault Category", selection: $selectedSegment) {
                        Text("Credit (\(creditCardCount))").tag(MoneyVaultSegment.creditCards)
                        Text("Debit (\(debitCardCount))").tag(MoneyVaultSegment.debitCards)
                        Text("Bank (\(store.bankAccounts.count))").tag(MoneyVaultSegment.bankAccounts)
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)
                    
                    switch selectedSegment {
                    case .creditCards:
                        creditCardsSection
                    case .debitCards:
                        debitCardsSection
                    case .bankAccounts:
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
        .navigationTitle(navigationTitleForSegment)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        HapticManager.light()
                        addCardCategory = "Credit"
                        showingAddCard = true
                    } label: {
                        Label("Add Credit Card", systemImage: "creditcard")
                    }
                    
                    Button {
                        HapticManager.light()
                        addCardCategory = "Debit"
                        showingAddCard = true
                    } label: {
                        Label("Add Debit Card", systemImage: "creditcard.fill")
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
            AddCreditCardSheet(store: store, initialCategory: addCardCategory)
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
    
    // MARK: - Credit Cards Section
    @ViewBuilder
    private var creditCardsSection: some View {
        // Vault Header
        if creditCardCount > 0 {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.blue)
                            Text("CREDIT CARD WALLET")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        Text("\(creditCardCount) Cards Stored")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    if totalCreditLimit > 0 {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("TOTAL LIMIT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(formatCurrency(totalCreditLimit))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                    Text("16-digit card numbers, CVVs, expiry dates, ATM PIN & TPIN encrypted on-device.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            
            // Search bar
            if creditCardCount >= 2 {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search credit cards by bank or name...", text: $creditSearchText)
                        .font(.system(size: 14))
                    if !creditSearchText.isEmpty {
                        Button(action: { creditSearchText = "" }) {
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
        if creditCardCount == 0 {
            VStack(spacing: 12) {
                Image(systemName: "creditcard")
                    .font(.system(size: 46))
                    .foregroundColor(.blue)
                    .padding(.top, 30)
                Text("No Credit Cards Stored")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Store all your credit cards with full 16-digit numbers, CVVs, expiry dates, and ATM/TPIN for instant 1-tap checkout.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                
                Button(action: {
                    HapticManager.light()
                    addCardCategory = "Credit"
                    showingAddCard = true
                }) {
                    Label("Add Credit Card", systemImage: "plus")
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
            ForEach(filteredCreditCards) { card in
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
                    
                    if !card.atmPin.isEmpty {
                        Button {
                            copyText(card.atmPin, label: "ATM PIN")
                        } label: {
                            Label("Copy ATM PIN", systemImage: "key.fill")
                        }
                    }
                    
                    if !card.tpin.isEmpty {
                        Button {
                            copyText(card.tpin, label: "TPIN")
                        } label: {
                            Label("Copy TPIN", systemImage: "lock.rotation")
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
    
    // MARK: - Debit Cards Section
    @ViewBuilder
    private var debitCardsSection: some View {
        // Vault Header
        if debitCardCount > 0 {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.cyan)
                            Text("DEBIT CARD WALLET")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        Text("\(debitCardCount) Debit Cards Stored")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                    Text("Debit card numbers, CVVs, ATM PIN & TPIN stored encrypted on-device.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            
            // Search bar
            if debitCardCount >= 2 {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search debit cards by bank or name...", text: $debitSearchText)
                        .font(.system(size: 14))
                    if !debitSearchText.isEmpty {
                        Button(action: { debitSearchText = "" }) {
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
        
        // Debit Cards List
        if debitCardCount == 0 {
            VStack(spacing: 12) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 46))
                    .foregroundColor(.cyan)
                    .padding(.top, 30)
                Text("No Debit Cards Stored")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Store your bank debit cards with full card numbers, CVVs, ATM PINs & TPINs for safe, fast access.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                
                Button(action: {
                    HapticManager.light()
                    addCardCategory = "Debit"
                    showingAddCard = true
                }) {
                    Label("Add Debit Card", systemImage: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.cyan)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top, 10)
            }
            .padding(.vertical, 28)
        } else {
            ForEach(filteredDebitCards) { card in
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
                    
                    if !card.atmPin.isEmpty {
                        Button {
                            copyText(card.atmPin, label: "ATM PIN")
                        } label: {
                            Label("Copy ATM PIN", systemImage: "key.fill")
                        }
                    }
                    
                    if !card.tpin.isEmpty {
                        Button {
                            copyText(card.tpin, label: "TPIN")
                        } label: {
                            Label("Copy TPIN", systemImage: "lock.rotation")
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
                    Text("Bank account numbers, IFSC codes, UPI IDs, ATM PIN & TPIN stored encrypted on-device.")
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
                Text("Store your savings, current, and salary bank accounts with IFSC codes, UPI IDs, and PINs for instant 1-tap copy during bank transfers.")
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
                    
                    if !account.tpin.isEmpty {
                        Button {
                            copyText(account.tpin, label: "TPIN / UPI PIN")
                        } label: {
                            Label("Copy TPIN / UPI PIN", systemImage: "lock.rotation")
                        }
                    }
                    
                    if !account.atmPin.isEmpty {
                        Button {
                            copyText(account.atmPin, label: "ATM PIN")
                        } label: {
                            Label("Copy ATM PIN", systemImage: "key.fill")
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

// MARK: - 2. Subscriptions Hub (Dedicated OTT & Digital Subscriptions)

public struct SubscriptionPresetPlan: Identifiable {
    public var id: String { name }
    public let name: String
    public let price: Double
    public let frequency: RepeatFrequency
}

public struct OTTServicePreset: Identifiable {
    public let id: String
    public let name: String
    public let icon: String
    public let brandColor: Color
    public let hexColor: String
    public let category: String
    public let plans: [SubscriptionPresetPlan]
}

public let popularSubscriptionPresets: [OTTServicePreset] = [
    OTTServicePreset(
        id: "netflix",
        name: "Netflix",
        icon: "tv.fill",
        brandColor: Color(red: 0.90, green: 0.04, blue: 0.08),
        hexColor: "#E50914",
        category: "OTT / Video",
        plans: [
            SubscriptionPresetPlan(name: "Mobile", price: 149, frequency: .monthly),
            SubscriptionPresetPlan(name: "Basic 720p", price: 199, frequency: .monthly),
            SubscriptionPresetPlan(name: "Standard 1080p", price: 499, frequency: .monthly),
            SubscriptionPresetPlan(name: "Premium 4K UHD", price: 649, frequency: .monthly)
        ]
    ),
    OTTServicePreset(
        id: "prime",
        name: "Amazon Prime Video",
        icon: "play.rectangle.fill",
        brandColor: Color(red: 0.0, green: 0.65, blue: 0.88),
        hexColor: "#00A8E1",
        category: "OTT / Video",
        plans: [
            SubscriptionPresetPlan(name: "Prime Annual", price: 1499, frequency: .yearly),
            SubscriptionPresetPlan(name: "Prime Monthly", price: 299, frequency: .monthly),
            SubscriptionPresetPlan(name: "Prime Lite Annual", price: 799, frequency: .yearly),
            SubscriptionPresetPlan(name: "Prime Shopping Edition", price: 399, frequency: .yearly)
        ]
    ),
    OTTServicePreset(
        id: "hotstar",
        name: "Disney+ Hotstar",
        icon: "star.fill",
        brandColor: Color(red: 0.07, green: 0.24, blue: 0.81),
        hexColor: "#113CCF",
        category: "OTT / Video",
        plans: [
            SubscriptionPresetPlan(name: "Super Annual (Full HD)", price: 899, frequency: .yearly),
            SubscriptionPresetPlan(name: "Premium Annual (4K UHD)", price: 1499, frequency: .yearly),
            SubscriptionPresetPlan(name: "Premium Monthly", price: 299, frequency: .monthly)
        ]
    ),
    OTTServicePreset(
        id: "youtube",
        name: "YouTube Premium",
        icon: "play.rectangle.on.rectangle.fill",
        brandColor: Color(red: 1.0, green: 0.0, blue: 0.0),
        hexColor: "#FF0000",
        category: "OTT / Video",
        plans: [
            SubscriptionPresetPlan(name: "Individual Monthly", price: 149, frequency: .monthly),
            SubscriptionPresetPlan(name: "Family Monthly (5 users)", price: 299, frequency: .monthly),
            SubscriptionPresetPlan(name: "Individual Annual", price: 1490, frequency: .yearly),
            SubscriptionPresetPlan(name: "Student Monthly", price: 89, frequency: .monthly)
        ]
    ),
    OTTServicePreset(
        id: "spotify",
        name: "Spotify",
        icon: "music.note",
        brandColor: Color(red: 0.11, green: 0.73, blue: 0.33),
        hexColor: "#1DB954",
        category: "Music",
        plans: [
            SubscriptionPresetPlan(name: "Individual Monthly", price: 119, frequency: .monthly),
            SubscriptionPresetPlan(name: "Duo Monthly", price: 149, frequency: .monthly),
            SubscriptionPresetPlan(name: "Family Monthly", price: 179, frequency: .monthly),
            SubscriptionPresetPlan(name: "Individual Annual", price: 1189, frequency: .yearly)
        ]
    ),
    OTTServicePreset(
        id: "apple",
        name: "Apple One / TV+",
        icon: "applelogo",
        brandColor: Color(red: 0.55, green: 0.55, blue: 0.58),
        hexColor: "#8E8E93",
        category: "OTT / Video",
        plans: [
            SubscriptionPresetPlan(name: "Apple One Individual", price: 195, frequency: .monthly),
            SubscriptionPresetPlan(name: "Apple One Family", price: 365, frequency: .monthly),
            SubscriptionPresetPlan(name: "Apple TV+ Only", price: 99, frequency: .monthly),
            SubscriptionPresetPlan(name: "Apple Music Individual", price: 99, frequency: .monthly)
        ]
    ),
    OTTServicePreset(
        id: "chatgpt",
        name: "ChatGPT / Claude AI",
        icon: "cpu.fill",
        brandColor: Color(red: 0.06, green: 0.64, blue: 0.50),
        hexColor: "#10A37F",
        category: "AI & Cloud",
        plans: [
            SubscriptionPresetPlan(name: "ChatGPT Plus ($20)", price: 1999, frequency: .monthly),
            SubscriptionPresetPlan(name: "Claude Pro ($20)", price: 1999, frequency: .monthly),
            SubscriptionPresetPlan(name: "Perplexity Pro", price: 1999, frequency: .monthly)
        ]
    ),
    OTTServicePreset(
        id: "googleone",
        name: "Google One / Cloud",
        icon: "cloud.fill",
        brandColor: Color(red: 0.26, green: 0.52, blue: 0.96),
        hexColor: "#4285F4",
        category: "AI & Cloud",
        plans: [
            SubscriptionPresetPlan(name: "Basic 100GB Monthly", price: 130, frequency: .monthly),
            SubscriptionPresetPlan(name: "Standard 200GB Monthly", price: 210, frequency: .monthly),
            SubscriptionPresetPlan(name: "Premium 2TB Monthly", price: 650, frequency: .monthly),
            SubscriptionPresetPlan(name: "Basic 100GB Annual", price: 1300, frequency: .yearly)
        ]
    ),
    OTTServicePreset(
        id: "sonyliv",
        name: "Sony LIV",
        icon: "play.tv.fill",
        brandColor: Color(red: 1.0, green: 0.40, blue: 0.0),
        hexColor: "#FF6600",
        category: "OTT / Video",
        plans: [
            SubscriptionPresetPlan(name: "Premium Annual", price: 999, frequency: .yearly),
            SubscriptionPresetPlan(name: "Premium 6-Months", price: 699, frequency: .halfYearly),
            SubscriptionPresetPlan(name: "Mobile Only Annual", price: 599, frequency: .yearly)
        ]
    ),
    OTTServicePreset(
        id: "zee5",
        name: "Zee5",
        icon: "film.fill",
        brandColor: Color(red: 0.51, green: 0.19, blue: 0.78),
        hexColor: "#8230C6",
        category: "OTT / Video",
        plans: [
            SubscriptionPresetPlan(name: "Premium Annual", price: 899, frequency: .yearly),
            SubscriptionPresetPlan(name: "Premium 4K Annual", price: 1199, frequency: .yearly)
        ]
    ),
    OTTServicePreset(
        id: "jiocinema",
        name: "JioCinema Premium",
        icon: "video.fill",
        brandColor: Color(red: 0.90, green: 0.0, blue: 0.49),
        hexColor: "#E5007D",
        category: "OTT / Video",
        plans: [
            SubscriptionPresetPlan(name: "Premium Monthly", price: 29, frequency: .monthly),
            SubscriptionPresetPlan(name: "Family Monthly (4 screens)", price: 89, frequency: .monthly),
            SubscriptionPresetPlan(name: "Annual VIP", price: 299, frequency: .yearly)
        ]
    ),
    OTTServicePreset(
        id: "custom",
        name: "Other / Custom",
        icon: "arrow.triangle.2.circlepath.circle.fill",
        brandColor: Color.purple,
        hexColor: "#9333EA",
        category: "Utilities",
        plans: [
            SubscriptionPresetPlan(name: "Custom Monthly", price: 499, frequency: .monthly),
            SubscriptionPresetPlan(name: "Custom Annual", price: 4999, frequency: .yearly)
        ]
    )
]

/// Dedicated Subscriptions Hub with OTT presets, effective monthly burn rate, and rich management.
public struct SubscriptionsHubView: View {
    @ObservedObject var store: LifeStore
    @State private var showingAddSubscription = false
    @State private var selectedItemToEdit: LifeItem? = nil
    @State private var selectedFilter: String = "All"
    @State private var searchQuery: String = ""
    @State private var copiedFeedback: String? = nil
    
    public init(store: LifeStore) {
        self.store = store
    }
    
    private var allSubs: [LifeItem] {
        store.items(for: .subscription)
    }
    
    private var filteredSubs: [LifeItem] {
        var items = allSubs
        
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            items = items.filter {
                $0.title.lowercased().contains(q) ||
                $0.subtitle.lowercased().contains(q) ||
                ($0.planTier?.lowercased().contains(q) ?? false) ||
                ($0.paymentMethod?.lowercased().contains(q) ?? false) ||
                ($0.accountEmail?.lowercased().contains(q) ?? false) ||
                ($0.notes?.lowercased().contains(q) ?? false)
            }
        }
        
        switch selectedFilter {
        case "OTT / Video":
            return items.filter { item in
                let t = item.title.lowercased()
                return t.contains("netflix") || t.contains("prime") || t.contains("hotstar") ||
                       t.contains("youtube") || t.contains("apple") || t.contains("sony") ||
                       t.contains("zee") || t.contains("jio") || t.contains("hbo") || t.contains("ott")
            }
        case "Music":
            return items.filter { item in
                let t = item.title.lowercased()
                return t.contains("spotify") || t.contains("music") || t.contains("wynk") || t.contains("gaana")
            }
        case "AI & Cloud":
            return items.filter { item in
                let t = item.title.lowercased()
                return t.contains("chatgpt") || t.contains("claude") || t.contains("google") ||
                       t.contains("icloud") || t.contains("cloud") || t.contains("ai") || t.contains("drive")
            }
        case "Annual":
            return items.filter { $0.repeatFrequency == .yearly }
        case "Auto-Debit":
            return items.filter { $0.autoRenew == true }
        default:
            return items
        }
    }
    
    private var monthlyBurn: Double {
        allSubs.filter { !$0.isCompleted }.reduce(0) { $0 + $1.normalizedMonthlyAmount }
    }
    
    private var yearlyRunRate: Double {
        monthlyBurn * 12.0
    }
    
    private var activeCount: Int {
        allSubs.filter { !$0.isCompleted }.count
    }
    
    private var autoDebitCount: Int {
        allSubs.filter { $0.autoRenew == true }.count
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 📊 Analytics KPI Cards
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle().fill(Color.purple).frame(width: 6, height: 6)
                            Text("MONTHLY BURN")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        Text(formatCurrency(monthlyBurn))
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("\(activeCount) Active Subscriptions")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 10))
                                .foregroundColor(.indigo)
                            Text("YEARLY RUN-RATE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        Text(formatCurrency(yearlyRunRate))
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(.indigo)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("\(autoDebitCount) on Auto-Debit")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                }
                
                // 🔍 Search Bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    TextField("Search Netflix, Prime, Hotstar, Plans...", text: $searchQuery)
                        .font(.system(size: 14))
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // 🏷️ Category Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["All", "OTT / Video", "Music", "AI & Cloud", "Annual", "Auto-Debit"], id: \.self) { filter in
                            Button {
                                HapticManager.selection()
                                selectedFilter = filter
                            } label: {
                                Text(filter)
                                    .font(.system(size: 12, weight: selectedFilter == filter ? .bold : .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedFilter == filter ? Color.purple : Color(UIColor.secondarySystemBackground))
                                    .foregroundColor(selectedFilter == filter ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                // 📋 Subscriptions List / Empty State
                if filteredSubs.isEmpty {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.12))
                                .frame(width: 80, height: 80)
                            Image(systemName: "play.tv.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.purple)
                        }
                        .padding(.top, 24)
                        
                        Text(allSubs.isEmpty ? "Track All Your OTT & Subscriptions" : "No Matching Subscriptions")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        
                        Text(allSubs.isEmpty ? "Manage Netflix, Prime, Disney+ Hotstar, YouTube, Spotify, and cloud plans with renewal countdowns and effective monthly burn tracking." : "Try adjusting your search query or selected filter.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        // Preset Quick-Tap Pills in Empty State
                        if allSubs.isEmpty {
                            VStack(spacing: 8) {
                                Text("POPULAR PRESETS")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(popularSubscriptionPresets.prefix(4)) { preset in
                                        Button {
                                            HapticManager.light()
                                            showingAddSubscription = true
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: preset.icon)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(preset.brandColor)
                                                Text(preset.name)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .lineLimit(1)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color(UIColor.secondarySystemBackground))
                                            .cornerRadius(10)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                        
                        Button {
                            HapticManager.light()
                            showingAddSubscription = true
                        } label: {
                            Label("Add Subscription", systemImage: "plus")
                                .font(.system(size: 15, weight: .bold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 24)
                } else {
                    VStack(spacing: 12) {
                        ForEach(filteredSubs) { item in
                            SubscriptionCardRow(
                                item: item,
                                onTogglePaid: {
                                    withAnimation {
                                        HapticManager.success()
                                        store.toggleCompleted(item)
                                    }
                                },
                                onEdit: {
                                    selectedItemToEdit = item
                                },
                                onDelete: {
                                    withAnimation {
                                        store.deleteItem(item)
                                    }
                                },
                                onCopyEmail: { email in
                                    UIPasteboard.general.string = email
                                    HapticManager.success()
                                    withAnimation {
                                        copiedFeedback = "Copied \(email)"
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation { copiedFeedback = nil }
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .navigationTitle("Subscriptions")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let feedback = copiedFeedback {
                Text(feedback)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.85))
                    .clipShape(Capsule())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
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
            AddSubscriptionSheet(store: store)
        }
        .sheet(item: $selectedItemToEdit) { item in
            EditSubscriptionSheet(store: store, item: item)
        }
    }
}

/// Custom visual card row for OTT and digital subscriptions.
public struct SubscriptionCardRow: View {
    let item: LifeItem
    let onTogglePaid: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onCopyEmail: (String) -> Void
    
    private var preset: OTTServicePreset? {
        let t = item.title.lowercased()
        let b = (item.serviceBrand ?? "").lowercased()
        return popularSubscriptionPresets.first {
            $0.name.lowercased() == t ||
            $0.id.lowercased() == b ||
            t.contains($0.name.lowercased())
        }
    }
    
    private var brandColor: Color {
        preset?.brandColor ?? Color.purple
    }
    
    private var iconName: String {
        preset?.icon ?? "play.tv.fill"
    }
    
    private var billingCycleLabel: String {
        switch item.repeatFrequency {
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .halfYearly: return "Half-Yearly"
        case .yearly: return "Annual"
        case .never: return "One-Time"
        }
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                // Brand Icon Container
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [brandColor.opacity(0.25), brandColor.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(brandColor.opacity(0.3), lineWidth: 1)
                        )
                        .frame(width: 46, height: 46)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(brandColor)
                }
                
                // Subscription Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        if let plan = item.planTier, !plan.isEmpty {
                            Text(plan)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(brandColor.opacity(0.18))
                                .foregroundColor(brandColor)
                                .clipShape(Capsule())
                        }
                    }
                    
                    // Renewal Countdown & Date
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text("\(item.daysRemainingText) • Due \(item.formattedDueDate)")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundColor(item.urgency <= .in3Days ? .orange : .secondary)
                    
                    // Account ID & Sharing
                    if let email = item.accountEmail, !email.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 10))
                            Text(email)
                                .font(.system(size: 11))
                                .lineLimit(1)
                            
                            if let shared = item.sharedWith, !shared.isEmpty {
                                Text("• \(shared)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Pricing & Action
                VStack(alignment: .trailing, spacing: 4) {
                    if let amount = item.amount {
                        Text(formatCurrency(amount))
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(billingCycleLabel)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        if item.repeatFrequency == .yearly {
                            Text("(\(formatCurrency(amount / 12.0))/mo)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        } else if item.repeatFrequency == .quarterly {
                            Text("(\(formatCurrency(amount / 3.0))/mo)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: onTogglePaid) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(item.isCompleted ? .green : .secondary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            
            // Bottom Metadata Bar (Payment Method & Auto-Debit status)
            if item.paymentMethod != nil || item.autoRenew == true {
                Divider().background(Color.primary.opacity(0.06))
                
                HStack(spacing: 8) {
                    if let payment = item.paymentMethod, !payment.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.blue)
                            Text(payment)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    if item.autoRenew == true {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9))
                            Text("Auto-Debit Active")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.emeraldAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.emeraldAccent.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit Subscription", systemImage: "pencil")
            }
            
            Button {
                onTogglePaid()
            } label: {
                Label("Mark Renewed (Advance Cycle)", systemImage: "arrow.triangle.2.circlepath")
            }
            
            if let email = item.accountEmail, !email.isEmpty {
                Button {
                    onCopyEmail(email)
                } label: {
                    Label("Copy Login ID (\(email))", systemImage: "doc.on.doc")
                }
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Subscription", systemImage: "trash")
            }
        }
    }
}

/// Comprehensive sheet specifically crafted for adding OTT and digital subscriptions.
public struct AddSubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var selectedPreset: OTTServicePreset? = popularSubscriptionPresets.first
    @State private var title: String = "Netflix"
    @State private var planTier: String = "Premium 4K UHD"
    @State private var billingCycle: RepeatFrequency = .monthly
    @State private var amountText: String = "649"
    @State private var dueDate: Date = Date().addingTimeInterval(86400 * 30)
    @State private var paymentMethod: String = "HDFC Credit Card"
    @State private var accountEmail: String = ""
    @State private var sharedWith: String = "4 Screens • Family"
    @State private var autoRenew: Bool = true
    @State private var reminderDays: [Int] = [7, 3, 1]
    @State private var notes: String = ""
    
    public init(store: LifeStore) {
        self.store = store
    }
    
    private var effectiveMonthlyBurn: Double {
        let val = Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        switch billingCycle {
        case .monthly: return val
        case .quarterly: return val / 3.0
        case .halfYearly: return val / 6.0
        case .yearly: return val / 12.0
        case .never: return val
        }
    }
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0) > 0
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                // 1. Quick Presets Carousel
                Section("Popular OTT & Digital Services") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(popularSubscriptionPresets) { preset in
                                Button {
                                    HapticManager.selection()
                                    selectPreset(preset)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: preset.icon)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(preset.brandColor)
                                        Text(preset.name)
                                            .font(.system(size: 12, weight: selectedPreset?.id == preset.id ? .bold : .medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedPreset?.id == preset.id ? preset.brandColor.opacity(0.18) : Color(UIColor.secondarySystemBackground))
                                    .foregroundColor(selectedPreset?.id == preset.id ? preset.brandColor : .primary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(selectedPreset?.id == preset.id ? preset.brandColor : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // 2. Service & Plan
                Section("Service & Plan Details") {
                    TextField("Service Name (e.g. Netflix, Prime Video)", text: $title)
                    
                    if let preset = selectedPreset, !preset.plans.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recommended Plans")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(preset.plans) { plan in
                                        Button {
                                            HapticManager.selection()
                                            planTier = plan.name
                                            amountText = "\(Int(plan.price))"
                                            billingCycle = plan.frequency
                                        } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(plan.name)
                                                    .font(.system(size: 11, weight: .bold))
                                                Text("₹\(Int(plan.price)) • \(plan.frequency.rawValue)")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(planTier == plan.name ? Color.purple.opacity(0.15) : Color(UIColor.secondarySystemBackground))
                                            .foregroundColor(planTier == plan.name ? .purple : .primary)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(planTier == plan.name ? Color.purple : Color.clear, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    
                    TextField("Plan Tier (e.g. Premium 4K, Family, Annual VIP)", text: $planTier)
                }
                
                // 3. Pricing & Billing Frequency
                Section("Billing Cycle & Pricing") {
                    Picker("Billing Frequency", selection: $billingCycle) {
                        Text("Monthly").tag(RepeatFrequency.monthly)
                        Text("Quarterly (3m)").tag(RepeatFrequency.quarterly)
                        Text("Half-Yearly (6m)").tag(RepeatFrequency.halfYearly)
                        Text("Annual (1yr)").tag(RepeatFrequency.yearly)
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text("₹")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        TextField("Price (e.g. 649 or 1499)", text: $amountText)
                            .keyboardType(.numberPad)
                    }
                    
                    // Effective Monthly Burn Indicator Callout
                    if effectiveMonthlyBurn > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.purple)
                                .font(.system(size: 14))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Effective Monthly Burn: \(formatCurrency(effectiveMonthlyBurn))/month")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.purple)
                                Text("Normalized monthly cost based on \(billingCycle.rawValue.lowercased()) cycle")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // 4. Renewal Timeline & Auto-Debit
                Section("Renewal & Auto-Debit") {
                    DatePicker("Next Renewal Date", selection: $dueDate, displayedComponents: [.date])
                    
                    Toggle(isOn: $autoRenew) {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.shield.fill")
                                .foregroundColor(.emeraldAccent)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Auto-Debit Active")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Recurring e-mandate on card or UPI")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // 5. Payment Source & Account Details
                Section("Payment Method & Login") {
                    // Quick Payment Selection
                    TextField("Payment Source (e.g. HDFC Regalia, UPI AutoPay)", text: $paymentMethod)
                    
                    // Quick Fill Pills from User's Cards & Banks
                    if !store.creditCards.isEmpty || !store.bankAccounts.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(store.creditCards) { card in
                                    Button {
                                        paymentMethod = "\(card.bankName) \(card.cardName)"
                                    } label: {
                                        Text("💳 \(card.bankName) (...\(card.lastFourDigits))")
                                            .font(.system(size: 10.5, weight: .medium))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(UIColor.secondarySystemBackground))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Button {
                                    paymentMethod = "UPI AutoPay"
                                } label: {
                                    Text("📲 UPI AutoPay")
                                        .font(.system(size: 10.5, weight: .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    paymentMethod = "Apple In-App"
                                } label: {
                                    Text("🍎 Apple In-App")
                                        .font(.system(size: 10.5, weight: .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    TextField("Registered Email / Phone ID (e.g. prabu@gmail.com)", text: $accountEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("Profile / Screens (e.g. 4 Screens • Family)", text: $sharedWith)
                }
                
                // 6. Notes & Hints
                Section("Notes & Credential Hints") {
                    TextField("Login hints, renewal coupons, or sharing info", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("New Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSubscription()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func selectPreset(_ preset: OTTServicePreset) {
        selectedPreset = preset
        title = preset.name
        if let firstPlan = preset.plans.first {
            planTier = firstPlan.name
            amountText = "\(Int(firstPlan.price))"
            billingCycle = firstPlan.frequency
        }
    }
    
    private func saveSubscription() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ""))
        let item = LifeItem(
            title: title.trimmingCharacters(in: .whitespaces),
            subtitle: "\(planTier.isEmpty ? "Plan" : planTier) • \(billingCycle.rawValue)",
            category: .subscription,
            dueDate: dueDate,
            amount: amount,
            repeatFrequency: billingCycle,
            isCompleted: false,
            notes: notes.isEmpty ? nil : notes,
            reminderDaysBefore: reminderDays,
            planTier: planTier.isEmpty ? nil : planTier,
            billingCycle: billingCycle.rawValue,
            paymentMethod: paymentMethod.isEmpty ? nil : paymentMethod,
            accountEmail: accountEmail.isEmpty ? nil : accountEmail,
            sharedWith: sharedWith.isEmpty ? nil : sharedWith,
            autoRenew: autoRenew,
            serviceBrand: selectedPreset?.id ?? title
        )
        store.addItem(item)
        HapticManager.success()
        dismiss()
    }
}

/// Sheet for editing an existing subscription with all OTT & digital service controls.
public struct EditSubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    let item: LifeItem
    
    @State private var title: String = ""
    @State private var planTier: String = ""
    @State private var billingCycle: RepeatFrequency = .monthly
    @State private var amountText: String = ""
    @State private var dueDate: Date = Date()
    @State private var paymentMethod: String = ""
    @State private var accountEmail: String = ""
    @State private var sharedWith: String = ""
    @State private var autoRenew: Bool = true
    @State private var notes: String = ""
    
    public init(store: LifeStore, item: LifeItem) {
        self.store = store
        self.item = item
    }
    
    private var effectiveMonthlyBurn: Double {
        let val = Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        switch billingCycle {
        case .monthly: return val
        case .quarterly: return val / 3.0
        case .halfYearly: return val / 6.0
        case .yearly: return val / 12.0
        case .never: return val
        }
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Service & Plan") {
                    TextField("Service Name", text: $title)
                    TextField("Plan Tier (e.g. Premium 4K)", text: $planTier)
                }
                
                Section("Billing Cycle & Pricing") {
                    Picker("Billing Frequency", selection: $billingCycle) {
                        Text("Monthly").tag(RepeatFrequency.monthly)
                        Text("Quarterly (3m)").tag(RepeatFrequency.quarterly)
                        Text("Half-Yearly (6m)").tag(RepeatFrequency.halfYearly)
                        Text("Annual (1yr)").tag(RepeatFrequency.yearly)
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text("₹").foregroundColor(.secondary)
                        TextField("Amount", text: $amountText)
                            .keyboardType(.numberPad)
                    }
                    
                    if effectiveMonthlyBurn > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill").foregroundColor(.purple)
                            Text("Effective Monthly Burn: \(formatCurrency(effectiveMonthlyBurn))/month")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.purple)
                        }
                    }
                }
                
                Section("Renewal & Auto-Debit") {
                    DatePicker("Next Renewal Date", selection: $dueDate, displayedComponents: [.date])
                    Toggle("Auto-Debit Active (e-Mandate)", isOn: $autoRenew)
                }
                
                Section("Payment Source & Account") {
                    TextField("Payment Method (e.g. HDFC Card)", text: $paymentMethod)
                    TextField("Registered Email / Phone", text: $accountEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Profile / Screens (e.g. 4 Screens)", text: $sharedWith)
                }
                
                Section("Notes") {
                    TextField("Notes & details", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Edit Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                title = item.title
                planTier = item.planTier ?? item.subtitle
                billingCycle = item.repeatFrequency
                amountText = item.amount != nil ? "\(Int(item.amount!))" : ""
                dueDate = item.dueDate
                paymentMethod = item.paymentMethod ?? ""
                accountEmail = item.accountEmail ?? ""
                sharedWith = item.sharedWith ?? ""
                autoRenew = item.autoRenew ?? true
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
                        updated.subtitle = "\(planTier.isEmpty ? "Plan" : planTier) • \(billingCycle.rawValue)"
                        updated.planTier = planTier.isEmpty ? nil : planTier
                        updated.billingCycle = billingCycle.rawValue
                        updated.repeatFrequency = billingCycle
                        updated.amount = Double(amountText.replacingOccurrences(of: ",", with: ""))
                        updated.dueDate = dueDate
                        updated.paymentMethod = paymentMethod.isEmpty ? nil : paymentMethod
                        updated.accountEmail = accountEmail.isEmpty ? nil : accountEmail
                        updated.sharedWith = sharedWith.isEmpty ? nil : sharedWith
                        updated.autoRenew = autoRenew
                        updated.notes = notes.isEmpty ? nil : notes
                        store.updateItem(updated)
                        HapticManager.success()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
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

// MARK: - Vault Theme Colors & Blue Shades

struct VaultThemeOption: Identifiable {
    let id: String
    let name: String
    let previewColor: Color
    let isBlueShade: Bool
}

let vaultCardThemes: [VaultThemeOption] = [
    // Blue Shades (7 rich variations)
    VaultThemeOption(id: "midnight", name: "Midnight", previewColor: Color(red: 0.14, green: 0.32, blue: 0.58), isBlueShade: true),
    VaultThemeOption(id: "navy", name: "Deep Navy", previewColor: Color(red: 0.08, green: 0.18, blue: 0.40), isBlueShade: true),
    VaultThemeOption(id: "sapphire", name: "Sapphire", previewColor: Color(red: 0.12, green: 0.36, blue: 0.82), isBlueShade: true),
    VaultThemeOption(id: "pacific", name: "Pacific Blue", previewColor: Color(red: 0.10, green: 0.44, blue: 0.68), isBlueShade: true),
    VaultThemeOption(id: "arctic", name: "Arctic Cyan", previewColor: Color(red: 0.15, green: 0.55, blue: 0.78), isBlueShade: true),
    VaultThemeOption(id: "steel", name: "Steel Slate", previewColor: Color(red: 0.26, green: 0.36, blue: 0.48), isBlueShade: true),
    VaultThemeOption(id: "sky", name: "Sky Azure", previewColor: Color(red: 0.25, green: 0.55, blue: 0.90), isBlueShade: true),
    
    // Luxury & Classic Shades
    VaultThemeOption(id: "obsidian", name: "Obsidian", previewColor: Color(red: 0.22, green: 0.22, blue: 0.24), isBlueShade: false),
    VaultThemeOption(id: "emerald", name: "Emerald", previewColor: Color(red: 0.12, green: 0.42, blue: 0.28), isBlueShade: false),
    VaultThemeOption(id: "titanium", name: "Titanium", previewColor: Color(red: 0.48, green: 0.52, blue: 0.56), isBlueShade: false),
    VaultThemeOption(id: "purple", name: "Purple", previewColor: Color(red: 0.46, green: 0.16, blue: 0.68), isBlueShade: false),
    VaultThemeOption(id: "roseGold", name: "Rose Gold", previewColor: Color(red: 0.62, green: 0.26, blue: 0.36), isBlueShade: false),
    VaultThemeOption(id: "amber", name: "Warm Bronze", previewColor: Color(red: 0.62, green: 0.38, blue: 0.16), isBlueShade: false)
]

func vaultCardGradient(for themeId: String) -> LinearGradient {
    switch themeId {
    case "navy":
        return LinearGradient(
            colors: [Color(red: 0.04, green: 0.08, blue: 0.20), Color(red: 0.08, green: 0.18, blue: 0.40)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    case "sapphire":
        return LinearGradient(
            colors: [Color(red: 0.04, green: 0.18, blue: 0.52), Color(red: 0.12, green: 0.36, blue: 0.82)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    case "pacific":
        return LinearGradient(
            colors: [Color(red: 0.04, green: 0.22, blue: 0.38), Color(red: 0.10, green: 0.44, blue: 0.68)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    case "arctic":
        return LinearGradient(
            colors: [Color(red: 0.06, green: 0.26, blue: 0.42), Color(red: 0.15, green: 0.55, blue: 0.78)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    case "steel":
        return LinearGradient(
            colors: [Color(red: 0.14, green: 0.20, blue: 0.30), Color(red: 0.26, green: 0.36, blue: 0.48)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    case "sky":
        return LinearGradient(
            colors: [Color(red: 0.08, green: 0.30, blue: 0.60), Color(red: 0.25, green: 0.55, blue: 0.90)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    case "obsidian", "slate":
        return LinearGradient(
            colors: [Color(red: 0.12, green: 0.12, blue: 0.14), Color(red: 0.24, green: 0.24, blue: 0.26)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    case "emerald":
        return LinearGradient(
            colors: [Color(red: 0.05, green: 0.22, blue: 0.16), Color(red: 0.12, green: 0.42, blue: 0.28)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    case "titanium":
        return LinearGradient(
            colors: [Color(red: 0.28, green: 0.30, blue: 0.34), Color(red: 0.48, green: 0.52, blue: 0.56)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    case "purple":
        return LinearGradient(
            colors: [Color(red: 0.22, green: 0.08, blue: 0.38), Color(red: 0.46, green: 0.16, blue: 0.68)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    case "roseGold":
        return LinearGradient(
            colors: [Color(red: 0.38, green: 0.14, blue: 0.22), Color(red: 0.62, green: 0.26, blue: 0.36)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    case "amber":
        return LinearGradient(
            colors: [Color(red: 0.38, green: 0.22, blue: 0.08), Color(red: 0.62, green: 0.38, blue: 0.16)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    default: // midnight or blue
        return LinearGradient(
            colors: [Color(red: 0.08, green: 0.15, blue: 0.32), Color(red: 0.14, green: 0.32, blue: 0.58)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

/// Visual Credit Card Component with Realistic Design, Privacy Masking, and 1-Tap Copy Actions.
struct CreditCardView: View {
    let card: CreditCardAccount
    let onCopy: (_ text: String, _ label: String) -> Void
    var onEdit: (() -> Void)? = nil
    
    @State private var isRevealed: Bool = false
    
    private var cardGradient: LinearGradient {
        vaultCardGradient(for: card.cardTheme)
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
                
                // Security PINs Row (ATM PIN & TPIN)
                if !card.atmPin.isEmpty || !card.tpin.isEmpty {
                    HStack(spacing: 16) {
                        if !card.atmPin.isEmpty {
                            Button(action: {
                                onCopy(card.atmPin, "ATM PIN")
                            }) {
                                HStack(spacing: 4) {
                                    Text("ATM PIN:")
                                        .font(.system(size: 8.5, weight: .bold))
                                        .foregroundColor(.white.opacity(0.65))
                                    Text(isRevealed ? card.atmPin : card.maskedAtmPin)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if !card.tpin.isEmpty {
                            Button(action: {
                                onCopy(card.tpin, "TPIN")
                            }) {
                                HStack(spacing: 4) {
                                    Text("TPIN:")
                                        .font(.system(size: 8.5, weight: .bold))
                                        .foregroundColor(.white.opacity(0.65))
                                    Text(isRevealed ? card.tpin : card.maskedTpin)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
            .padding(18)
            .background(cardGradient)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 5)
            
            // 1-Tap Copy Action Pills Below Card
            ScrollView(.horizontal, showsIndicators: false) {
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
                        .padding(.horizontal, 10)
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
                            .padding(.horizontal, 10)
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
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(UIColor.secondarySystemBackground))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if !card.atmPin.isEmpty {
                        Button(action: {
                            onCopy(card.atmPin, "ATM PIN")
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 10))
                                Text("Copy ATM PIN")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(UIColor.secondarySystemBackground))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if !card.tpin.isEmpty {
                        Button(action: {
                            onCopy(card.tpin, "TPIN")
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.rotation")
                                    .font(.system(size: 10))
                                Text("Copy TPIN")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 10)
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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
}

/// Sheet for adding a new credit or debit card account with full card number, CVV, expiry date, and security PINs.
struct AddCreditCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    var initialCategory: String = "Credit"
    
    @State private var cardCategory = "Credit"
    @State private var bankName = ""
    @State private var cardName = ""
    @State private var cardNumber = ""
    @State private var cardHolderName = "PRABU GANESAN"
    @State private var expiryDate = ""
    @State private var cvv = ""
    @State private var atmPin = ""
    @State private var tpin = ""
    @State private var creditLimitText = ""
    @State private var hasDueDay = false
    @State private var dueDay = 5
    @State private var cardTheme = "midnight"
    
    let commonBanks = ["HDFC Bank", "ICICI Bank", "SBI", "Axis Bank", "Kotak", "Amex", "Standard Chartered", "IndusInd"]
    
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
                
                Section("Security PINs (Optional & Encrypted)") {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.blue)
                            .frame(width: 22)
                        TextField("ATM PIN (4 digits)", text: $atmPin)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: atmPin) { newValue in
                                let clean = newValue.filter { $0.isNumber }
                                atmPin = String(clean.prefix(4))
                            }
                    }
                    
                    HStack {
                        Image(systemName: "lock.rotation")
                            .foregroundColor(.blue)
                            .frame(width: 22)
                        TextField("TPIN / NetBanking PIN (4-6 digits)", text: $tpin)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: tpin) { newValue in
                                let clean = newValue.filter { $0.isNumber }
                                tpin = String(clean.prefix(6))
                            }
                    }
                }
                
                Section("Card Theme Color (Blue Shades & More)") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("BLUE SHADES")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.blue)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(vaultCardThemes.filter { $0.isBlueShade }) { theme in
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(theme.previewColor)
                                                .frame(width: 34, height: 34)
                                            
                                            if cardTheme == theme.id {
                                                Circle()
                                                    .stroke(Color.primary, lineWidth: 2.5)
                                                    .frame(width: 40, height: 40)
                                            }
                                        }
                                        Text(theme.name)
                                            .font(.system(size: 9.5, weight: cardTheme == theme.id ? .bold : .regular))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    .onTapGesture {
                                        HapticManager.selection()
                                        cardTheme = theme.id
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        Divider().padding(.vertical, 2)
                        
                        Text("LUXURY & CLASSIC")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(vaultCardThemes.filter { !$0.isBlueShade }) { theme in
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(theme.previewColor)
                                                .frame(width: 34, height: 34)
                                            
                                            if cardTheme == theme.id {
                                                Circle()
                                                    .stroke(Color.primary, lineWidth: 2.5)
                                                    .frame(width: 40, height: 40)
                                            }
                                        }
                                        Text(theme.name)
                                            .font(.system(size: 9.5, weight: cardTheme == theme.id ? .bold : .regular))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    .onTapGesture {
                                        HapticManager.selection()
                                        cardTheme = theme.id
                                    }
                                }
                            }
                            .padding(.vertical, 4)
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
            .onAppear {
                cardCategory = initialCategory
            }
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
            atmPin: atmPin.trimmingCharacters(in: .whitespaces),
            tpin: tpin.trimmingCharacters(in: .whitespaces),
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
    @State private var atmPin = ""
    @State private var tpin = ""
    @State private var creditLimitText = ""
    @State private var hasDueDay = false
    @State private var dueDay = 5
    @State private var cardTheme = "midnight"
    
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
                
                Section("Security PINs (Optional & Encrypted)") {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.blue)
                            .frame(width: 22)
                        TextField("ATM PIN (4 digits)", text: $atmPin)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: atmPin) { newValue in
                                let clean = newValue.filter { $0.isNumber }
                                atmPin = String(clean.prefix(4))
                            }
                    }
                    
                    HStack {
                        Image(systemName: "lock.rotation")
                            .foregroundColor(.blue)
                            .frame(width: 22)
                        TextField("TPIN / NetBanking PIN (4-6 digits)", text: $tpin)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: tpin) { newValue in
                                let clean = newValue.filter { $0.isNumber }
                                tpin = String(clean.prefix(6))
                            }
                    }
                }
                
                Section("Card Theme Color (Blue Shades & More)") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("BLUE SHADES")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.blue)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(vaultCardThemes.filter { $0.isBlueShade }) { theme in
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(theme.previewColor)
                                                .frame(width: 34, height: 34)
                                            
                                            if cardTheme == theme.id {
                                                Circle()
                                                    .stroke(Color.primary, lineWidth: 2.5)
                                                    .frame(width: 40, height: 40)
                                            }
                                        }
                                        Text(theme.name)
                                            .font(.system(size: 9.5, weight: cardTheme == theme.id ? .bold : .regular))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    .onTapGesture {
                                        HapticManager.selection()
                                        cardTheme = theme.id
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        Divider().padding(.vertical, 2)
                        
                        Text("LUXURY & CLASSIC")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(vaultCardThemes.filter { !$0.isBlueShade }) { theme in
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(theme.previewColor)
                                                .frame(width: 34, height: 34)
                                            
                                            if cardTheme == theme.id {
                                                Circle()
                                                    .stroke(Color.primary, lineWidth: 2.5)
                                                    .frame(width: 40, height: 40)
                                            }
                                        }
                                        Text(theme.name)
                                            .font(.system(size: 9.5, weight: cardTheme == theme.id ? .bold : .regular))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    .onTapGesture {
                                        HapticManager.selection()
                                        cardTheme = theme.id
                                    }
                                }
                            }
                            .padding(.vertical, 4)
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
                atmPin = card.atmPin
                tpin = card.tpin
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
        updated.atmPin = atmPin.trimmingCharacters(in: .whitespaces)
        updated.tpin = tpin.trimmingCharacters(in: .whitespaces)
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
        vaultCardGradient(for: account.accountTheme)
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
                
                // Security PINs Row (TPIN & ATM PIN)
                if !account.tpin.isEmpty || !account.atmPin.isEmpty {
                    HStack(spacing: 16) {
                        if !account.tpin.isEmpty {
                            Button(action: {
                                onCopy(account.tpin, "TPIN / UPI PIN")
                            }) {
                                HStack(spacing: 4) {
                                    Text("TPIN / UPI PIN:")
                                        .font(.system(size: 8.5, weight: .bold))
                                        .foregroundColor(.white.opacity(0.65))
                                    Text(isRevealed ? account.tpin : account.maskedTpin)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if !account.atmPin.isEmpty {
                            Button(action: {
                                onCopy(account.atmPin, "ATM PIN")
                            }) {
                                HStack(spacing: 4) {
                                    Text("ATM PIN:")
                                        .font(.system(size: 8.5, weight: .bold))
                                        .foregroundColor(.white.opacity(0.65))
                                    Text(isRevealed ? account.atmPin : account.maskedAtmPin)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
            .padding(18)
            .background(accountGradient)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 5)
            
            // 1-Tap Copy Quick Action Pills
            ScrollView(.horizontal, showsIndicators: false) {
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
                        .padding(.horizontal, 10)
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
                            .padding(.horizontal, 10)
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
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(UIColor.secondarySystemBackground))
                            .foregroundColor(.teal)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if !account.tpin.isEmpty {
                        Button(action: {
                            onCopy(account.tpin, "TPIN / UPI PIN")
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.rotation")
                                    .font(.system(size: 10))
                                Text("Copy TPIN")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(UIColor.secondarySystemBackground))
                            .foregroundColor(.teal)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if !account.atmPin.isEmpty {
                        Button(action: {
                            onCopy(account.atmPin, "ATM PIN")
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 10))
                                Text("Copy ATM PIN")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 10)
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
    @State private var tpin = ""
    @State private var atmPin = ""
    @State private var accountTheme = "midnight"
    
    let commonBanks = ["HDFC Bank", "ICICI Bank", "SBI", "Axis Bank", "Kotak", "Canara Bank", "Bank of Baroda", "PNB"]
    let accountTypes = ["Savings", "Current", "Salary"]
    
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
                
                Section("UPI ID & Security PINs (Optional)") {
                    TextField("UPI ID (e.g. name@okhdfcbank)", text: $upiId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.emailAddress)
                    
                    HStack {
                        Image(systemName: "lock.rotation")
                            .foregroundColor(.teal)
                            .frame(width: 22)
                        TextField("TPIN / UPI PIN (4-6 digits)", text: $tpin)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: tpin) { newValue in
                                let clean = newValue.filter { $0.isNumber }
                                tpin = String(clean.prefix(6))
                            }
                    }
                    
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.teal)
                            .frame(width: 22)
                        TextField("ATM PIN (4 digits)", text: $atmPin)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: atmPin) { newValue in
                                let clean = newValue.filter { $0.isNumber }
                                atmPin = String(clean.prefix(4))
                            }
                    }
                }
                
                Section("Account Theme Color (Blue Shades & More)") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("BLUE SHADES")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.blue)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(vaultCardThemes.filter { $0.isBlueShade }) { theme in
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(theme.previewColor)
                                                .frame(width: 34, height: 34)
                                            
                                            if accountTheme == theme.id {
                                                Circle()
                                                    .stroke(Color.primary, lineWidth: 2.5)
                                                    .frame(width: 40, height: 40)
                                            }
                                        }
                                        Text(theme.name)
                                            .font(.system(size: 9.5, weight: accountTheme == theme.id ? .bold : .regular))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    .onTapGesture {
                                        HapticManager.selection()
                                        accountTheme = theme.id
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        Divider().padding(.vertical, 2)
                        
                        Text("LUXURY & CLASSIC")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(vaultCardThemes.filter { !$0.isBlueShade }) { theme in
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(theme.previewColor)
                                                .frame(width: 34, height: 34)
                                            
                                            if accountTheme == theme.id {
                                                Circle()
                                                    .stroke(Color.primary, lineWidth: 2.5)
                                                    .frame(width: 40, height: 40)
                                            }
                                        }
                                        Text(theme.name)
                                            .font(.system(size: 9.5, weight: accountTheme == theme.id ? .bold : .regular))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    .onTapGesture {
                                        HapticManager.selection()
                                        accountTheme = theme.id
                                    }
                                }
                            }
                            .padding(.vertical, 4)
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
            accountTheme: accountTheme,
            tpin: tpin.trimmingCharacters(in: .whitespaces),
            atmPin: atmPin.trimmingCharacters(in: .whitespaces)
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
    @State private var tpin = ""
    @State private var atmPin = ""
    @State private var accountTheme = "midnight"
    
    let commonBanks = ["HDFC Bank", "ICICI Bank", "SBI", "Axis Bank", "Kotak", "Canara Bank", "Bank of Baroda", "PNB"]
    let accountTypes = ["Savings", "Current", "Salary"]
    
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
                
                Section("UPI ID & Security PINs (Optional)") {
                    TextField("UPI ID", text: $upiId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.emailAddress)
                    
                    HStack {
                        Image(systemName: "lock.rotation")
                            .foregroundColor(.teal)
                            .frame(width: 22)
                        TextField("TPIN / UPI PIN (4-6 digits)", text: $tpin)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: tpin) { newValue in
                                let clean = newValue.filter { $0.isNumber }
                                tpin = String(clean.prefix(6))
                            }
                    }
                    
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.teal)
                            .frame(width: 22)
                        TextField("ATM PIN (4 digits)", text: $atmPin)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: atmPin) { newValue in
                                let clean = newValue.filter { $0.isNumber }
                                atmPin = String(clean.prefix(4))
                            }
                    }
                }
                
                Section("Account Theme Color (Blue Shades & More)") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("BLUE SHADES")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.blue)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(vaultCardThemes.filter { $0.isBlueShade }) { theme in
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(theme.previewColor)
                                                .frame(width: 34, height: 34)
                                            
                                            if accountTheme == theme.id {
                                                Circle()
                                                    .stroke(Color.primary, lineWidth: 2.5)
                                                    .frame(width: 40, height: 40)
                                            }
                                        }
                                        Text(theme.name)
                                            .font(.system(size: 9.5, weight: accountTheme == theme.id ? .bold : .regular))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    .onTapGesture {
                                        HapticManager.selection()
                                        accountTheme = theme.id
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        Divider().padding(.vertical, 2)
                        
                        Text("LUXURY & CLASSIC")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(vaultCardThemes.filter { !$0.isBlueShade }) { theme in
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(theme.previewColor)
                                                .frame(width: 34, height: 34)
                                            
                                            if accountTheme == theme.id {
                                                Circle()
                                                    .stroke(Color.primary, lineWidth: 2.5)
                                                    .frame(width: 40, height: 40)
                                            }
                                        }
                                        Text(theme.name)
                                            .font(.system(size: 9.5, weight: accountTheme == theme.id ? .bold : .regular))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    .onTapGesture {
                                        HapticManager.selection()
                                        accountTheme = theme.id
                                    }
                                }
                            }
                            .padding(.vertical, 4)
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
                tpin = account.tpin
                atmPin = account.atmPin
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
        updated.tpin = tpin.trimmingCharacters(in: .whitespaces)
        updated.atmPin = atmPin.trimmingCharacters(in: .whitespaces)
        
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
