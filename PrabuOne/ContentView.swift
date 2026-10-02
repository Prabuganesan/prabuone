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
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Brand Card
                    HStack(spacing: 14) {
                        Image("Logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Prabu One")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                            Text("Personal Life OS")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 10) {
                            // ☁️ Google Drive Backup Button
                            Button(action: {
                                HapticManager.light()
                                showingGoogleBackupSheet = true
                            }) {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.cyan)
                            }
                            
                            // ⚡ Sudden Quick Note Button
                            Button(action: {
                                HapticManager.light()
                                showingQuickNoteSheet = true
                            }) {
                                Image(systemName: "square.and.pencil.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.amberAccent)
                            }
                            
                            // + Quick Add Life Commitment
                            Button(action: {
                                HapticManager.light()
                                showingAddSheet = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    // 🔍 Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search cards, accounts, loans, LIC, vehicle, docs...", text: $searchText)
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
                        // 🔴 Attention Engine Card
                        let attentionItems = store.itemsNeedingAttention
                        if !attentionItems.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("🔴 \(attentionItems.count) Things Need Attention")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                                
                                VStack(spacing: 10) {
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
                            .padding(16)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.red.opacity(0.25), lineWidth: 1)
                            )
                        } else {
                            // 🟢 All Clear Banner
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("All Clear")
                                        .font(.system(size: 15, weight: .bold))
                                    Text(store.items.isEmpty ? "Tap + to add your cards, vehicle, and bills" : "No urgent payments or renewals due")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(Color.green.opacity(0.08))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.green.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // 💰 Monthly Outflow Overview Card
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("THIS MONTH'S OUTFLOW")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                Text(formatCurrency(store.thisMonthCommitmentTotal))
                                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text("\(store.thisMonthRenewalsCount) upcoming renewals & commitments")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "indianrupeesign.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(18)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(18)
                        
                        // 🧰 Active Utilities (Car Mirror)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Active Utilities")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            
                            NavigationLink(destination: CarMirrorView(captureManager: captureManager)) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(LinearGradient(
                                                colors: [Color.blue, Color.cyan],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ))
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: "car.side.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Car Mirror")
                                                .font(.system(size: 17, weight: .semibold))
                                                .foregroundColor(.primary)
                                            
                                            if captureManager.stats.isCapturing {
                                                Text("LIVE \(String(format: "%.0f", captureManager.stats.fps)) FPS")
                                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.green)
                                                    .foregroundColor(.white)
                                                    .cornerRadius(4)
                                            }
                                        }
                                        
                                        Text("Screen mirroring for vehicle CarPlay display")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color.secondary.opacity(0.6))
                                }
                                .padding(14)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(16)
                            }
                        }
                        
                        // 🏛️ Life Pillars Grid
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Life Pillars")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                NavigationLink(destination: VehicleHubView(store: store)) {
                                    PillarCard(
                                        icon: "car.side.fill",
                                        color: .orange,
                                        title: "Vehicles",
                                        subtitle: "Kia Sonet & Service",
                                        badgeCount: store.items(for: .vehicle).filter { !$0.isCompleted }.count
                                    )
                                }
                                
                                NavigationLink(destination: MoneyHubView(store: store)) {
                                    PillarCard(
                                        icon: "creditcard.fill",
                                        color: .blue,
                                        title: "Money & Cards",
                                        subtitle: "Cards & Payments",
                                        badgeCount: store.creditCards.count + store.bankAccounts.count
                                    )
                                }
                                
                                NavigationLink(destination: SubscriptionsHubView(store: store)) {
                                    PillarCard(
                                        icon: "arrow.triangle.2.circlepath.circle.fill",
                                        color: .purple,
                                        title: "Subscriptions",
                                        subtitle: "OTT, AI & Cloud",
                                        badgeCount: store.items(for: .subscription).filter { !$0.isCompleted }.count
                                    )
                                }
                                
                                NavigationLink(destination: MobileBillsHubView(store: store)) {
                                    PillarCard(
                                        icon: "iphone.gen3",
                                        color: .green,
                                        title: "Mobile & Bills",
                                        subtitle: "SIM & Utility Plans",
                                        badgeCount: store.items(for: .mobileBill).filter { !$0.isCompleted }.count
                                    )
                                }
                                
                                NavigationLink(destination: LifeDatesHubView(store: store)) {
                                    PillarCard(
                                        icon: "gift.fill",
                                        color: .pink,
                                        title: "Birthdays & Life",
                                        subtitle: "Family & Events",
                                        badgeCount: store.items(for: .birthday).filter { !$0.isCompleted }.count
                                    )
                                }
                                
                                NavigationLink(destination: DocumentVaultView(store: store)) {
                                    PillarCard(
                                        icon: "doc.text.fill",
                                        color: .teal,
                                        title: "Document Vault",
                                        subtitle: "RC, PUC & IDs",
                                        badgeCount: store.documents.count
                                    )
                                }
                                
                                NavigationLink(destination: LoansAndLicHubView(store: store)) {
                                    PillarCard(
                                        icon: "building.columns.fill",
                                        color: .indigo,
                                        title: "Loans & LIC",
                                        subtitle: "EMIs & Insurance",
                                        badgeCount: store.loans.count + store.licPolicies.count
                                    )
                                }
                                
                                NavigationLink(destination: QuickNotesHubView(store: store)) {
                                    PillarCard(
                                        icon: "square.and.pencil",
                                        color: .amberAccent,
                                        title: "Quick Notes",
                                        subtitle: "Sudden Thoughts & Memos",
                                        badgeCount: store.quickNotes.count
                                    )
                                }
                                
                                NavigationLink(destination: GoogleBackupView(store: store)) {
                                    PillarCard(
                                        icon: "arrow.triangle.2.circlepath.circle.fill",
                                        color: .cyan,
                                        title: "Google Backup",
                                        subtitle: "Drive Export & Sync",
                                        badgeCount: 0
                                    )
                                }
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
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }
                
                Spacer()
                
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.2))
                        .foregroundColor(color)
                        .clipShape(Capsule())
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    ContentView()
}
