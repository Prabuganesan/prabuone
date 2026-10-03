import SwiftUI

fileprivate func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencySymbol = "₹"
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "₹0"
}

public enum FinancialObligationTab: String, CaseIterable {
    case loans = "Loans & EMIs"
    case insurance = "LIC & Policies"
}

/// Dedicated Hub for managing and tracking Loans, EMIs, and LIC/Insurance Policies.
public struct LoansAndLicHubView: View {
    @ObservedObject var store: LifeStore
    @State private var selectedTab: FinancialObligationTab = .loans
    @State private var searchText = ""
    
    // Sheets
    @State private var showingAddLoan = false
    @State private var selectedLoanToEdit: LoanAccount? = nil
    
    @State private var showingAddPolicy = false
    @State private var selectedPolicyToEdit: InsurancePolicyRecord? = nil
    
    // Copy feedback toast
    @State private var copiedToast: String? = nil
    
    public init(store: LifeStore, initialTab: FinancialObligationTab = .loans) {
        self.store = store
        _selectedTab = State(initialValue: initialTab)
    }
    
    private var filteredLoans: [LoanAccount] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty { return store.loans }
        return store.loans.filter {
            $0.loanName.lowercased().contains(query) ||
            $0.lenderName.lowercased().contains(query) ||
            $0.accountNumber.contains(query) ||
            $0.loanType.lowercased().contains(query) ||
            ($0.notes?.lowercased().contains(query) ?? false)
        }
    }
    
    private var filteredPolicies: [InsurancePolicyRecord] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty { return store.licPolicies }
        return store.licPolicies.filter {
            $0.policyName.lowercased().contains(query) ||
            $0.insurerName.lowercased().contains(query) ||
            $0.policyNumber.contains(query) ||
            $0.policyType.lowercased().contains(query) ||
            $0.policyHolderName.lowercased().contains(query) ||
            ($0.notes?.lowercased().contains(query) ?? false)
        }
    }
    
    public var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Segment Picker
                    Picker("Category", selection: $selectedTab) {
                        Text("Loans & EMIs (\(store.loans.count))").tag(FinancialObligationTab.loans)
                        Text("LIC & Policies (\(store.licPolicies.count))").tag(FinancialObligationTab.insurance)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField(selectedTab == .loans ? "Search loans, lenders, account numbers..." : "Search policies, LIC, policy numbers...", text: $searchText)
                            .font(.system(size: 15))
                        if !searchText.isEmpty {
                            Button(action: {
                                HapticManager.light()
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    if selectedTab == .loans {
                        loansContentView
                    } else {
                        licContentView
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            
            // Toast notification
            if let toast = copiedToast {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(toast)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.85))
                    .clipShape(Capsule())
                    .shadow(radius: 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Loans & Insurance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    HapticManager.light()
                    if selectedTab == .loans {
                        showingAddLoan = true
                    } else {
                        showingAddPolicy = true
                    }
                }) {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingAddLoan) {
            AddLoanSheet(store: store)
        }
        .sheet(item: $selectedLoanToEdit) { loan in
            EditLoanSheet(store: store, loan: loan)
        }
        .sheet(isPresented: $showingAddPolicy) {
            AddInsurancePolicySheet(store: store)
        }
        .sheet(item: $selectedPolicyToEdit) { policy in
            EditInsurancePolicySheet(store: store, policy: policy)
        }
    }
    
    // MARK: - Loans Tab Content
    
    private var loansContentView: some View {
        VStack(spacing: 16) {
            // KPI Summary Cards
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL OUTSTANDING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(formatCurrency(store.totalLoanOutstanding))
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundColor(.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("MONTHLY EMI OUTFLOW")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(formatCurrency(store.totalMonthlyLoanEmi))
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
            }
            .padding(.horizontal)
            
            if filteredLoans.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "building.columns.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                        .padding(.top, 36)
                    
                    Text(searchText.isEmpty ? "No Loans Added" : "No Loans Found")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(searchText.isEmpty ? "Keep track of Home, Car, and Personal loans with automatic EMI due date tracking and 1-tap copy." : "Try adjusting your search keywords.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    if searchText.isEmpty {
                        Button(action: {
                            HapticManager.light()
                            showingAddLoan = true
                        }) {
                            Label("Add First Loan", systemImage: "plus")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.vertical, 20)
            } else {
                ForEach(filteredLoans) { loan in
                    LoanCard(loan: loan, onCopy: { text, label in
                        copyToClipboard(text: text, label: label)
                    }, onEdit: {
                        selectedLoanToEdit = loan
                    }, onDelete: {
                        withAnimation {
                            store.deleteLoan(loan)
                        }
                    }, onRecordPayment: {
                        withAnimation {
                            store.recordEmiPayment(for: loan)
                        }
                    })
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - LIC & Insurance Tab Content
    
    private var licContentView: some View {
        VStack(spacing: 16) {
            // KPI Summary Cards
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL SUM ASSURED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(formatCurrency(store.totalInsuranceSumAssured))
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundColor(.emeraldAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("ANNUAL PREMIUMS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(formatCurrency(store.totalAnnualInsurancePremiums))
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
            }
            .padding(.horizontal)
            
            // Upcoming Premiums Banner
            let dueSoonPolicies = store.licPolicies.filter { $0.isDueSoon }
            if !dueSoonPolicies.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(dueSoonPolicies.count) Premium Renewal\(dueSoonPolicies.count > 1 ? "s" : "") Due Soon")
                            .font(.system(size: 14, weight: .bold))
                        Text(dueSoonPolicies.map { "\($0.policyName) (\(formatCurrency($0.premiumAmount)))" }.joined(separator: ", "))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            if filteredPolicies.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 48))
                        .foregroundColor(.emeraldAccent)
                        .padding(.top, 36)
                    
                    Text(searchText.isEmpty ? "No Policies Added" : "No Policies Found")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(searchText.isEmpty ? "Track LIC life policies, health insurance, and vehicle coverage with sum assured, policy numbers, and premium reminders." : "Try adjusting your search keywords.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    if searchText.isEmpty {
                        Button(action: {
                            HapticManager.light()
                            showingAddPolicy = true
                        }) {
                            Label("Add First Policy", systemImage: "plus")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.emeraldAccent)
                                .cornerRadius(12)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.vertical, 20)
            } else {
                ForEach(filteredPolicies) { policy in
                    InsurancePolicyCard(policy: policy, onCopy: { text, label in
                        copyToClipboard(text: text, label: label)
                    }, onEdit: {
                        selectedPolicyToEdit = policy
                    }, onDelete: {
                        withAnimation {
                            store.deleteInsurancePolicy(policy)
                        }
                    })
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private func copyToClipboard(text: String, label: String) {
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

// MARK: - Loan Card Component

struct LoanCard: View {
    let loan: LoanAccount
    let onCopy: (String, String) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onRecordPayment: (() -> Void)? = nil
    
    private var cardGradient: LinearGradient {
        switch loan.theme {
        case "midnight":
            return LinearGradient(colors: [Color(red: 0.12, green: 0.14, blue: 0.20), Color(red: 0.06, green: 0.08, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "emerald":
            return LinearGradient(colors: [Color(red: 0.05, green: 0.32, blue: 0.24), Color(red: 0.02, green: 0.18, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "amber":
            return LinearGradient(colors: [Color(red: 0.42, green: 0.26, blue: 0.08), Color(red: 0.22, green: 0.12, blue: 0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "ruby":
            return LinearGradient(colors: [Color(red: 0.45, green: 0.08, blue: 0.15), Color(red: 0.22, green: 0.04, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: // sapphire
            return LinearGradient(colors: [Color(red: 0.08, green: 0.22, blue: 0.42), Color(red: 0.04, green: 0.11, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: loan.startDate)
    }
    
    private var formattedEndDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: loan.calculatedEndDate)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loan.lenderName.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .tracking(1)
                    
                    Text(loan.loanName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text(loan.loanType)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.18))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            
            // Account Number Row (1-Tap Copy)
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "number.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 14))
                    
                    Text("A/C: \(loan.formattedAccountNumber)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: {
                    onCopy(loan.accountNumber, "Loan Account Number")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 11))
                        Text("Copy")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            // EMI & Due Day Highlights
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MONTHLY EMI")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                    Text(formatCurrency(loan.emiAmount))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("NEXT DUE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                        Text("Day \(loan.dueDay) (\(loan.daysUntilDue == 0 ? "Today" : "In \(loan.daysUntilDue)d"))")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(loan.isDueSoon ? .yellow : .white)
                }
            }
            
            // Repayment Progress & Timeline Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12))
                        Text("\(loan.emisPaid) of \(loan.tenureMonths) EMIs Paid (\(String(format: "%.0f", loan.progressPercentage))%)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("\(loan.remainingEmis) Left")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.18))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 7)
                        Capsule()
                            .fill(LinearGradient(colors: [.green, .mint, .cyan], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, min(geo.size.width * CGFloat(loan.progressPercentage / 100.0), geo.size.width)), height: 7)
                    }
                }
                .frame(height: 7)
                
                HStack {
                    Text("Paid: \(formatCurrency(loan.totalEmiPaidAmount))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Text("To Pay: \(formatCurrency(loan.remainingEmiAmount))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Timeline row
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 10))
                        Text("Start: \(formattedStartDate)")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 10))
                        Text("End: \(formattedEndDate)")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.22))
            .cornerRadius(12)
            
            // Details & Actions Footer
            HStack {
                Text("\(String(format: "%.2f", loan.interestRate))% p.a. • \(loan.tenureMonths / 12)y \(loan.tenureMonths % 12)m")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                HStack(spacing: 10) {
                    if loan.remainingEmis > 0, let recordAction = onRecordPayment {
                        Button(action: recordAction) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 12))
                                Text("+1 Paid")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                    }
                    
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red.opacity(0.85))
                    }
                }
            }
        }
        .padding(18)
        .background(cardGradient)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Insurance Policy Card Component

struct InsurancePolicyCard: View {
    let policy: InsurancePolicyRecord
    let onCopy: (String, String) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var cardGradient: LinearGradient {
        switch policy.theme {
        case "sapphire":
            return LinearGradient(colors: [Color(red: 0.08, green: 0.22, blue: 0.42), Color(red: 0.04, green: 0.11, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "midnight":
            return LinearGradient(colors: [Color(red: 0.12, green: 0.14, blue: 0.20), Color(red: 0.06, green: 0.08, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "ruby":
            return LinearGradient(colors: [Color(red: 0.45, green: 0.08, blue: 0.15), Color(red: 0.22, green: 0.04, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "purple":
            return LinearGradient(colors: [Color(red: 0.32, green: 0.08, blue: 0.42), Color(red: 0.16, green: 0.04, blue: 0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: // emerald
            return LinearGradient(colors: [Color(red: 0.04, green: 0.30, blue: 0.22), Color(red: 0.02, green: 0.16, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private var formattedDueDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: policy.nextDueDate)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(policy.insurerName.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .tracking(1)
                    
                    Text(policy.policyName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text(policy.policyType)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.18))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            
            // Policy Number Row (1-Tap Copy)
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 14))
                    
                    Text("Policy: \(policy.formattedPolicyNumber)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: {
                    onCopy(policy.policyNumber, "Policy Number")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 11))
                        Text("Copy")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            // Sum Assured & Premium
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SUM ASSURED (COVER)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                    Text(formatCurrency(policy.sumAssured))
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("PREMIUM (\(policy.premiumFrequency.uppercased()))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                    Text(formatCurrency(policy.premiumAmount))
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            
            // Due Date Row
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.exclamationmark.fill")
                        .foregroundColor(policy.isOverdue ? .red : (policy.isDueSoon ? .yellow : .white.opacity(0.8)))
                    Text("Next Premium: \(formattedDueDate)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                if policy.isOverdue {
                    Text("OVERDUE")
                        .font(.system(size: 10, weight: .black))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                } else if policy.isDueSoon {
                    Text("DUE IN \(policy.daysUntilDue)D")
                        .font(.system(size: 10, weight: .black))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.2))
            .cornerRadius(10)
            
            // Footer
            HStack {
                Text(policy.policyHolderName.isEmpty ? "Self" : "Holder: \(policy.policyHolderName)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red.opacity(0.85))
                    }
                }
            }
        }
        .padding(18)
        .background(cardGradient)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Add / Edit Loan Sheets

struct AddLoanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var loanName = ""
    @State private var lenderName = ""
    @State private var accountNumber = ""
    @State private var loanType = "Personal Loan"
    
    // Timeline & EMI Tracking
    @State private var startDate = Date()
    @State private var tenureMonths = 36
    @State private var dueDay = 5
    @State private var manualOverride = false
    @State private var manualEmisPaid = 0
    
    // Financial Details
    @State private var totalPrincipalString = ""
    @State private var remainingPrincipalString = ""
    @State private var emiAmountString = ""
    @State private var interestRateString = "8.5"
    @State private var theme = "sapphire"
    @State private var notes = ""
    
    let loanTypes = ["Personal Loan", "Home Loan", "Car Loan", "Gold Loan", "Education Loan", "Business Loan", "Consumer Durable", "Others"]
    let themes = [("Sapphire", "sapphire"), ("Emerald", "emerald"), ("Midnight", "midnight"), ("Amber", "amber"), ("Ruby", "ruby")]
    let tenurePresets = [12, 24, 36, 48, 60, 84, 120, 180, 240, 300, 360]
    
    // MARK: - Auto Calculations
    
    private var calculatedEmisPaid: Int {
        let calendar = Calendar.current
        let today = Date()
        guard startDate <= today else { return 0 }
        
        let startComponents = calendar.dateComponents([.year, .month], from: startDate)
        let currentComponents = calendar.dateComponents([.year, .month], from: today)
        
        guard let startMonthDate = calendar.date(from: startComponents),
              let currentMonthDate = calendar.date(from: currentComponents) else {
            return 0
        }
        
        let monthDiff = calendar.dateComponents([.month], from: startMonthDate, to: currentMonthDate).month ?? 0
        let currentDay = calendar.component(.day, from: today)
        let thisMonthBilled = currentDay >= dueDay ? 1 : 0
        let total = monthDiff + thisMonthBilled
        return min(max(total, 0), tenureMonths)
    }
    
    private var effectiveEmisPaid: Int {
        if manualOverride {
            return min(max(manualEmisPaid, 0), tenureMonths)
        }
        return calculatedEmisPaid
    }
    
    private var remainingEmis: Int {
        max(0, tenureMonths - effectiveEmisPaid)
    }
    
    private var calculatedEndDate: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .month, value: tenureMonths, to: startDate) ?? startDate
    }
    
    private var calculatedEndDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: calculatedEndDate)
    }
    
    private var progressPercent: Double {
        guard tenureMonths > 0 else { return 0 }
        return (Double(effectiveEmisPaid) / Double(tenureMonths)) * 100.0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Loan Information") {
                    TextField("Lender / Bank Name (e.g. HDFC Bank, SBI)", text: $lenderName)
                    TextField("Loan Name (e.g. Car Loan, Home Loan)", text: $loanName)
                    Picker("Loan Type", selection: $loanType) {
                        ForEach(loanTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    TextField("Loan Account Number", text: $accountNumber)
                        .keyboardType(.numbersAndPunctuation)
                }
                
                Section {
                    DatePicker("Loan Start Date (Disbursal)", selection: $startDate, displayedComponents: [.date])
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Tenure")
                            Spacer()
                            Text("\(tenureMonths) Months (\(tenureMonths / 12)y \(tenureMonths % 12)m)")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        Stepper("", value: $tenureMonths, in: 6...360, step: 6)
                            .labelsHidden()
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tenurePresets, id: \.self) { months in
                                    Button(action: {
                                        HapticManager.selection()
                                        tenureMonths = months
                                    }) {
                                        Text("\(months)m")
                                            .font(.system(size: 12, weight: tenureMonths == months ? .bold : .medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(tenureMonths == months ? Color.blue : Color(UIColor.tertiarySystemBackground))
                                            .foregroundColor(tenureMonths == months ? .white : .primary)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    Picker("Monthly EMI Due Day", selection: $dueDay) {
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day)th of every month").tag(day)
                        }
                    }
                    
                    // Auto Calculation Live Summary Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.blue)
                            Text("Auto-Calculated Repayment Status")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("EMIs Paid So Far")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text("\(effectiveEmisPaid) of \(tenureMonths) (\(String(format: "%.0f", progressPercent))%)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Remaining EMIs")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text("\(remainingEmis) EMIs Left")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        HStack {
                            Text("Loan Closure Date:")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(calculatedEndDateString)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(12)
                    
                    Toggle("Adjust EMIs Paid Manually", isOn: $manualOverride)
                        .onChange(of: manualOverride) { enabled in
                            if enabled && manualEmisPaid == 0 {
                                manualEmisPaid = calculatedEmisPaid
                            }
                        }
                    
                    if manualOverride {
                        Stepper("Manual EMIs Paid: \(manualEmisPaid)", value: $manualEmisPaid, in: 0...tenureMonths)
                    }
                } header: {
                    Text("Timeline & Auto-Calculation")
                } footer: {
                    Text("Prabu One calculates EMIs paid, remaining payments, and loan closure date automatically from the start date.")
                }
                
                Section("Financial Details (₹)") {
                    TextField("Monthly EMI Amount (e.g. 18500)", text: $emiAmountString)
                        .keyboardType(.decimalPad)
                    TextField("Sanctioned Amount (Optional, e.g. 800000)", text: $totalPrincipalString)
                        .keyboardType(.decimalPad)
                    TextField("Current Balance Outstanding (Optional)", text: $remainingPrincipalString)
                        .keyboardType(.decimalPad)
                    TextField("Interest Rate % p.a. (e.g. 8.75)", text: $interestRateString)
                        .keyboardType(.decimalPad)
                }
                
                Section("Card Theme") {
                    Picker("Theme", selection: $theme) {
                        ForEach(themes, id: \.1) { name, code in
                            Text(name).tag(code)
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Optional notes (e.g. Branch, Repayment Mode)", text: $notes)
                }
            }
            .navigationTitle("Add New Loan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLoan()
                    }
                    .disabled(lenderName.trimmingCharacters(in: .whitespaces).isEmpty || loanName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveLoan() {
        let emi = Double(emiAmountString) ?? 0
        let total = (Double(totalPrincipalString) ?? 0) > 0 ? (Double(totalPrincipalString) ?? 0) : Double(tenureMonths) * emi
        let rate = Double(interestRateString) ?? 8.5
        
        let remaining: Double
        if let userRemaining = Double(remainingPrincipalString), userRemaining > 0 {
            remaining = userRemaining
        } else if total > 0 {
            let paidRatio = Double(effectiveEmisPaid) / Double(max(1, tenureMonths))
            remaining = max(0, total * (1.0 - paidRatio))
        } else {
            remaining = Double(remainingEmis) * emi
        }
        
        let loan = LoanAccount(
            loanName: loanName.trimmingCharacters(in: .whitespaces),
            lenderName: lenderName.trimmingCharacters(in: .whitespaces),
            accountNumber: accountNumber.trimmingCharacters(in: .whitespaces),
            loanType: loanType,
            totalPrincipal: total,
            remainingPrincipal: remaining,
            emiAmount: emi,
            interestRate: rate,
            dueDay: dueDay,
            tenureMonths: tenureMonths,
            startDate: startDate,
            endDate: calculatedEndDate,
            emisPaidOverride: manualOverride ? manualEmisPaid : nil,
            theme: theme,
            notes: notes.isEmpty ? nil : notes
        )
        store.addLoan(loan)
        dismiss()
    }
}

struct EditLoanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    let loan: LoanAccount
    
    @State private var loanName: String
    @State private var lenderName: String
    @State private var accountNumber: String
    @State private var loanType: String
    
    // Timeline & EMI Tracking
    @State private var startDate: Date
    @State private var tenureMonths: Int
    @State private var dueDay: Int
    @State private var manualOverride: Bool
    @State private var manualEmisPaid: Int
    
    // Financial Details
    @State private var totalPrincipalString: String
    @State private var remainingPrincipalString: String
    @State private var emiAmountString: String
    @State private var interestRateString: String
    @State private var theme: String
    @State private var notes: String
    
    let loanTypes = ["Personal Loan", "Home Loan", "Car Loan", "Gold Loan", "Education Loan", "Business Loan", "Consumer Durable", "Others"]
    let themes = [("Sapphire", "sapphire"), ("Emerald", "emerald"), ("Midnight", "midnight"), ("Amber", "amber"), ("Ruby", "ruby")]
    let tenurePresets = [12, 24, 36, 48, 60, 84, 120, 180, 240, 300, 360]
    
    init(store: LifeStore, loan: LoanAccount) {
        self.store = store
        self.loan = loan
        _loanName = State(initialValue: loan.loanName)
        _lenderName = State(initialValue: loan.lenderName)
        _accountNumber = State(initialValue: loan.accountNumber)
        _loanType = State(initialValue: loan.loanType)
        _startDate = State(initialValue: loan.startDate)
        _tenureMonths = State(initialValue: loan.tenureMonths)
        _dueDay = State(initialValue: loan.dueDay)
        _manualOverride = State(initialValue: loan.emisPaidOverride != nil)
        _manualEmisPaid = State(initialValue: loan.emisPaid)
        _totalPrincipalString = State(initialValue: String(format: "%.0f", loan.totalPrincipal))
        _remainingPrincipalString = State(initialValue: String(format: "%.0f", loan.remainingPrincipal))
        _emiAmountString = State(initialValue: String(format: "%.0f", loan.emiAmount))
        _interestRateString = State(initialValue: String(format: "%.2f", loan.interestRate))
        _theme = State(initialValue: loan.theme)
        _notes = State(initialValue: loan.notes ?? "")
    }
    
    // MARK: - Auto Calculations
    
    private var calculatedEmisPaid: Int {
        let calendar = Calendar.current
        let today = Date()
        guard startDate <= today else { return 0 }
        
        let startComponents = calendar.dateComponents([.year, .month], from: startDate)
        let currentComponents = calendar.dateComponents([.year, .month], from: today)
        
        guard let startMonthDate = calendar.date(from: startComponents),
              let currentMonthDate = calendar.date(from: currentComponents) else {
            return 0
        }
        
        let monthDiff = calendar.dateComponents([.month], from: startMonthDate, to: currentMonthDate).month ?? 0
        let currentDay = calendar.component(.day, from: today)
        let thisMonthBilled = currentDay >= dueDay ? 1 : 0
        let total = monthDiff + thisMonthBilled
        return min(max(total, 0), tenureMonths)
    }
    
    private var effectiveEmisPaid: Int {
        if manualOverride {
            return min(max(manualEmisPaid, 0), tenureMonths)
        }
        return calculatedEmisPaid
    }
    
    private var remainingEmis: Int {
        max(0, tenureMonths - effectiveEmisPaid)
    }
    
    private var calculatedEndDate: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .month, value: tenureMonths, to: startDate) ?? startDate
    }
    
    private var calculatedEndDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: calculatedEndDate)
    }
    
    private var progressPercent: Double {
        guard tenureMonths > 0 else { return 0 }
        return (Double(effectiveEmisPaid) / Double(tenureMonths)) * 100.0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Loan Information") {
                    TextField("Lender / Bank Name", text: $lenderName)
                    TextField("Loan Name", text: $loanName)
                    Picker("Loan Type", selection: $loanType) {
                        ForEach(loanTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    TextField("Loan Account Number", text: $accountNumber)
                        .keyboardType(.numbersAndPunctuation)
                }
                
                Section {
                    DatePicker("Loan Start Date (Disbursal)", selection: $startDate, displayedComponents: [.date])
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Tenure")
                            Spacer()
                            Text("\(tenureMonths) Months (\(tenureMonths / 12)y \(tenureMonths % 12)m)")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        Stepper("", value: $tenureMonths, in: 6...360, step: 6)
                            .labelsHidden()
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tenurePresets, id: \.self) { months in
                                    Button(action: {
                                        HapticManager.selection()
                                        tenureMonths = months
                                    }) {
                                        Text("\(months)m")
                                            .font(.system(size: 12, weight: tenureMonths == months ? .bold : .medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(tenureMonths == months ? Color.blue : Color(UIColor.tertiarySystemBackground))
                                            .foregroundColor(tenureMonths == months ? .white : .primary)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    Picker("Monthly EMI Due Day", selection: $dueDay) {
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day)th of every month").tag(day)
                        }
                    }
                    
                    // Auto Calculation Live Summary Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.blue)
                            Text("Auto-Calculated Repayment Status")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("EMIs Paid So Far")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text("\(effectiveEmisPaid) of \(tenureMonths) (\(String(format: "%.0f", progressPercent))%)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Remaining EMIs")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text("\(remainingEmis) EMIs Left")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        HStack {
                            Text("Loan Closure Date:")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(calculatedEndDateString)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(12)
                    
                    Toggle("Adjust EMIs Paid Manually", isOn: $manualOverride)
                        .onChange(of: manualOverride) { enabled in
                            if enabled && manualEmisPaid == 0 {
                                manualEmisPaid = calculatedEmisPaid
                            }
                        }
                    
                    if manualOverride {
                        Stepper("Manual EMIs Paid: \(manualEmisPaid)", value: $manualEmisPaid, in: 0...tenureMonths)
                    }
                } header: {
                    Text("Timeline & Auto-Calculation")
                } footer: {
                    Text("Prabu One calculates EMIs paid, remaining payments, and loan closure date automatically from the start date.")
                }
                
                Section("Financial Details (₹)") {
                    TextField("Monthly EMI Amount", text: $emiAmountString)
                        .keyboardType(.decimalPad)
                    TextField("Sanctioned Amount", text: $totalPrincipalString)
                        .keyboardType(.decimalPad)
                    TextField("Current Balance Outstanding", text: $remainingPrincipalString)
                        .keyboardType(.decimalPad)
                    TextField("Interest Rate % p.a.", text: $interestRateString)
                        .keyboardType(.decimalPad)
                }
                
                Section("Card Theme") {
                    Picker("Theme", selection: $theme) {
                        ForEach(themes, id: \.1) { name, code in
                            Text(name).tag(code)
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Notes", text: $notes)
                }
                
                Section {
                    Button(role: .destructive, action: {
                        store.deleteLoan(loan)
                        dismiss()
                    }) {
                        HStack {
                            Spacer()
                            Text("Delete Loan")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Loan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateLoan()
                    }
                }
            }
        }
    }
    
    private func updateLoan() {
        let emi = Double(emiAmountString) ?? loan.emiAmount
        let total = Double(totalPrincipalString) ?? loan.totalPrincipal
        let rate = Double(interestRateString) ?? loan.interestRate
        
        let remaining: Double
        if let userRemaining = Double(remainingPrincipalString), userRemaining > 0 {
            remaining = userRemaining
        } else if total > 0 {
            let paidRatio = Double(effectiveEmisPaid) / Double(max(1, tenureMonths))
            remaining = max(0, total * (1.0 - paidRatio))
        } else {
            remaining = Double(remainingEmis) * emi
        }
        
        var updated = loan
        updated.loanName = loanName.trimmingCharacters(in: .whitespaces)
        updated.lenderName = lenderName.trimmingCharacters(in: .whitespaces)
        updated.accountNumber = accountNumber.trimmingCharacters(in: .whitespaces)
        updated.loanType = loanType
        updated.totalPrincipal = total
        updated.remainingPrincipal = remaining
        updated.emiAmount = emi
        updated.interestRate = rate
        updated.dueDay = dueDay
        updated.tenureMonths = tenureMonths
        updated.startDate = startDate
        updated.endDate = calculatedEndDate
        updated.emisPaidOverride = manualOverride ? manualEmisPaid : nil
        updated.theme = theme
        updated.notes = notes.isEmpty ? nil : notes
        
        store.updateLoan(updated)
        dismiss()
    }
}

// MARK: - Add / Edit LIC Sheets

struct AddInsurancePolicySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var insurerName = "Life Insurance Corporation of India (LIC)"
    @State private var policyName = ""
    @State private var policyNumber = ""
    @State private var policyType = "Life Insurance"
    @State private var sumAssuredString = ""
    @State private var premiumAmountString = ""
    @State private var premiumFrequency = "Yearly"
    @State private var nextDueDate = Date().addingTimeInterval(86400 * 90)
    @State private var hasMaturityDate = false
    @State private var maturityDate = Date().addingTimeInterval(86400 * 365 * 15)
    @State private var policyHolderName = ""
    @State private var theme = "emerald"
    @State private var notes = ""
    
    let insurers = ["Life Insurance Corporation of India (LIC)", "HDFC Life", "ICICI Prudential", "Star Health", "Max Life", "Tata AIG", "Care Health", "SBI Life", "Bajaj Allianz", "Others"]
    let policyTypes = ["Life Insurance", "Term Life", "Health / Mediclaim", "Vehicle Insurance", "Endowment Plan", "Pension / Annuity", "ULIP", "Others"]
    let frequencies = ["Yearly", "Half-Yearly", "Quarterly", "Monthly"]
    let themes = [("Emerald", "emerald"), ("Sapphire", "sapphire"), ("Ruby", "ruby"), ("Purple", "purple"), ("Midnight", "midnight")]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Policy Information") {
                    Picker("Insurer", selection: $insurerName) {
                        ForEach(insurers, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    TextField("Policy Name (e.g. Jeevan Labh)", text: $policyName)
                    Picker("Policy Type", selection: $policyType) {
                        ForEach(policyTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    TextField("Policy Number", text: $policyNumber)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Policy Holder Name", text: $policyHolderName)
                }
                
                Section("Coverage & Premium (₹)") {
                    TextField("Sum Assured / Coverage (e.g. 10000000)", text: $sumAssuredString)
                        .keyboardType(.decimalPad)
                    TextField("Premium Amount (e.g. 24500)", text: $premiumAmountString)
                        .keyboardType(.decimalPad)
                    Picker("Premium Frequency", selection: $premiumFrequency) {
                        ForEach(frequencies, id: \.self) { freq in
                            Text(freq).tag(freq)
                        }
                    }
                }
                
                Section("Dates") {
                    DatePicker("Next Premium Due Date", selection: $nextDueDate, displayedComponents: [.date])
                    Toggle("Has Maturity Date", isOn: $hasMaturityDate)
                    if hasMaturityDate {
                        DatePicker("Maturity Date", selection: $maturityDate, displayedComponents: [.date])
                    }
                }
                
                Section("Card Theme") {
                    Picker("Theme", selection: $theme) {
                        ForEach(themes, id: \.1) { name, code in
                            Text(name).tag(code)
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Optional notes (e.g. Agent Name, Portal Login)", text: $notes)
                }
            }
            .navigationTitle("Add Insurance / LIC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePolicy()
                    }
                    .disabled(policyName.trimmingCharacters(in: .whitespaces).isEmpty || policyNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func savePolicy() {
        let sum = Double(sumAssuredString) ?? 0
        let premium = Double(premiumAmountString) ?? 0
        
        let policy = InsurancePolicyRecord(
            policyName: policyName.trimmingCharacters(in: .whitespaces),
            insurerName: insurerName.trimmingCharacters(in: .whitespaces),
            policyNumber: policyNumber.trimmingCharacters(in: .whitespaces),
            policyType: policyType,
            sumAssured: sum,
            premiumAmount: premium,
            premiumFrequency: premiumFrequency,
            nextDueDate: nextDueDate,
            maturityDate: hasMaturityDate ? maturityDate : nil,
            policyHolderName: policyHolderName.trimmingCharacters(in: .whitespaces),
            theme: theme,
            notes: notes.isEmpty ? nil : notes
        )
        store.addInsurancePolicy(policy)
        dismiss()
    }
}

struct EditInsurancePolicySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    let policy: InsurancePolicyRecord
    
    @State private var insurerName: String
    @State private var policyName: String
    @State private var policyNumber: String
    @State private var policyType: String
    @State private var sumAssuredString: String
    @State private var premiumAmountString: String
    @State private var premiumFrequency: String
    @State private var nextDueDate: Date
    @State private var hasMaturityDate: Bool
    @State private var maturityDate: Date
    @State private var policyHolderName: String
    @State private var theme: String
    @State private var notes: String
    
    let insurers = ["Life Insurance Corporation of India (LIC)", "HDFC Life", "ICICI Prudential", "Star Health", "Max Life", "Tata AIG", "Care Health", "SBI Life", "Bajaj Allianz", "Others"]
    let policyTypes = ["Life Insurance", "Term Life", "Health / Mediclaim", "Vehicle Insurance", "Endowment Plan", "Pension / Annuity", "ULIP", "Others"]
    let frequencies = ["Yearly", "Half-Yearly", "Quarterly", "Monthly"]
    let themes = [("Emerald", "emerald"), ("Sapphire", "sapphire"), ("Ruby", "ruby"), ("Purple", "purple"), ("Midnight", "midnight")]
    
    init(store: LifeStore, policy: InsurancePolicyRecord) {
        self.store = store
        self.policy = policy
        _insurerName = State(initialValue: policy.insurerName)
        _policyName = State(initialValue: policy.policyName)
        _policyNumber = State(initialValue: policy.policyNumber)
        _policyType = State(initialValue: policy.policyType)
        _sumAssuredString = State(initialValue: String(format: "%.0f", policy.sumAssured))
        _premiumAmountString = State(initialValue: String(format: "%.0f", policy.premiumAmount))
        _premiumFrequency = State(initialValue: policy.premiumFrequency)
        _nextDueDate = State(initialValue: policy.nextDueDate)
        _hasMaturityDate = State(initialValue: policy.maturityDate != nil)
        _maturityDate = State(initialValue: policy.maturityDate ?? Date().addingTimeInterval(86400 * 365 * 10))
        _policyHolderName = State(initialValue: policy.policyHolderName)
        _theme = State(initialValue: policy.theme)
        _notes = State(initialValue: policy.notes ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Policy Information") {
                    Picker("Insurer", selection: $insurerName) {
                        ForEach(insurers, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    TextField("Policy Name", text: $policyName)
                    Picker("Policy Type", selection: $policyType) {
                        ForEach(policyTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    TextField("Policy Number", text: $policyNumber)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Policy Holder Name", text: $policyHolderName)
                }
                
                Section("Coverage & Premium (₹)") {
                    TextField("Sum Assured / Coverage", text: $sumAssuredString)
                        .keyboardType(.decimalPad)
                    TextField("Premium Amount", text: $premiumAmountString)
                        .keyboardType(.decimalPad)
                    Picker("Premium Frequency", selection: $premiumFrequency) {
                        ForEach(frequencies, id: \.self) { freq in
                            Text(freq).tag(freq)
                        }
                    }
                }
                
                Section("Dates") {
                    DatePicker("Next Premium Due Date", selection: $nextDueDate, displayedComponents: [.date])
                    Toggle("Has Maturity Date", isOn: $hasMaturityDate)
                    if hasMaturityDate {
                        DatePicker("Maturity Date", selection: $maturityDate, displayedComponents: [.date])
                    }
                }
                
                Section("Card Theme") {
                    Picker("Theme", selection: $theme) {
                        ForEach(themes, id: \.1) { name, code in
                            Text(name).tag(code)
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Notes", text: $notes)
                }
                
                Section {
                    Button(role: .destructive, action: {
                        store.deleteInsurancePolicy(policy)
                        dismiss()
                    }) {
                        HStack {
                            Spacer()
                            Text("Delete Policy")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Insurance Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updatePolicy()
                    }
                }
            }
        }
    }
    
    private func updatePolicy() {
        var updated = policy
        updated.insurerName = insurerName.trimmingCharacters(in: .whitespaces)
        updated.policyName = policyName.trimmingCharacters(in: .whitespaces)
        updated.policyNumber = policyNumber.trimmingCharacters(in: .whitespaces)
        updated.policyType = policyType
        updated.sumAssured = Double(sumAssuredString) ?? policy.sumAssured
        updated.premiumAmount = Double(premiumAmountString) ?? policy.premiumAmount
        updated.premiumFrequency = premiumFrequency
        updated.nextDueDate = nextDueDate
        updated.maturityDate = hasMaturityDate ? maturityDate : nil
        updated.policyHolderName = policyHolderName.trimmingCharacters(in: .whitespaces)
        updated.theme = theme
        updated.notes = notes.isEmpty ? nil : notes
        
        store.updateInsurancePolicy(updated)
        dismiss()
    }
}
