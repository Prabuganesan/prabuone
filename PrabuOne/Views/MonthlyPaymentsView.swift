import SwiftUI

/// Represents the classification of a monthly payment.
public enum PaymentCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case loanEmi = "Loan EMIs"
    case licInsurance = "LIC & Insurance"
    case subscription = "Subscriptions"
    case mobileBill = "Mobile & Bills"
    case creditCard = "Credit Cards"
    case vehicle = "Vehicle"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .all: return "tray.full.fill"
        case .loanEmi: return "building.columns.fill"
        case .licInsurance: return "shield.lefthalf.filled"
        case .subscription: return "play.tv.fill"
        case .mobileBill: return "iphone.gen3"
        case .creditCard: return "creditcard.fill"
        case .vehicle: return "car.side.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .all: return .primary
        case .loanEmi: return .orange
        case .licInsurance: return .emeraldAccent
        case .subscription: return .purple
        case .mobileBill: return .blue
        case .creditCard: return .cyan
        case .vehicle: return .amberAccent
        }
    }
}

/// Represents the payment channel/mode (Auto-Debit, UPI, Card, NetBanking, etc.).
public enum PaymentModeIconType {
    case autoDebit       // ⚡ Auto-Debit (NACH / e-Mandate)
    case upiAutoPay      // 📲 UPI AutoPay (GPay / PhonePe)
    case creditCard      // 💳 Credit Card
    case bankTransfer    // 🏦 NetBanking / IMPS / NEFT
    case inApp           // 🍎 Apple / Google In-App
    case manual          // 🖐️ Manual Payment / Bill Desk
    
    public var icon: String {
        switch self {
        case .autoDebit: return "bolt.shield.fill"
        case .upiAutoPay: return "qrcode.viewfinder"
        case .creditCard: return "creditcard.fill"
        case .bankTransfer: return "building.columns.fill"
        case .inApp: return "applelogo"
        case .manual: return "hand.tap.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .autoDebit: return .green
        case .upiAutoPay: return .teal
        case .creditCard: return .blue
        case .bankTransfer: return .indigo
        case .inApp: return .secondary
        case .manual: return .orange
        }
    }
}

public enum PaymentSourceType {
    case item
    case loan
    case licPolicy
    case creditCard
}

/// A unified representation of any financial payment due in a calendar month.
public struct MonthlyPaymentItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let whatIsThat: String
    public let category: PaymentCategory
    public let amount: Double
    public let dueDate: Date
    public let dueDay: Int
    public var isPaid: Bool
    public let modeOfPayment: String
    public let paymentModeType: PaymentModeIconType
    public let accountOrPolicyNumber: String?
    public let notes: String?
    public let daysRemaining: Int
    public let urgency: UrgencyLevel
    public let sourceId: UUID
    public let sourceType: PaymentSourceType
    
    public var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "₹\(Int(amount))"
    }
    
    public var formattedDueDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: dueDate)
    }
}

/// Comprehensive, single-page command center for all payments due in the current month.
/// Displays what each payment is, the payment mode (Auto-Debit, UPI, Card), and real-time payment status.
public struct MonthlyPaymentsView: View {
    @ObservedObject var store: LifeStore
    @State private var selectedDate: Date = Date()
    @State private var selectedStatusFilter: String = "All"
    @State private var selectedCategory: PaymentCategory = .all
    @State private var searchQuery: String = ""
    @State private var copiedFeedback: String? = nil
    
    public init(store: LifeStore) {
        self.store = store
    }
    
    private var calendar: Calendar {
        Calendar.current
    }
    
    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }
    
    // MARK: - Unified Monthly Payments Aggregator
    
    private var allPaymentsForMonth: [MonthlyPaymentItem] {
        var results: [MonthlyPaymentItem] = []
        
        let targetMonth = calendar.component(.month, from: selectedDate)
        let targetYear = calendar.component(.year, from: selectedDate)
        let today = Date()
        let isCurrentMonth = calendar.isDate(selectedDate, equalTo: today, toGranularity: .month)
        
        // 1. 🏦 Loan EMIs
        for loan in store.loans {
            var comp = calendar.dateComponents([.year, .month], from: selectedDate)
            comp.day = loan.dueDay
            let loanDueDate = calendar.date(from: comp) ?? selectedDate
            
            // Check if there is a corresponding item in items
            let matchingItem = store.items.first(where: {
                $0.category == .loan &&
                $0.title.contains(loan.lenderName) &&
                $0.subtitle.contains(loan.loanName)
            })
            
            let isPaid: Bool = {
                if let item = matchingItem {
                    // If the item's dueDate is past this month, it was already paid/completed for this month
                    let itemMonth = calendar.component(.month, from: item.dueDate)
                    let itemYear = calendar.component(.year, from: item.dueDate)
                    if itemYear > targetYear || (itemYear == targetYear && itemMonth > targetMonth) {
                        return true
                    }
                    return item.isCompleted
                }
                return false
            }()
            
            let daysRem: Int = {
                let startOfToday = calendar.startOfDay(for: today)
                let startOfDue = calendar.startOfDay(for: loanDueDate)
                return calendar.dateComponents([.day], from: startOfToday, to: startOfDue).day ?? 0
            }()
            
            let urgency: UrgencyLevel = {
                if isPaid { return .upcoming }
                if daysRem < 0 { return .overdue }
                if daysRem == 0 { return .today }
                if daysRem <= 3 { return .in3Days }
                if daysRem <= 7 { return .in7Days }
                return .upcoming
            }()
            
            let mode = "⚡ Auto-Debit (NACH Mandate from Salary A/C)"
            let what = "\(loan.loanType) • \(loan.loanName) • A/C #\(loan.accountNumber)"
            
            results.append(
                MonthlyPaymentItem(
                    id: "loan_\(loan.id)",
                    title: "\(loan.lenderName) EMI",
                    whatIsThat: what,
                    category: .loanEmi,
                    amount: loan.emiAmount,
                    dueDate: loanDueDate,
                    dueDay: loan.dueDay,
                    isPaid: isPaid,
                    modeOfPayment: mode,
                    paymentModeType: .autoDebit,
                    accountOrPolicyNumber: loan.accountNumber,
                    notes: loan.notes,
                    daysRemaining: daysRem,
                    urgency: urgency,
                    sourceId: loan.id,
                    sourceType: .loan
                )
            )
        }
        
        // 2. 🛡️ LIC & Insurance Premiums
        for policy in store.licPolicies {
            let pMonth = calendar.component(.month, from: policy.nextDueDate)
            let pYear = calendar.component(.year, from: policy.nextDueDate)
            
            let isDueThisMonth: Bool = {
                switch policy.premiumFrequency.lowercased() {
                case "monthly":
                    return true
                case "quarterly":
                    return abs(targetMonth - pMonth) % 3 == 0
                case "half-yearly":
                    return abs(targetMonth - pMonth) % 6 == 0
                case "yearly", "annual":
                    return pMonth == targetMonth && pYear == targetYear
                default:
                    return pMonth == targetMonth
                }
            }()
            
            if isDueThisMonth {
                var comp = calendar.dateComponents([.year, .month], from: selectedDate)
                comp.day = calendar.component(.day, from: policy.nextDueDate)
                let policyDueDate = calendar.date(from: comp) ?? policy.nextDueDate
                
                let matchingItem = store.items.first(where: {
                    $0.category == .insurance && $0.subtitle.contains(policy.policyNumber)
                })
                
                let isPaid: Bool = {
                    if let item = matchingItem {
                        let itemMonth = calendar.component(.month, from: item.dueDate)
                        let itemYear = calendar.component(.year, from: item.dueDate)
                        if itemYear > targetYear || (itemYear == targetYear && itemMonth > targetMonth) {
                            return true
                        }
                        return item.isCompleted
                    }
                    return false
                }()
                
                let daysRem: Int = {
                    let startOfToday = calendar.startOfDay(for: today)
                    let startOfDue = calendar.startOfDay(for: policyDueDate)
                    return calendar.dateComponents([.day], from: startOfToday, to: startOfDue).day ?? 0
                }()
                
                let urgency: UrgencyLevel = {
                    if isPaid { return .upcoming }
                    if daysRem < 0 { return .overdue }
                    if daysRem == 0 { return .today }
                    if daysRem <= 3 { return .in3Days }
                    if daysRem <= 7 { return .in7Days }
                    return .upcoming
                }()
                
                let mode: String = {
                    if policy.notes?.lowercased().contains("nach") == true || policy.notes?.lowercased().contains("ecs") == true {
                        return "⚡ Auto-Debit / ECS Mandate"
                    }
                    return "🏦 LIC Portal / UPI AutoPay"
                }()
                
                let what = "\(policy.policyType) • \(policy.policyName) • Pol #\(policy.policyNumber) • Cover: ₹\(Int(policy.sumAssured))"
                
                results.append(
                    MonthlyPaymentItem(
                        id: "policy_\(policy.id)",
                        title: "\(policy.insurerName) Premium",
                        whatIsThat: what,
                        category: .licInsurance,
                        amount: policy.premiumAmount,
                        dueDate: policyDueDate,
                        dueDay: calendar.component(.day, from: policyDueDate),
                        isPaid: isPaid,
                        modeOfPayment: mode,
                        paymentModeType: mode.contains("Auto-Debit") ? .autoDebit : .bankTransfer,
                        accountOrPolicyNumber: policy.policyNumber,
                        notes: policy.notes,
                        daysRemaining: daysRem,
                        urgency: urgency,
                        sourceId: policy.id,
                        sourceType: .licPolicy
                    )
                )
            }
        }
        
        // 3. 🍿 Subscriptions, 📱 Bills, and Other Commitments from `store.items`
        for item in store.items {
            // Avoid duplicate loan and policy items
            if item.category == .loan || item.category == .insurance {
                continue
            }
            guard let amount = item.amount, amount > 0 else { continue }
            
            let itemMonth = calendar.component(.month, from: item.dueDate)
            let itemYear = calendar.component(.year, from: item.dueDate)
            
            // Check if item falls in this month or repeats into this month
            let belongsToMonth: Bool = {
                if itemMonth == targetMonth && itemYear == targetYear {
                    return true
                }
                if item.repeatFrequency == .monthly {
                    return true
                }
                if item.repeatFrequency == .quarterly && abs(targetMonth - itemMonth) % 3 == 0 {
                    return true
                }
                if item.repeatFrequency == .halfYearly && abs(targetMonth - itemMonth) % 6 == 0 {
                    return true
                }
                return false
            }()
            
            if belongsToMonth {
                var comp = calendar.dateComponents([.year, .month], from: selectedDate)
                comp.day = calendar.component(.day, from: item.dueDate)
                let adjustedDue = calendar.date(from: comp) ?? item.dueDate
                
                let isPaid: Bool = {
                    if item.repeatFrequency == .never {
                        return item.isCompleted
                    }
                    if itemYear > targetYear || (itemYear == targetYear && itemMonth > targetMonth) {
                        return true
                    }
                    return item.isCompleted
                }()
                
                let daysRem: Int = {
                    let startOfToday = calendar.startOfDay(for: today)
                    let startOfDue = calendar.startOfDay(for: adjustedDue)
                    return calendar.dateComponents([.day], from: startOfToday, to: startOfDue).day ?? 0
                }()
                
                let urgency: UrgencyLevel = {
                    if isPaid { return .upcoming }
                    if daysRem < 0 { return .overdue }
                    if daysRem == 0 { return .today }
                    if daysRem <= 3 { return .in3Days }
                    if daysRem <= 7 { return .in7Days }
                    return .upcoming
                }()
                
                let category: PaymentCategory = {
                    switch item.category {
                    case .subscription: return .subscription
                    case .mobileBill: return .mobileBill
                    case .creditCard: return .creditCard
                    case .vehicle: return .vehicle
                    default: return .mobileBill
                    }
                }()
                
                let mode: String = {
                    if let m = item.paymentMethod, !m.isEmpty {
                        if item.autoRenew == true {
                            return "⚡ Auto-Debit (\(m))"
                        }
                        return m
                    }
                    if item.autoRenew == true {
                        return "⚡ Auto-Debit (e-Mandate)"
                    }
                    return "📲 UPI / Online NetBanking"
                }()
                
                let modeType: PaymentModeIconType = {
                    let lower = mode.lowercased()
                    if lower.contains("auto-debit") || lower.contains("e-mandate") { return .autoDebit }
                    if lower.contains("upi") || lower.contains("pay") { return .upiAutoPay }
                    if lower.contains("card") { return .creditCard }
                    if lower.contains("apple") { return .inApp }
                    return .manual
                }()
                
                let what: String = {
                    var details: [String] = []
                    if let plan = item.planTier, !plan.isEmpty {
                        details.append(plan)
                    }
                    if let email = item.accountEmail, !email.isEmpty {
                        details.append(email)
                    }
                    if let shared = item.sharedWith, !shared.isEmpty {
                        details.append(shared)
                    }
                    if !item.subtitle.isEmpty && !details.contains(item.subtitle) {
                        details.append(item.subtitle)
                    }
                    return details.joined(separator: " • ")
                }()
                
                results.append(
                    MonthlyPaymentItem(
                        id: "item_\(item.id)",
                        title: item.title,
                        whatIsThat: what.isEmpty ? item.category.displayName : what,
                        category: category,
                        amount: amount,
                        dueDate: adjustedDue,
                        dueDay: calendar.component(.day, from: adjustedDue),
                        isPaid: isPaid,
                        modeOfPayment: mode,
                        paymentModeType: modeType,
                        accountOrPolicyNumber: item.accountEmail,
                        notes: item.notes,
                        daysRemaining: daysRem,
                        urgency: urgency,
                        sourceId: item.id,
                        sourceType: .item
                    )
                )
            }
        }
        
        // Sort chronologically by due day (1st to 31st)
        return results.sorted { $0.dueDay < $1.dueDay }
    }
    
    // MARK: - Filtered List
    
    private var filteredPayments: [MonthlyPaymentItem] {
        var list = allPaymentsForMonth
        
        // Status filter
        if selectedStatusFilter == "Pending" {
            list = list.filter { !$0.isPaid }
        } else if selectedStatusFilter == "Paid" {
            list = list.filter { $0.isPaid }
        } else if selectedStatusFilter == "Auto-Debit" {
            list = list.filter { $0.paymentModeType == .autoDebit || $0.modeOfPayment.contains("Auto-Debit") }
        }
        
        // Category filter
        if selectedCategory != .all {
            list = list.filter { $0.category == selectedCategory }
        }
        
        // Search filter
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.title.lowercased().contains(q) ||
                $0.whatIsThat.lowercased().contains(q) ||
                $0.modeOfPayment.lowercased().contains(q) ||
                ($0.accountOrPolicyNumber?.lowercased().contains(q) ?? false) ||
                ($0.notes?.lowercased().contains(q) ?? false)
            }
        }
        
        return list
    }
    
    // MARK: - KPI Metrics
    
    private var totalOutflow: Double {
        allPaymentsForMonth.reduce(0) { $0 + $1.amount }
    }
    
    private var paidSoFar: Double {
        allPaymentsForMonth.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
    }
    
    private var remainingToPay: Double {
        allPaymentsForMonth.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
    }
    
    private var paidCount: Int {
        allPaymentsForMonth.filter { $0.isPaid }.count
    }
    
    private var pendingCount: Int {
        allPaymentsForMonth.filter { !$0.isPaid }.count
    }
    
    private var overdueCount: Int {
        allPaymentsForMonth.filter { !$0.isPaid && $0.daysRemaining < 0 }.count
    }
    
    private var completionPercentage: Double {
        guard totalOutflow > 0 else { return 0 }
        return min(max(paidSoFar / totalOutflow, 0), 1.0)
    }
    
    // MARK: - Body
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 🗓️ Month Navigation Bar
                HStack {
                    Button {
                        HapticManager.selection()
                        adjustMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .padding(10)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(currentMonthName.uppercased())
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Monthly Payment Schedule")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        HapticManager.selection()
                        adjustMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .bold))
                            .padding(10)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                
                // 💰 Executive Monthly Outflow Dashboard Card
                VStack(spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle().fill(Color.orange).frame(width: 7, height: 7)
                                Text("TOTAL OUTFLOW THIS MONTH")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundColor(.white.opacity(0.75))
                                    .tracking(0.5)
                            }
                            
                            Text(formatCurrency(totalOutflow))
                                .font(.system(size: 30, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(allPaymentsForMonth.count) Total Payments")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.18))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                            
                            if overdueCount > 0 {
                                Text("\(overdueCount) Overdue")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.white)
                                    .cornerRadius(6)
                            }
                        }
                    }
                    
                    // Visual Progress Bar
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 8)
                                
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.emeraldAccent, Color.green],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * CGFloat(completionPercentage), height: 8)
                            }
                        }
                        .frame(height: 8)
                        
                        HStack {
                            Text("\(Int(completionPercentage * 100))% Paid")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.emeraldAccent)
                            Spacer()
                            Text("\(pendingCount) Payments Pending")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    // Paid So Far vs Remaining Split
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.green)
                                Text("PAID SO FAR")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            Text(formatCurrency(paidSoFar))
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            Text("\(paidCount) completed")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "hourglass")
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                                Text("REMAINING TO PAY")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            Text(formatCurrency(remainingToPay))
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundColor(.orange)
                            Text("\(pendingCount) pending")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                    }
                }
                .padding(18)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.12, blue: 0.28),
                            Color(red: 0.04, green: 0.06, blue: 0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                
                // 🔍 Search Bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    TextField("Search payee, policy, A/C #, payment mode...", text: $searchQuery)
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
                .padding(.horizontal)
                
                // 🔘 Status Segmented Pills (All, Pending, Paid, Auto-Debit)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        statusFilterButton("All (\(allPaymentsForMonth.count))", filter: "All")
                        statusFilterButton("Pending (\(pendingCount))", filter: "Pending")
                        statusFilterButton("Paid (\(paidCount))", filter: "Paid")
                        statusFilterButton("Auto-Debit Only", filter: "Auto-Debit")
                    }
                    .padding(.horizontal)
                }
                
                // 🏷️ Category Filter Scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PaymentCategory.allCases) { cat in
                            Button {
                                HapticManager.selection()
                                selectedCategory = cat
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 11))
                                    Text(cat.rawValue)
                                        .font(.system(size: 12, weight: selectedCategory == cat ? .bold : .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(selectedCategory == cat ? cat.color : Color(UIColor.secondarySystemBackground))
                                .foregroundColor(selectedCategory == cat ? .white : .primary)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 📋 Payment Cards List
                if filteredPayments.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.emeraldAccent)
                            .padding(.top, 28)
                        
                        Text(selectedStatusFilter == "Pending" ? "All Caught Up!" : "No Payments Found")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        
                        Text(selectedStatusFilter == "Pending" ? "You have zero pending payments due for this month. All obligations are clear." : "No payments match the selected category and search query.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.vertical, 32)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredPayments) { payment in
                            PaymentDetailCard(
                                payment: payment,
                                onToggleStatus: {
                                    togglePaymentStatus(payment)
                                },
                                onCopy: { text in
                                    UIPasteboard.general.string = text
                                    HapticManager.success()
                                    withAnimation {
                                        copiedFeedback = "Copied \(text)"
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation { copiedFeedback = nil }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .navigationTitle("This Month's Payments")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let feedback = copiedFeedback {
                Text(feedback)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.black.opacity(0.88))
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Actions
    
    private func adjustMonth(by offset: Int) {
        if let newDate = calendar.date(byAdding: .month, value: offset, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    private func statusFilterButton(_ title: String, filter: String) -> some View {
        Button {
            HapticManager.selection()
            selectedStatusFilter = filter
        } label: {
            Text(title)
                .font(.system(size: 12, weight: selectedStatusFilter == filter ? .bold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedStatusFilter == filter ? Color.blue : Color(UIColor.secondarySystemBackground))
                .foregroundColor(selectedStatusFilter == filter ? .white : .primary)
                .clipShape(Capsule())
        }
    }
    
    private func togglePaymentStatus(_ payment: MonthlyPaymentItem) {
        HapticManager.success()
        
        switch payment.sourceType {
        case .loan:
            if let loan = store.loans.first(where: { $0.id == payment.sourceId }) {
                store.recordEmiPayment(for: loan)
            }
            if let index = store.items.firstIndex(where: { $0.category == .loan && $0.title.contains(payment.title) }) {
                store.toggleCompleted(store.items[index])
            }
        case .licPolicy:
            if let index = store.items.firstIndex(where: { $0.category == .insurance && $0.subtitle.contains(payment.accountOrPolicyNumber ?? "") }) {
                store.toggleCompleted(store.items[index])
            }
        case .item:
            if let item = store.items.first(where: { $0.id == payment.sourceId }) {
                store.toggleCompleted(item)
            }
        case .creditCard:
            break
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }
}

/// The dedicated visual card showing What It Is, the Payment Mode, Amount, and Live Status.
public struct PaymentDetailCard: View {
    let payment: MonthlyPaymentItem
    let onToggleStatus: () -> Void
    let onCopy: (String) -> Void
    
    private var dayString: String {
        "\(payment.dueDay)"
    }
    
    private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: payment.dueDate).uppercased()
    }
    
    private var weekdayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: payment.dueDate).uppercased()
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                // 📅 Date Badge
                VStack(spacing: 2) {
                    Text(monthString)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(payment.isPaid ? .secondary : payment.category.color)
                    Text(dayString)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(payment.isPaid ? .secondary : .primary)
                    Text(weekdayString)
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .frame(width: 44, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(payment.isPaid ? Color.gray.opacity(0.12) : payment.category.color.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(payment.isPaid ? Color.clear : payment.category.color.opacity(0.25), lineWidth: 1)
                )
                
                // 📝 "What is that" Details & Payee Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(payment.title)
                            .font(.system(size: 15.5, weight: .bold, design: .rounded))
                            .strikethrough(payment.isPaid)
                            .foregroundColor(payment.isPaid ? .secondary : .primary)
                        
                        // Category Pill
                        Text(payment.category.rawValue)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(payment.category.color.opacity(0.16))
                            .foregroundColor(payment.category.color)
                            .clipShape(Capsule())
                    }
                    
                    // Detailed "What is that" description
                    Text(payment.whatIsThat)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 💳 Amount & Interactive Status Button
                VStack(alignment: .trailing, spacing: 4) {
                    Text(payment.formattedAmount)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .strikethrough(payment.isPaid)
                        .foregroundColor(payment.isPaid ? .secondary : .primary)
                    
                    Button(action: onToggleStatus) {
                        HStack(spacing: 4) {
                            Image(systemName: payment.isPaid ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundColor(payment.isPaid ? .green : .orange)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            
            Divider().background(Color.primary.opacity(0.06))
            
            // ⚡ Mode of Payment & Live Status Chips
            HStack(spacing: 8) {
                // Mode of Payment Pill
                HStack(spacing: 4) {
                    Image(systemName: payment.paymentModeType.icon)
                        .font(.system(size: 10))
                        .foregroundColor(payment.paymentModeType.color)
                    Text(payment.modeOfPayment)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.85))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(UIColor.tertiarySystemBackground))
                .clipShape(Capsule())
                
                Spacer()
                
                // Live Status Pill
                if payment.isPaid {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8.5, weight: .black))
                        Text("PAID")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.16))
                    .foregroundColor(.green)
                    .clipShape(Capsule())
                } else if payment.urgency == .overdue {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 8.5))
                        Text("OVERDUE (\(abs(payment.daysRemaining))d)")
                            .font(.system(size: 9.5, weight: .heavy))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.16))
                    .foregroundColor(.red)
                    .clipShape(Capsule())
                } else if payment.urgency == .today {
                    HStack(spacing: 3) {
                        Circle().fill(Color.orange).frame(width: 5, height: 5)
                        Text("DUE TODAY")
                            .font(.system(size: 9.5, weight: .heavy))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.16))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
                } else {
                    Text(payment.daysRemaining == 1 ? "Tomorrow" : "in \(payment.daysRemaining) days")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(payment.urgency == .overdue && !payment.isPaid ? Color.red.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .contextMenu {
            Button {
                onToggleStatus()
            } label: {
                Label(payment.isPaid ? "Mark as Pending (Undo)" : "Mark as Paid", systemImage: payment.isPaid ? "arrow.uturn.backward" : "checkmark.circle")
            }
            
            if let num = payment.accountOrPolicyNumber, !num.isEmpty {
                Button {
                    onCopy(num)
                } label: {
                    Label("Copy Identifier (\(num))", systemImage: "doc.on.doc")
                }
            }
        }
    }
}
