import SwiftUI

/// Main Attention-Driven Dashboard for Prabu One — Personal Life OS.
/// Surfacing what needs immediate attention, monthly commitments, and life pillars.
public struct ContentView: View {
    @StateObject private var store = LifeStore.shared
    @StateObject private var captureManager = ScreenCaptureManager()
    @State private var showingAddSheet = false
    @State private var showingQuickNoteSheet = false
    @State private var selectedItemToEdit: LifeItem? = nil
    @State private var selectedNoteToEdit: QuickNote? = nil
    @State private var searchText = ""
    
    @State private var showingGoogleBackupSheet = false
    @State private var showingQRScanner = false
    @State private var showingDocumentScanner = false
    @State private var showingDeviceHealth = false
    @StateObject private var deviceManager = DeviceHealthManager.shared
    @State private var selectedLoanToEdit: LoanAccount? = nil
    @State private var selectedPolicyToEdit: InsurancePolicyRecord? = nil
    @State private var selectedDocToEdit: DocumentRecord? = nil
    @State private var copiedToastText: String? = nil
    
    public init() {}
    
    // MARK: - Universal Search Across All Data Sources
    
    private var cleanQuery: String {
        searchText.trimmingCharacters(in: .whitespaces).lowercased()
    }
    
    private var cardSearchResults: [CreditCardAccount] {
        guard !cleanQuery.isEmpty else { return [] }
        return store.creditCards.filter {
            $0.bankName.lowercased().contains(cleanQuery) ||
            $0.cardName.lowercased().contains(cleanQuery) ||
            $0.cardHolderName.lowercased().contains(cleanQuery) ||
            $0.cardNumber.contains(cleanQuery) ||
            $0.lastFourDigits.contains(cleanQuery) ||
            $0.cardCategory.lowercased().contains(cleanQuery) ||
            $0.cardNetwork.lowercased().contains(cleanQuery)
        }
    }
    
    private var bankSearchResults: [BankAccount] {
        guard !cleanQuery.isEmpty else { return [] }
        return store.bankAccounts.filter {
            $0.bankName.lowercased().contains(cleanQuery) ||
            $0.accountNumber.contains(cleanQuery) ||
            $0.lastFourDigits.contains(cleanQuery) ||
            $0.accountHolderName.lowercased().contains(cleanQuery) ||
            $0.ifscCode.lowercased().contains(cleanQuery) ||
            $0.upiId.lowercased().contains(cleanQuery) ||
            $0.branchName.lowercased().contains(cleanQuery)
        }
    }
    
    private var loanSearchResults: [LoanAccount] {
        guard !cleanQuery.isEmpty else { return [] }
        return store.loans.filter {
            $0.loanName.lowercased().contains(cleanQuery) ||
            $0.lenderName.lowercased().contains(cleanQuery) ||
            $0.accountNumber.contains(cleanQuery) ||
            $0.loanType.lowercased().contains(cleanQuery) ||
            ($0.notes?.lowercased().contains(cleanQuery) ?? false)
        }
    }
    
    private var licSearchResults: [InsurancePolicyRecord] {
        guard !cleanQuery.isEmpty else { return [] }
        return store.licPolicies.filter {
            $0.policyName.lowercased().contains(cleanQuery) ||
            $0.insurerName.lowercased().contains(cleanQuery) ||
            $0.policyNumber.contains(cleanQuery) ||
            $0.policyType.lowercased().contains(cleanQuery) ||
            $0.policyHolderName.lowercased().contains(cleanQuery) ||
            ($0.notes?.lowercased().contains(cleanQuery) ?? false)
        }
    }
    
    private var docSearchResults: [DocumentRecord] {
        guard !cleanQuery.isEmpty else { return [] }
        return store.documents.filter {
            $0.title.lowercased().contains(cleanQuery) ||
            $0.documentType.lowercased().contains(cleanQuery) ||
            $0.documentNumber.lowercased().contains(cleanQuery) ||
            ($0.notes?.lowercased().contains(cleanQuery) ?? false)
        }
    }
    
    private var vehicleMatches: Bool {
        guard !cleanQuery.isEmpty else { return false }
        let profile = store.vehicleProfile
        return profile.makeModel.lowercased().contains(cleanQuery) ||
            profile.registrationNumber.lowercased().contains(cleanQuery) ||
            profile.fuelType.lowercased().contains(cleanQuery) ||
            profile.serviceHistory.contains(where: {
                $0.title.lowercased().contains(cleanQuery) ||
                $0.serviceCenter.lowercased().contains(cleanQuery) ||
                $0.itemsReplaced.contains(where: { $0.lowercased().contains(cleanQuery) })
            })
    }
    
    private var itemSearchResults: [LifeItem] {
        guard !cleanQuery.isEmpty else { return [] }
        return store.items.filter {
            $0.title.lowercased().contains(cleanQuery) ||
            $0.subtitle.lowercased().contains(cleanQuery) ||
            $0.category.displayName.lowercased().contains(cleanQuery) ||
            ($0.planTier?.lowercased().contains(cleanQuery) ?? false) ||
            ($0.paymentMethod?.lowercased().contains(cleanQuery) ?? false) ||
            ($0.accountEmail?.lowercased().contains(cleanQuery) ?? false) ||
            ($0.notes?.lowercased().contains(cleanQuery) ?? false)
        }
    }
    
    private var noteSearchResults: [QuickNote] {
        guard !cleanQuery.isEmpty else { return [] }
        return store.quickNotes.filter {
            $0.title.lowercased().contains(cleanQuery) ||
            $0.content.lowercased().contains(cleanQuery)
        }
    }
    
    private var totalSearchResultsCount: Int {
        cardSearchResults.count +
        bankSearchResults.count +
        loanSearchResults.count +
        licSearchResults.count +
        docSearchResults.count +
        (vehicleMatches ? 1 : 0) +
        itemSearchResults.count +
        noteSearchResults.count
    }
    
    private func copyToClipboard(text: String, label: String) {
        UIPasteboard.general.string = text
        HapticManager.success()
        withAnimation {
            copiedToastText = "Copied \(label)"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedToastText = nil
            }
        }
    }
    
    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good Morning"
        } else if hour < 17 {
            return "Good Afternoon"
        } else {
            return "Good Evening"
        }
    }
    
    private var formattedTodayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM"
        return formatter.string(from: Date())
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Modern Command Header
                    HStack(alignment: .center, spacing: 14) {
                        ZStack(alignment: .bottomTrailing) {
                            Image("Logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: Color.black.opacity(0.12), radius: 5, x: 0, y: 2)
                            
                            Circle()
                                .fill(Color.emeraldAccent)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 2))
                                .offset(x: 2, y: 2)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(timeGreeting), Prabu")
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 6) {
                                Text(formattedTodayDate)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text("•")
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .font(.system(size: 10))
                                
                                Text("Life OS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 10) {
                            // 🔋 Phone Info & Battery Status Chip (1-Tap opens Device Health)
                            Button(action: {
                                HapticManager.light()
                                showingDeviceHealth = true
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: deviceManager.batteryState == .charging ? "bolt.batteryblock.fill" : (deviceManager.isLowPowerMode ? "battery.50percent" : "battery.100.bolt"))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(deviceManager.batteryPercentage <= 20 ? .red : (deviceManager.isLowPowerMode ? .yellow : .green))
                                    
                                    Text("\(deviceManager.batteryPercentage)%")
                                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            
                            // ⚡ Universal Quick Actions Menu (+ Button)
                            Menu {
                                Section("Quick Add") {
                                    Button(action: {
                                        HapticManager.selection()
                                        showingAddSheet = true
                                    }) {
                                        Label("Add Commitment / Bill", systemImage: "plus.circle.fill")
                                    }
                                    
                                    Button(action: {
                                        HapticManager.selection()
                                        showingQuickNoteSheet = true
                                    }) {
                                        Label("Sudden Quick Note", systemImage: "square.and.pencil")
                                    }
                                }
                                
                                Section("Hardware & Scanners") {
                                    Button(action: {
                                        HapticManager.selection()
                                        showingQRScanner = true
                                    }) {
                                        Label("QR & UPI Scanner", systemImage: "qrcode.viewfinder")
                                    }
                                    
                                    Button(action: {
                                        HapticManager.selection()
                                        showingDocumentScanner = true
                                    }) {
                                        Label("Scan Document (PDF)", systemImage: "doc.viewfinder.fill")
                                    }
                                    
                                    Button(action: {
                                        HapticManager.selection()
                                        showingDeviceHealth = true
                                    }) {
                                        Label("Phone Info & Diagnostics", systemImage: "iphone.gen3")
                                    }
                                }
                                
                                Section("Sync & Backup") {
                                    Button(action: {
                                        HapticManager.selection()
                                        showingGoogleBackupSheet = true
                                    }) {
                                        Label("Google Drive Cloud Backup", systemImage: "arrow.triangle.2.circlepath")
                                    }
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.blue, Color(red: 0.1, green: 0.45, blue: 0.9)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 38, height: 38)
                                        .shadow(color: Color.blue.opacity(0.35), radius: 5, x: 0, y: 2)
                                    
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
                    
                    // 🔍 Modern Floating Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 15, weight: .medium))
                        TextField("Search all 9 pillars, cards, accounts, loans, docs...", text: $searchText)
                            .font(.system(size: 14))
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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                    )
                    
                    if !searchText.isEmpty {
                        // Universal Search Results Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Search Results (\(totalSearchResultsCount) found)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Spacer()
                            }
                            
                            if totalSearchResultsCount == 0 {
                                VStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 36))
                                        .foregroundColor(.secondary)
                                        .padding(.top, 16)
                                    Text("No Details Matching '\(searchText)'")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Searched across cards, bank accounts, loans, LIC policies, vehicle records, documents, notes, and commitments.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 24)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                            } else {
                                // 1. Cards & Bank Accounts
                                if !cardSearchResults.isEmpty || !bankSearchResults.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Cards & Banking (\(cardSearchResults.count + bankSearchResults.count))")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.blue)
                                        
                                        ForEach(cardSearchResults) { card in
                                            NavigationLink(destination: MoneyHubView(store: store)) {
                                                HStack(spacing: 12) {
                                                    Image(systemName: card.isDebit ? "creditcard" : "creditcard.fill")
                                                        .foregroundColor(.blue)
                                                        .frame(width: 22)
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        HStack {
                                                            Text("\(card.bankName) \(card.cardName)")
                                                                .font(.system(size: 14, weight: .semibold))
                                                                .foregroundColor(.primary)
                                                            Text(card.cardCategory.uppercased())
                                                                .font(.system(size: 9, weight: .bold))
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 2)
                                                                .background(Color.blue.opacity(0.15))
                                                                .foregroundColor(.blue)
                                                                .cornerRadius(4)
                                                        }
                                                        
                                                        Text(card.formattedCardNumber)
                                                            .font(.system(size: 12, design: .monospaced))
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    Button(action: {
                                                        copyToClipboard(text: card.cardNumber, label: "\(card.cardName) Number")
                                                    }) {
                                                        Image(systemName: "doc.on.doc")
                                                            .font(.system(size: 13, weight: .semibold))
                                                            .foregroundColor(.blue)
                                                            .padding(6)
                                                            .background(Color.blue.opacity(0.1))
                                                            .clipShape(Circle())
                                                    }
                                                }
                                                .padding(10)
                                                .background(Color(UIColor.secondarySystemBackground))
                                                .cornerRadius(10)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        
                                        ForEach(bankSearchResults) { bank in
                                            NavigationLink(destination: MoneyHubView(store: store)) {
                                                HStack(spacing: 12) {
                                                    Image(systemName: "building.columns.fill")
                                                        .foregroundColor(.indigo)
                                                        .frame(width: 22)
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text("\(bank.bankName) • \(bank.accountHolderName)")
                                                            .font(.system(size: 14, weight: .semibold))
                                                            .foregroundColor(.primary)
                                                        Text("A/C: \(bank.formattedAccountNumber) • IFSC: \(bank.ifscCode)")
                                                            .font(.system(size: 12, design: .monospaced))
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    Button(action: {
                                                        copyToClipboard(text: bank.accountNumber, label: "\(bank.bankName) A/C Number")
                                                    }) {
                                                        Image(systemName: "doc.on.doc")
                                                            .font(.system(size: 13, weight: .semibold))
                                                            .foregroundColor(.indigo)
                                                            .padding(6)
                                                            .background(Color.indigo.opacity(0.1))
                                                            .clipShape(Circle())
                                                    }
                                                }
                                                .padding(10)
                                                .background(Color(UIColor.secondarySystemBackground))
                                                .cornerRadius(10)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                
                                // 2. Loans & EMIs
                                if !loanSearchResults.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Loans & EMIs (\(loanSearchResults.count))")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.red)
                                        
                                        ForEach(loanSearchResults) { loan in
                                            Button(action: {
                                                selectedLoanToEdit = loan
                                            }) {
                                                HStack(spacing: 12) {
                                                    Image(systemName: "indianrupeesign.square.fill")
                                                        .foregroundColor(.red)
                                                        .frame(width: 22)
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        HStack {
                                                            Text("\(loan.lenderName) • \(loan.loanName)")
                                                                .font(.system(size: 14, weight: .semibold))
                                                                .foregroundColor(.primary)
                                                            Text(loan.loanType)
                                                                .font(.system(size: 9, weight: .bold))
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 2)
                                                                .background(Color.red.opacity(0.15))
                                                                .foregroundColor(.red)
                                                                .cornerRadius(4)
                                                        }
                                                        
                                                        Text("EMI: \(formatCurrency(loan.emiAmount))/mo • Due on \(loan.dueDay)th • A/C: \(loan.formattedAccountNumber)")
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    Button(action: {
                                                        copyToClipboard(text: loan.accountNumber, label: "\(loan.loanName) A/C")
                                                    }) {
                                                        Image(systemName: "doc.on.doc")
                                                            .font(.system(size: 13, weight: .semibold))
                                                            .foregroundColor(.red)
                                                            .padding(6)
                                                            .background(Color.red.opacity(0.1))
                                                            .clipShape(Circle())
                                                    }
                                                }
                                                .padding(10)
                                                .background(Color(UIColor.secondarySystemBackground))
                                                .cornerRadius(10)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                
                                // 3. LIC & Insurance Policies
                                if !licSearchResults.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("LIC & Insurance Policies (\(licSearchResults.count))")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.emeraldAccent)
                                        
                                        ForEach(licSearchResults) { policy in
                                            Button(action: {
                                                selectedPolicyToEdit = policy
                                            }) {
                                                HStack(spacing: 12) {
                                                    Image(systemName: "shield.lefthalf.filled")
                                                        .foregroundColor(.emeraldAccent)
                                                        .frame(width: 22)
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        HStack {
                                                            Text("\(policy.insurerName) • \(policy.policyName)")
                                                                .font(.system(size: 14, weight: .semibold))
                                                                .foregroundColor(.primary)
                                                            Text(policy.policyType)
                                                                .font(.system(size: 9, weight: .bold))
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 2)
                                                                .background(Color.emeraldAccent.opacity(0.15))
                                                                .foregroundColor(.emeraldAccent)
                                                                .cornerRadius(4)
                                                        }
                                                        
                                                        Text("Cover: \(formatCurrency(policy.sumAssured)) • Prem: \(formatCurrency(policy.premiumAmount)) • Pol: \(policy.formattedPolicyNumber)")
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    Button(action: {
                                                        copyToClipboard(text: policy.policyNumber, label: "Policy Number")
                                                    }) {
                                                        Image(systemName: "doc.on.doc")
                                                            .font(.system(size: 13, weight: .semibold))
                                                            .foregroundColor(.emeraldAccent)
                                                            .padding(6)
                                                            .background(Color.emeraldAccent.opacity(0.1))
                                                            .clipShape(Circle())
                                                    }
                                                }
                                                .padding(10)
                                                .background(Color(UIColor.secondarySystemBackground))
                                                .cornerRadius(10)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                
                                // 4. Document Vault Items
                                if !docSearchResults.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Document Vault (\(docSearchResults.count))")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.teal)
                                        
                                        ForEach(docSearchResults) { doc in
                                            Button(action: {
                                                selectedDocToEdit = doc
                                            }) {
                                                HStack(spacing: 12) {
                                                    Image(systemName: "doc.text.fill")
                                                        .foregroundColor(.teal)
                                                        .frame(width: 22)
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        HStack {
                                                            Text(doc.title)
                                                                .font(.system(size: 14, weight: .semibold))
                                                                .foregroundColor(.primary)
                                                            Text(doc.documentType)
                                                                .font(.system(size: 9, weight: .bold))
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 2)
                                                                .background(Color.teal.opacity(0.15))
                                                                .foregroundColor(.teal)
                                                                .cornerRadius(4)
                                                        }
                                                        
                                                        Text("ID: \(doc.documentNumber)")
                                                            .font(.system(size: 12, design: .monospaced))
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    Button(action: {
                                                        copyToClipboard(text: doc.documentNumber, label: "\(doc.title) Number")
                                                    }) {
                                                        Image(systemName: "doc.on.doc")
                                                            .font(.system(size: 13, weight: .semibold))
                                                            .foregroundColor(.teal)
                                                            .padding(6)
                                                            .background(Color.teal.opacity(0.1))
                                                            .clipShape(Circle())
                                                    }
                                                }
                                                .padding(10)
                                                .background(Color(UIColor.secondarySystemBackground))
                                                .cornerRadius(10)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                
                                // 5. Vehicle Records
                                if vehicleMatches {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Vehicle Telemetry & Service")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.orange)
                                        
                                        NavigationLink(destination: VehicleHubView(store: store)) {
                                            HStack(spacing: 12) {
                                                Image(systemName: "car.side.fill")
                                                    .foregroundColor(.orange)
                                                    .frame(width: 22)
                                                
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(store.vehicleProfile.makeModel)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.primary)
                                                    Text("Reg: \(store.vehicleProfile.registrationNumber) • Odo: \(store.vehicleProfile.currentOdometerKm) km • Fuel: \(store.vehicleProfile.fuelType)")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                Spacer()
                                                
                                                Button(action: {
                                                    copyToClipboard(text: store.vehicleProfile.registrationNumber, label: "Vehicle Reg Number")
                                                }) {
                                                    Image(systemName: "doc.on.doc")
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(.orange)
                                                        .padding(6)
                                                        .background(Color.orange.opacity(0.1))
                                                        .clipShape(Circle())
                                                }
                                            }
                                            .padding(10)
                                            .background(Color(UIColor.secondarySystemBackground))
                                            .cornerRadius(10)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                
                                // 6. Commitments & Bills
                                if !itemSearchResults.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Commitments & Items (\(itemSearchResults.count))")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.secondary)
                                        
                                        ForEach(itemSearchResults) { item in
                                            AttentionItemRow(item: item, onComplete: {
                                                withAnimation {
                                                    store.toggleCompleted(item)
                                                }
                                            }, onEdit: {
                                                selectedItemToEdit = item
                                            })
                                        }
                                    }
                                }
                                
                                // 7. Quick Notes
                                if !noteSearchResults.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Quick Notes (\(noteSearchResults.count))")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.amberAccent)
                                        
                                        ForEach(noteSearchResults) { note in
                                            Button(action: {
                                                selectedNoteToEdit = note
                                            }) {
                                                HStack(spacing: 12) {
                                                    Image(systemName: "square.and.pencil")
                                                        .foregroundColor(.amberAccent)
                                                        .frame(width: 20)
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(note.displayTitle)
                                                            .font(.system(size: 14, weight: .semibold))
                                                            .foregroundColor(.primary)
                                                        
                                                        if !note.previewSnippet.isEmpty {
                                                            Text(note.previewSnippet)
                                                                .font(.system(size: 12))
                                                                .foregroundColor(.secondary)
                                                                .lineLimit(1)
                                                        }
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(.secondary.opacity(0.4))
                                                }
                                                .padding(12)
                                                .background(Color(UIColor.secondarySystemBackground))
                                                .cornerRadius(12)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        // 💰 Executive Pulse Command Card
                        VStack(spacing: 14) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 7, height: 7)
                                        Text("MONTHLY COMMITMENT PULSE")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white.opacity(0.75))
                                            .tracking(0.6)
                                    }
                                    
                                    Text(formatCurrency(store.thisMonthCommitmentTotal))
                                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(store.thisMonthRenewalsCount) Upcoming")
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.18))
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                    
                                    Text("This Month")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.65))
                                }
                            }
                            
                            Divider().background(Color.white.opacity(0.2))
                            
                            // 4 Key Pulse Metric Tiles (EMIs, LIC Premiums, Life Cover, Cards & Accounts)
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                                microMetricPill(
                                    icon: "indianrupeesign.square.fill",
                                    color: .orange,
                                    label: "Monthly EMIs",
                                    value: formatCurrency(store.totalMonthlyLoanEmi),
                                    subvalue: "\(store.loans.count) Loan\(store.loans.count == 1 ? "" : "s") Active"
                                )
                                
                                microMetricPill(
                                    icon: "shield.lefthalf.filled",
                                    color: .emeraldAccent,
                                    label: "LIC Premiums",
                                    value: "\(formatCurrency(store.totalMonthlyInsurancePremium))/mo",
                                    subvalue: "\(formatCurrency(store.totalAnnualInsurancePremiums))/yr"
                                )
                                
                                microMetricPill(
                                    icon: "heart.text.square.fill",
                                    color: .pink,
                                    label: "Total Life Cover",
                                    value: formatCurrency(store.totalInsuranceSumAssured),
                                    subvalue: "\(store.licPolicies.count) Polic\(store.licPolicies.count == 1 ? "y" : "ies") Active"
                                )
                                
                                microMetricPill(
                                    icon: "creditcard.fill",
                                    color: .cyan,
                                    label: "Cards & Accounts",
                                    value: "\(store.creditCards.count + store.bankAccounts.count) Total",
                                    subvalue: "\(store.creditCards.count) Cards • \(store.bankAccounts.count) A/Cs"
                                )
                            }
                            
                            Divider().background(Color.white.opacity(0.18))
                            
                            // 🗓️ Direct Action to This Month's Payments & Modes View
                            NavigationLink(destination: MonthlyPaymentsView(store: store)) {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("View This Month's Payments & Modes")
                                        .font(.system(size: 12.5, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text("\(store.thisMonthRenewalsCount) Scheduled")
                                        .font(.system(size: 10.5, weight: .bold))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2.5)
                                        .background(Color.white.opacity(0.2))
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(18)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.14, blue: 0.32),
                                    Color(red: 0.04, green: 0.07, blue: 0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 5)
                        
                        // 🔴 Attention Radar Banner
                        let attentionItems = store.itemsNeedingAttention
                        if !attentionItems.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                        Text("\(attentionItems.count) Action\(attentionItems.count > 1 ? "s" : "") Need Attention")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(.red)
                                    }
                                    Spacer()
                                    Text("Due Soon")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.red.opacity(0.8))
                                }
                                
                                VStack(spacing: 8) {
                                    ForEach(attentionItems.prefix(3)) { item in
                                        AttentionItemRow(item: item, onComplete: {
                                            withAnimation {
                                                store.toggleCompleted(item)
                                            }
                                        }, onEdit: {
                                            selectedItemToEdit = item
                                        })
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.red.opacity(0.22), lineWidth: 1)
                            )
                        } else {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.18))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.green)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("All Commitments On Track")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text("No bills or renewals are overdue. Your personal OS is clean.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.green.opacity(0.07))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.green.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // 🚀 Quick Launchpad Bar
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                Button(action: {
                                    HapticManager.light()
                                    showingQRScanner = true
                                }) {
                                    launchpadButton(
                                        icon: "qrcode.viewfinder",
                                        color: .cyan,
                                        label: "QR Scanner",
                                        badge: "UPI"
                                    )
                                    .frame(width: 82)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    HapticManager.light()
                                    showingDocumentScanner = true
                                }) {
                                    launchpadButton(
                                        icon: "doc.viewfinder.fill",
                                        color: .teal,
                                        label: "Doc Scanner",
                                        badge: "PDF"
                                    )
                                    .frame(width: 82)
                                }
                                .buttonStyle(.plain)
                                
                                NavigationLink(destination: CarMirrorView(captureManager: captureManager)) {
                                    launchpadButton(
                                        icon: "car.side.fill",
                                        color: .orange,
                                        label: "Car Mirror",
                                        badge: captureManager.stats.isCapturing ? "LIVE" : nil
                                    )
                                    .frame(width: 82)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    HapticManager.light()
                                    showingQuickNoteSheet = true
                                }) {
                                    launchpadButton(
                                        icon: "square.and.pencil",
                                        color: .amberAccent,
                                        label: "Quick Note",
                                        badge: "\(store.quickNotes.count)"
                                    )
                                    .frame(width: 82)
                                }
                                .buttonStyle(.plain)
                                
                                NavigationLink(destination: DocumentVaultView(store: store)) {
                                    launchpadButton(
                                        icon: "doc.text.fill",
                                        color: .emeraldAccent,
                                        label: "Digital Vault",
                                        badge: "\(store.documents.count)"
                                    )
                                    .frame(width: 82)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    HapticManager.light()
                                    showingDeviceHealth = true
                                }) {
                                    launchpadButton(
                                        icon: "iphone.gen3",
                                        color: .indigo,
                                        label: "Phone Info",
                                        badge: "\(deviceManager.batteryPercentage)%"
                                    )
                                    .frame(width: 82)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    HapticManager.light()
                                    showingGoogleBackupSheet = true
                                }) {
                                    launchpadButton(
                                        icon: "arrow.triangle.2.circlepath",
                                        color: .blue,
                                        label: "Cloud Sync",
                                        badge: nil
                                    )
                                    .frame(width: 82)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // 💳 Section 1: Financial Command Pillars
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Financial Command")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Spacer()
                                Text("Banking & Wealth")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            
                            // 🗓️ Featured This Month's Payments Banner
                            NavigationLink(destination: MonthlyPaymentsView(store: store)) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.orange.opacity(0.25), Color.orange.opacity(0.10)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 42, height: 42)
                                        Image(systemName: "calendar.badge.clock")
                                            .font(.system(size: 19, weight: .bold))
                                            .foregroundColor(.orange)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text("This Month's Payments")
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundColor(.primary)
                                            Text("SCHEDULE")
                                                .font(.system(size: 8.5, weight: .black))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.18))
                                                .foregroundColor(.orange)
                                                .clipShape(Capsule())
                                        }
                                        Text("What to pay • Mode of payment • Live status")
                                            .font(.system(size: 11.5, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.secondary.opacity(0.6))
                                }
                                .padding(12)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                NavigationLink(destination: MoneyHubView(store: store)) {
                                    PillarCard(
                                        icon: "creditcard.fill",
                                        color: .blue,
                                        title: "Money & Cards",
                                        subtitle: "\(store.creditCards.count) Cards • \(store.bankAccounts.count) A/Cs",
                                        badgeCount: store.creditCards.count + store.bankAccounts.count
                                    )
                                }
                                
                                NavigationLink(destination: LoansAndLicHubView(store: store)) {
                                    PillarCard(
                                        icon: "building.columns.fill",
                                        color: .indigo,
                                        title: "Loans & LIC",
                                        subtitle: "\(store.loans.count) Loans • \(store.licPolicies.count) Policies",
                                        badgeCount: store.loans.count + store.licPolicies.count
                                    )
                                }
                                
                                NavigationLink(destination: SubscriptionsHubView(store: store)) {
                                    PillarCard(
                                        icon: "arrow.triangle.2.circlepath.circle.fill",
                                        color: .purple,
                                        title: "Subscriptions",
                                        subtitle: "\(store.items(for: .subscription).count) OTT, AI & Cloud",
                                        badgeCount: store.items(for: .subscription).filter { !$0.isCompleted }.count
                                    )
                                }
                                
                                NavigationLink(destination: MobileBillsHubView(store: store)) {
                                    PillarCard(
                                        icon: "iphone.gen3",
                                        color: .green,
                                        title: "Mobile & Bills",
                                        subtitle: "\(store.items(for: .mobileBill).count) SIM, Fiber & Utility Plans",
                                        badgeCount: store.items(for: .mobileBill).filter { !$0.isCompleted }.count
                                    )
                                }
                            }
                        }
                        
                        // 🛡️ Section 2: Vault, Identity & Life
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Vault & Personal Assets")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Spacer()
                                Text("Protection & Telemetry")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                NavigationLink(destination: VehicleHubView(store: store)) {
                                    PillarCard(
                                        icon: "car.side.fill",
                                        color: .orange,
                                        title: "Vehicles",
                                        subtitle: store.vehicleProfile.makeModel.isEmpty ? "Vehicle & Service" : "\(store.vehicleProfile.makeModel)",
                                        badgeCount: store.items(for: .vehicle).filter { !$0.isCompleted }.count
                                    )
                                }
                                
                                NavigationLink(destination: DocumentVaultView(store: store)) {
                                    PillarCard(
                                        icon: "doc.text.fill",
                                        color: .teal,
                                        title: "Document Vault",
                                        subtitle: "\(store.documents.count) Docs • \(store.documents.filter { $0.hasAttachment }.count) Files",
                                        badgeCount: store.documents.count
                                    )
                                }
                                
                                Button(action: {
                                    HapticManager.light()
                                    showingDocumentScanner = true
                                }) {
                                    PillarCard(
                                        icon: "doc.viewfinder.fill",
                                        color: .teal,
                                        title: "Doc Scanner",
                                        subtitle: "Multi-page • PDF & Enhancer",
                                        badgeCount: 0
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    HapticManager.light()
                                    showingQRScanner = true
                                }) {
                                    PillarCard(
                                        icon: "qrcode.viewfinder",
                                        color: .cyan,
                                        title: "QR Scanner",
                                        subtitle: "UPI Pay • Web • Wi-Fi",
                                        badgeCount: 0
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                NavigationLink(destination: LifeDatesHubView(store: store)) {
                                    PillarCard(
                                        icon: "gift.fill",
                                        color: .pink,
                                        title: "Birthdays & Life",
                                        subtitle: "\(store.items(for: .birthday).count) Family Milestones",
                                        badgeCount: store.items(for: .birthday).filter { !$0.isCompleted }.count
                                    )
                                }
                                
                                NavigationLink(destination: QuickNotesHubView(store: store)) {
                                    PillarCard(
                                        icon: "square.and.pencil",
                                        color: .amberAccent,
                                        title: "Quick Notes",
                                        subtitle: "\(store.quickNotes.count) Memos • \(store.quickNotes.filter { $0.isPinned }.count) Pinned",
                                        badgeCount: store.quickNotes.count
                                    )
                                }
                                
                                NavigationLink(destination: GoogleBackupView(store: store)) {
                                    PillarCard(
                                        icon: "cloud.fill",
                                        color: .cyan,
                                        title: "Google Backup",
                                        subtitle: "Drive Export & Restore",
                                        badgeCount: 0
                                    )
                                }
                                
                                Button(action: {
                                    HapticManager.light()
                                    showingDeviceHealth = true
                                }) {
                                    PillarCard(
                                        icon: "iphone.gen3",
                                        color: .indigo,
                                        title: "Phone & Battery",
                                        subtitle: "\(deviceManager.marketingModel.isEmpty ? "iPhone" : deviceManager.marketingModel) • \(deviceManager.batteryPercentage)% Battery",
                                        badgeCount: 0
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .overlay(alignment: .bottom) {
                if let toast = copiedToastText {
                    HStack(spacing: 8) {
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
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddSheet) {
                AddLifeItemView(store: store)
            }
            .sheet(isPresented: $showingQuickNoteSheet) {
                NoteEditorSheet(store: store, noteToEdit: nil)
            }
            .sheet(isPresented: $showingGoogleBackupSheet) {
                GoogleBackupView(store: store)
            }
            .sheet(isPresented: $showingDeviceHealth) {
                DeviceHealthView()
            }
            .sheet(isPresented: $showingQRScanner) {
                QRScannerView(store: store)
            }
            .sheet(isPresented: $showingDocumentScanner) {
                DocumentScannerView(store: store)
            }
            .sheet(item: $selectedItemToEdit) { item in
                EditLifeItemSheet(store: store, item: item)
            }
            .sheet(item: $selectedNoteToEdit) { note in
                NoteEditorSheet(store: store, noteToEdit: note)
            }
            .sheet(item: $selectedLoanToEdit) { loan in
                EditLoanSheet(store: store, loan: loan)
            }
            .sheet(item: $selectedPolicyToEdit) { policy in
                EditInsurancePolicySheet(store: store, policy: policy)
            }
            .sheet(item: $selectedDocToEdit) { doc in
                EditDocumentSheet(store: store, document: doc)
            }
        }
    }
    
    private func microMetricPill(icon: String, color: Color, label: String, value: String, subvalue: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.75))
            }
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            if let subvalue = subvalue {
                Text(subvalue)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }
    
    private func launchpadButton(icon: String, color: Color, label: String, badge: String?) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 19))
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(badge == "LIVE" ? Color.green : color)
                        .cornerRadius(4)
                        .offset(x: 4, y: -4)
                }
            }
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹0"
    }
}

/// Compact attention row for the top priority card.
struct AttentionItemRow: View {
    let item: LifeItem
    let onComplete: () -> Void
    var onEdit: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                if let onEdit = onEdit {
                    onEdit()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: item.category.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(item.amount != nil ? "\(item.formattedAmount ?? "") • \(item.daysRemainingText)" : item.daysRemainingText)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Button(action: {
                HapticManager.success()
                onComplete()
            }) {
                Text("Mark Done")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(6)
            }
        }
        .padding(10)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .contextMenu {
            if let onEdit = onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("Edit Commitment", systemImage: "pencil")
                }
            }
            
            Button {
                HapticManager.success()
                onComplete()
            } label: {
                Label("Mark as Done", systemImage: "checkmark.circle")
            }
        }
    }
}

/// Grid card for each life pillar.
struct PillarCard: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let badgeCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.22), color.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(color.opacity(0.2), lineWidth: 1)
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    if badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(color.opacity(0.18))
                            .foregroundColor(color)
                            .clipShape(Capsule())
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.secondary.opacity(0.5))
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    ContentView()
}
