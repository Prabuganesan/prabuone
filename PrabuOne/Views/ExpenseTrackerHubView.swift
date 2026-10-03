import SwiftUI

/// Dedicated Executive Expense Tracker Hub for Prabu One.
/// Tracks transactions via background iOS Shortcuts (SMS/push automations),
/// Gmail bank alert sync, clipboard parsing, and manual entries.
public struct ExpenseTrackerHubView: View {
    @ObservedObject var store: LifeStore
    @Environment(\.dismiss) private var dismiss
    
    // Sheets & Modals
    @State private var showingAddExpense = false
    @State private var showingSMSParser = false
    @State private var showingShortcutsGuide = false
    @State private var showingGmailSync = false
    @State private var selectedExpenseToEdit: ExpenseTransaction? = nil
    @State private var selectedCategoryFilter: ExpenseCategory? = nil
    @State private var transactionTypeFilter: TransactionType? = nil
    @State private var searchText = ""
    @State private var toastMessage: String? = nil
    
    public init(store: LifeStore) {
        self.store = store
    }
    
    private var filteredExpenses: [ExpenseTransaction] {
        var list = store.expenses
        
        if let cat = selectedCategoryFilter {
            list = list.filter { $0.category == cat }
        }
        
        if let type = transactionTypeFilter {
            list = list.filter { $0.type == type }
        }
        
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.merchantOrPayee.lowercased().contains(query) ||
                $0.category.rawValue.lowercased().contains(query) ||
                ($0.bankOrSource?.lowercased().contains(query) ?? false) ||
                ($0.accountOrCardLast4?.contains(query) ?? false) ||
                ($0.referenceNumber?.lowercased().contains(query) ?? false) ||
                String(format: "%.0f", $0.amount).contains(query)
            }
        }
        
        return list
    }
    
    private var totalSpentThisMonth: Double {
        store.thisMonthExpensesTotal
    }
    
    private var totalIncomeThisMonth: Double {
        store.thisMonthIncomeTotal
    }
    
    private var netCashflowThisMonth: Double {
        totalIncomeThisMonth - totalSpentThisMonth
    }
    
    public var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 18) {
                    // 1. Executive Cashflow Pulse Card
                    cashflowPulseCard
                    
                    // 2. Action Hub (Quick Parse, Add, Gmail, Shortcuts)
                    actionHubRow
                    
                    // 3. Category Spend Carousel
                    categoryBreakdownSection
                    
                    // 4. Search & Filter Bar
                    searchAndFilterSection
                    
                    // 5. Transactions Feed
                    transactionsFeedSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            
            // Toast HUD
            if let toast = toastMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(toast)
                            .font(.system(size: 13.5, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.88))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(radius: 6)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("Expense Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: { showingAddExpense = true }) {
                        Label("Add Expense", systemImage: "plus")
                    }
                    Button(action: { showingSMSParser = true }) {
                        Label("Parse SMS / Text", systemImage: "doc.on.clipboard")
                    }
                    Button(action: { showingGmailSync = true }) {
                        Label("Gmail Bank Alerts Sync", systemImage: "envelope.fill")
                    }
                    Button(action: { showingShortcutsGuide = true }) {
                        Label("iOS Shortcuts Guide", systemImage: "bolt.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 19))
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddEditExpenseSheet(store: store)
        }
        .sheet(item: $selectedExpenseToEdit) { expense in
            AddEditExpenseSheet(store: store, expenseToEdit: expense)
        }
        .sheet(isPresented: $showingSMSParser) {
            SMSPasteParserModal(store: store, onExpenseAdded: { msg in
                showToast(msg)
            })
        }
        .sheet(isPresented: $showingShortcutsGuide) {
            ShortcutsAutomationGuideModal()
        }
        .sheet(isPresented: $showingGmailSync) {
            GmailBankSyncModal(store: store, onSyncComplete: { msg in
                showToast(msg)
            })
        }
    }
    
    // MARK: - 1. Executive Cashflow Pulse Card
    private var cashflowPulseCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 7, height: 7)
                        Text("MONTHLY EXPENSE OUTFLOW")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.75))
                            .tracking(0.6)
                    }
                    
                    Text(formatCurrency(totalSpentThisMonth))
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(store.expenses.count) Total")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.16))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    
                    Text(currentMonthYearString)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }
            }
            
            Divider().background(Color.white.opacity(0.18))
            
            HStack(spacing: 12) {
                // Income / Credits
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.left")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                        Text("Credits / Income")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Text(formatCurrency(totalIncomeThisMonth))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                // Net Cashflow
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 4) {
                        Text("Net Cashflow")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        Image(systemName: netCashflowThisMonth >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(netCashflowThisMonth >= 0 ? .green : .red)
                    }
                    Text(formatCurrency(abs(netCashflowThisMonth)))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(netCashflowThisMonth >= 0 ? .white : .red.opacity(0.9))
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.10, blue: 0.28),
                    Color(red: 0.06, green: 0.06, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - 2. Action Hub Row
    private var actionHubRow: some View {
        HStack(spacing: 10) {
            // 1. Paste & Parse SMS Button
            Button(action: {
                HapticManager.light()
                showingSMSParser = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Parse SMS")
                        .font(.system(size: 12.5, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.blue.opacity(0.14))
                .foregroundColor(.blue)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // 2. Gmail Sync Button
            Button(action: {
                HapticManager.light()
                showingGmailSync = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Gmail Sync")
                        .font(.system(size: 12.5, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.red.opacity(0.12))
                .foregroundColor(.red)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.28), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // 3. iOS Shortcuts Setup Guide Button
            Button(action: {
                HapticManager.light()
                showingShortcutsGuide = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Shortcuts")
                        .font(.system(size: 12.5, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.green.opacity(0.14))
                .foregroundColor(.green)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // 4. Add Manual Button
            Button(action: {
                HapticManager.light()
                showingAddExpense = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - 3. Category Spend Carousel
    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Category Outflow")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                if selectedCategoryFilter != nil {
                    Button(action: {
                        HapticManager.light()
                        selectedCategoryFilter = nil
                    }) {
                        Text("Clear Filter")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            let categoriesData = store.expensesByCategoryThisMonth
            if categoriesData.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "chart.pie.fill")
                        .foregroundColor(.secondary)
                    Text("No transactions logged yet this month. Paste an SMS or trigger a sync.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(categoriesData, id: \.category) { item in
                            let isSelected = selectedCategoryFilter == item.category
                            Button(action: {
                                HapticManager.selection()
                                if selectedCategoryFilter == item.category {
                                    selectedCategoryFilter = nil
                                } else {
                                    selectedCategoryFilter = item.category
                                }
                            }) {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(item.category.color.opacity(0.18))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: item.category.iconName)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(item.category.color)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.category.rawValue)
                                            .font(.system(size: 11.5, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        Text(formatCurrency(item.amount))
                                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                            .foregroundColor(item.category.color)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(isSelected ? item.category.color.opacity(0.16) : Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? item.category.color : Color.secondary.opacity(0.12), lineWidth: isSelected ? 1.5 : 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 4. Search & Filter Bar
    private var searchAndFilterSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                TextField("Search merchant, amount, card, UPI...", text: $searchText)
                    .font(.system(size: 13.5))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            
            // Direction Chips: All vs Debits vs Credits
            HStack(spacing: 8) {
                filterChip(label: "All (\(store.expenses.count))", isSelected: transactionTypeFilter == nil) {
                    transactionTypeFilter = nil
                }
                filterChip(label: "Debits Only", isSelected: transactionTypeFilter == .debit) {
                    transactionTypeFilter = .debit
                }
                filterChip(label: "Credits Only", isSelected: transactionTypeFilter == .credit) {
                    transactionTypeFilter = .credit
                }
                Spacer()
            }
        }
    }
    
    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.selection()
            action()
        }) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
                .foregroundColor(isSelected ? .white : .secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 5. Transactions Feed
    private var transactionsFeedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Transactions (\(filteredExpenses.count))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
            }
            
            if filteredExpenses.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.top, 16)
                    
                    Text("No Expenses Recorded")
                        .font(.system(size: 15, weight: .bold))
                    
                    Text("Use 'Parse SMS' to paste bank alerts or set up the automated iOS Shortcut.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    Button(action: {
                        HapticManager.light()
                        showingSMSParser = true
                    }) {
                        Text("Paste Sample Bank SMS")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredExpenses) { expense in
                        expenseRow(expense)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedExpenseToEdit = expense
                            }
                    }
                }
            }
        }
    }
    
    private func expenseRow(_ expense: ExpenseTransaction) -> some View {
        HStack(spacing: 12) {
            // Category Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(expense.category.color.opacity(0.16))
                    .frame(width: 42, height: 42)
                
                Image(systemName: expense.category.iconName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(expense.category.color)
            }
            
            // Merchant & Account Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(expense.merchantOrPayee)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Import source badge
                    HStack(spacing: 3) {
                        Image(systemName: expense.importSource.iconName)
                            .font(.system(size: 8))
                        Text(expense.importSource.rawValue)
                            .font(.system(size: 8.5, weight: .bold))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(expense.importSource.badgeColor.opacity(0.12))
                    .foregroundColor(expense.importSource.badgeColor)
                    .cornerRadius(4)
                }
                
                HStack(spacing: 6) {
                    Text(expense.relativeDateString)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text(expense.accountLabel)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.formattedSignedAmount)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(expense.type.color)
                
                Text(expense.category.rawValue)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
    
    // MARK: - Helpers
    
    private var currentMonthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    private func showToast(_ msg: String) {
        withAnimation {
            toastMessage = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                toastMessage = nil
            }
        }
    }
}

fileprivate func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencySymbol = "₹"
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "₹0"
}

// MARK: - Add / Edit Expense Sheet
public struct AddEditExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    var expenseToEdit: ExpenseTransaction?
    
    @State private var amountText: String = ""
    @State private var type: TransactionType = .debit
    @State private var category: ExpenseCategory = .foodDining
    @State private var merchantOrPayee: String = ""
    @State private var bankOrSource: String = ""
    @State private var accountOrCardLast4: String = ""
    @State private var referenceNumber: String = ""
    @State private var transactionDate: Date = Date()
    @State private var notes: String = ""
    @State private var showingDeleteConfirm = false
    
    public init(store: LifeStore, expenseToEdit: ExpenseTransaction? = nil) {
        self.store = store
        self.expenseToEdit = expenseToEdit
        
        if let exp = expenseToEdit {
            _amountText = State(initialValue: String(format: "%.2f", exp.amount))
            _type = State(initialValue: exp.type)
            _category = State(initialValue: exp.category)
            _merchantOrPayee = State(initialValue: exp.merchantOrPayee)
            _bankOrSource = State(initialValue: exp.bankOrSource ?? "")
            _accountOrCardLast4 = State(initialValue: exp.accountOrCardLast4 ?? "")
            _referenceNumber = State(initialValue: exp.referenceNumber ?? "")
            _transactionDate = State(initialValue: exp.transactionDate)
            _notes = State(initialValue: exp.notes ?? "")
        }
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Transaction Details") {
                    Picker("Type", selection: $type) {
                        ForEach(TransactionType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text("₹")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.secondary)
                        TextField("Amount (e.g. 450)", text: $amountText)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .keyboardType(.decimalPad)
                    }
                    
                    TextField("Merchant / Payee (e.g. Swiggy, Amazon)", text: $merchantOrPayee)
                    
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.iconName).tag(cat)
                        }
                    }
                    
                    DatePicker("Date & Time", selection: $transactionDate)
                }
                
                Section("Bank / Card Info (Optional)") {
                    TextField("Bank / Source (e.g. HDFC Bank, GPay)", text: $bankOrSource)
                    TextField("Card / Account Last 4 Digits (e.g. 4921)", text: $accountOrCardLast4)
                        .keyboardType(.numberPad)
                    TextField("Reference / UPI UTR Number", text: $referenceNumber)
                }
                
                Section("Notes") {
                    TextField("Additional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
                
                if expenseToEdit != nil {
                    Section {
                        Button(role: .destructive, action: { showingDeleteConfirm = true }) {
                            HStack {
                                Spacer()
                                Text("Delete Transaction")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(expenseToEdit == nil ? "New Expense" : "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveExpense() }
                        .disabled(amountText.isEmpty || merchantOrPayee.isEmpty)
                }
            }
            .alert("Delete Transaction", isPresented: $showingDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    if let exp = expenseToEdit {
                        store.deleteExpense(exp)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to permanently delete this transaction?")
            }
        }
    }
    
    private func saveExpense() {
        guard let amountVal = Double(amountText.replacingOccurrences(of: ",", with: "")), amountVal > 0 else {
            return
        }
        
        if var exp = expenseToEdit {
            exp.amount = amountVal
            exp.type = type
            exp.category = category
            exp.merchantOrPayee = merchantOrPayee
            exp.bankOrSource = bankOrSource.isEmpty ? nil : bankOrSource
            exp.accountOrCardLast4 = accountOrCardLast4.isEmpty ? nil : accountOrCardLast4
            exp.referenceNumber = referenceNumber.isEmpty ? nil : referenceNumber
            exp.transactionDate = transactionDate
            exp.notes = notes.isEmpty ? nil : notes
            store.updateExpense(exp)
        } else {
            let newExp = ExpenseTransaction(
                amount: amountVal,
                type: type,
                category: category,
                merchantOrPayee: merchantOrPayee,
                accountOrCardLast4: accountOrCardLast4.isEmpty ? nil : accountOrCardLast4,
                bankOrSource: bankOrSource.isEmpty ? nil : bankOrSource,
                referenceNumber: referenceNumber.isEmpty ? nil : referenceNumber,
                transactionDate: transactionDate,
                rawTextSnippet: nil,
                importSource: .manual,
                isReviewed: true,
                notes: notes.isEmpty ? nil : notes
            )
            store.addExpense(newExp)
        }
        dismiss()
    }
}

// MARK: - SMS Paste & Test Parser Modal
public struct SMSPasteParserModal: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    var onExpenseAdded: (String) -> Void
    
    @State private var rawText: String = ""
    @State private var parsedResult: ParsedBankingAlert? = nil
    
    private let presetSamples = [
        ("HDFC SMS", "HDFC Bank: Rs 640.00 debited from A/c **4921 to SWIGGY on 03-OCT-26. UPI Ref: 4278190281. Avl Bal: Rs 48,250.00"),
        ("ICICI Card", "Alert: Update on your ICICI Bank Credit Card ending 8124 for INR 2,499.00 spent at AMAZON on 02-OCT-26. Avl Limit: INR 1,45,000.00"),
        ("SBI UPI", "Dear SBI User, your A/C 9876 debited by Rs.2,100.00 on 01-OCT-26 transfer to SHELL PETROL via UPI. Ref 99128301"),
        ("Salary Credit", "HDFC Bank: Salary credited! INR 85,000.00 credited to A/C **4921 by TECH CORP on 30-SEP-26. Avl Bal: INR 1,32,000.00")
    ]
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SMS & Notification Parser")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("Paste any bank SMS, UPI notification, or transactional email to auto-extract amount, merchant, card, and category.")
                            .font(.system(size: 12.5))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                    
                    // Quick Sample Buttons
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tap Sample Bank SMS to Test:")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(presetSamples, id: \.0) { sample in
                                    Button(action: {
                                        HapticManager.selection()
                                        rawText = sample.1
                                        parseCurrentText()
                                    }) {
                                        Text(sample.0)
                                            .font(.system(size: 11.5, weight: .semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.12))
                                            .foregroundColor(.blue)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    
                    // Text Input
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Bank Alert Text")
                                .font(.system(size: 13, weight: .bold))
                            Spacer()
                            Button(action: {
                                if let clip = UIPasteboard.general.string {
                                    rawText = clip
                                    parseCurrentText()
                                    HapticManager.light()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.clipboard")
                                    Text("Paste from Clipboard")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.blue)
                            }
                        }
                        
                        TextEditor(text: $rawText)
                            .frame(height: 110)
                            .padding(8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                            )
                            .onChange(of: rawText) { _ in
                                parseCurrentText()
                            }
                    }
                    
                    // Parsed Output Preview Card
                    if let parsed = parsedResult {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.emeraldAccent)
                                Text("AI / Heuristic Parser Result")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.emeraldAccent)
                                Spacer()
                                Text(parsed.type.rawValue.uppercased())
                                    .font(.system(size: 10, weight: .black))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(parsed.type.color.opacity(0.2))
                                    .foregroundColor(parsed.type.color)
                                    .cornerRadius(4)
                            }
                            
                            Divider()
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                parsedItemTile(title: "Amount", value: parsed.type.sign + "₹" + String(format: "%.2f", parsed.amount), color: parsed.type.color)
                                parsedItemTile(title: "Merchant", value: parsed.merchantOrPayee, color: .primary)
                                parsedItemTile(title: "Category", value: parsed.category.rawValue, color: parsed.category.color)
                                parsedItemTile(title: "Bank / Source", value: parsed.bankOrSource ?? "Auto Detected", color: .blue)
                                if let card = parsed.accountOrCardLast4 {
                                    parsedItemTile(title: "Card / Account", value: "••\(card)", color: .primary)
                                }
                                if let ref = parsed.referenceNumber {
                                    parsedItemTile(title: "Ref / UTR", value: ref, color: .secondary)
                                }
                            }
                            
                            Button(action: {
                                commitParsedExpense(parsed)
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add to Expenses")
                                }
                                .font(.system(size: 15, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.emeraldAccent)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                            }
                            .padding(.top, 4)
                        }
                        .padding(14)
                        .background(Color.emeraldAccent.opacity(0.08))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.emeraldAccent.opacity(0.25), lineWidth: 1)
                        )
                    } else if !rawText.trimmingCharacters(in: .whitespaces).isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("No bank transaction detected. Ensure text has amount and debit/credit status.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("Parse Bank SMS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func parseCurrentText() {
        self.parsedResult = BankingTextParser.parse(rawText)
    }
    
    private func commitParsedExpense(_ parsed: ParsedBankingAlert) {
        let expense = parsed.toExpense(source: .clipboardPaste)
        if store.containsDuplicateExpense(expense) {
            onExpenseAdded("Skipped duplicate: \(expense.merchantOrPayee) already recorded.")
        } else {
            store.addExpense(expense)
            onExpenseAdded("Recorded: \(expense.formattedSignedAmount) for \(expense.merchantOrPayee)")
        }
        dismiss()
    }
    
    private func parsedItemTile(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - iOS Shortcuts Automation Visual Guide Modal
public struct ShortcutsAutomationGuideModal: View {
    @Environment(\.dismiss) private var dismiss
    @State private var copiedURL: Bool = false
    
    private let sampleURLScheme = "prabuone://log-expense?text=[ShortcutInput]"
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Hero Card
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color.green, Color.teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 60, height: 60)
                            Image(systemName: "bolt.badge.automatic.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        
                        Text("100% Automated SMS Expense Tracking")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                        
                        Text("iOS personal automations allow your iPhone to capture bank SMS in real-time as they arrive and automatically record the expense into Prabu One.")
                            .font(.system(size: 12.5))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(18)
                    
                    // Step by step visual instructions
                    VStack(alignment: .leading, spacing: 14) {
                        Text("How to Set Up in iOS Shortcuts (2 Minutes)")
                            .font(.system(size: 15, weight: .bold))
                        
                        guideStepRow(
                            stepNumber: "1",
                            title: "Open Shortcuts App",
                            detail: "Open the native Apple 'Shortcuts' app on your iPhone and tap the 'Automation' tab at the bottom."
                        )
                        
                        guideStepRow(
                            stepNumber: "2",
                            title: "Create Message Automation",
                            detail: "Tap '+' -> Select 'Message' -> Set 'Message Contains' to: debited (or spent, credited)."
                        )
                        
                        guideStepRow(
                            stepNumber: "3",
                            title: "Select 'Run Immediately'",
                            detail: "Choose 'Run Immediately' and turn OFF 'Notify When Run' for completely silent background operation."
                        )
                        
                        guideStepRow(
                            stepNumber: "4",
                            title: "Add App Action",
                            detail: "Search for 'Prabu One' -> select 'Log Bank Expense from SMS', and pass 'Shortcut Input' into the text parameter."
                        )
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // URL Scheme Alternative Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Alternative: URL Scheme Trigger")
                            .font(.system(size: 14, weight: .bold))
                        
                        Text("You can also configure Shortcuts to open the URL:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(sampleURLScheme)
                                .font(.system(size: 11.5, design: .monospaced))
                                .lineLimit(1)
                            Spacer()
                            Button(action: {
                                UIPasteboard.general.string = sampleURLScheme
                                HapticManager.success()
                                copiedURL = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copiedURL = false
                                }
                            }) {
                                Image(systemName: copiedURL ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.06))
                        .cornerRadius(8)
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .navigationTitle("Shortcuts Automation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func guideStepRow(stepNumber: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)
                Text(stepNumber)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(.primary)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Gmail Bank Alerts Sync Modal
public struct GmailBankSyncModal: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    var onSyncComplete: (String) -> Void
    
    @State private var emailBatchText: String = ""
    @State private var isSyncing: Bool = false
    @State private var copiedQuery: Bool = false
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Header Hero
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color.red, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 60, height: 60)
                            Image(systemName: "envelope.badge.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.white)
                        }
                        
                        Text("Gmail Bank Alerts Sync")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        
                        Text("Import bank transaction alerts from HDFC, SBI, ICICI, Axis, Kotak, Swiggy, Amazon, and Cred emails with automatic de-duplication.")
                            .font(.system(size: 12.5))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(18)
                    
                    // 1-Tap Simulated Sync Button
                    Button(action: {
                        performSimulatedSync()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .bold))
                            Text(isSyncing ? "Syncing Alerts..." : "1-Tap Sync Bank Email Alerts")
                                .font(.system(size: 14.5, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: Color.red.opacity(0.3), radius: 5, x: 0, y: 2)
                    }
                    
                    // Gmail Search Filter Helper
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Recommended Gmail Search Query")
                                .font(.system(size: 13, weight: .bold))
                            Spacer()
                            Button(action: {
                                UIPasteboard.general.string = GmailExpenseSyncManager.recommendedGmailSearchQuery
                                HapticManager.success()
                                copiedQuery = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copiedQuery = false
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: copiedQuery ? "checkmark" : "doc.on.doc")
                                    Text(copiedQuery ? "Copied" : "Copy")
                                }
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(.red)
                            }
                        }
                        
                        Text("Copy and paste this into Gmail search bar to find all your bank transaction emails instantly:")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                        
                        Text(GmailExpenseSyncManager.recommendedGmailSearchQuery)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(10)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                    
                    // Batch Email Snippet Paste
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Or Paste Multiple Bank Email Texts:")
                            .font(.system(size: 13, weight: .bold))
                        
                        Text("Separate different alert emails with '---' or newlines.")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $emailBatchText)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                            )
                        
                        Button(action: {
                            importCustomEmailBatch()
                        }) {
                            Text("Import Pasted Emails")
                                .font(.system(size: 13, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(emailBatchText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .navigationTitle("Gmail Alerts Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func performSimulatedSync() {
        isSyncing = true
        HapticManager.light()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let result = GmailExpenseSyncManager.shared.syncSimulatedGmailAlerts(into: store)
            isSyncing = false
            onSyncComplete("Imported \(result.imported) bank emails (\(result.skippedDuplicates) duplicates skipped)")
            dismiss()
        }
    }
    
    private func importCustomEmailBatch() {
        let result = GmailExpenseSyncManager.shared.importRawEmailBatch(text: emailBatchText, into: store)
        onSyncComplete("Imported \(result.imported) transactions (\(result.skippedDuplicates) duplicates skipped)")
        dismiss()
    }
}
