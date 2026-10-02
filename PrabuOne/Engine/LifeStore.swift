import Foundation
import Combine
import SwiftUI

/// Central observable store managing all personal life events, commitments, vehicle telemetry, and documents.
@MainActor
public final class LifeStore: ObservableObject {
    public static let shared = LifeStore()
    
    // Core Collections
    @Published public var items: [LifeItem] = [] { didSet { saveToDisk() } }
    @Published public var creditCards: [CreditCardAccount] = [] { didSet { saveCardsToDisk() } }
    @Published public var bankAccounts: [BankAccount] = [] { didSet { saveBankAccountsToDisk() } }
    @Published public var loans: [LoanAccount] = [] { didSet { saveLoansToDisk() } }
    @Published public var licPolicies: [InsurancePolicyRecord] = [] { didSet { savePoliciesToDisk() } }
    @Published public var vehicleProfile: VehicleProfile = VehicleProfile() { didSet { saveVehicleToDisk() } }
    @Published public var documents: [DocumentRecord] = [] { didSet { saveDocumentsToDisk() } }
    @Published public var quickNotes: [QuickNote] = [] { didSet { saveNotesToDisk() } }
    
    private let itemsFileName = "prabuone_life_items.json"
    private let cardsFileName = "prabuone_credit_cards.json"
    private let bankAccountsFileName = "prabuone_bank_accounts.json"
    private let loansFileName = "prabuone_loans.json"
    private let insuranceFileName = "prabuone_insurance.json"
    private let vehicleFileName = "prabuone_vehicle.json"
    private let documentsFileName = "prabuone_documents.json"
    private let notesFileName = "prabuone_notes.json"
    
    public init() {
        loadFromDisk()
        ReminderEngine.shared.requestAuthorization()
    }
    
    // MARK: - Queries
    
    /// Items that are either overdue, due today, or due within the next 7 days.
    public var itemsNeedingAttention: [LifeItem] {
        items
            .filter { !$0.isCompleted && $0.daysRemaining <= 7 }
            .sorted { $0.dueDate < $1.dueDate }
    }
    
    /// Total financial outflow committed for the current calendar month.
    public var thisMonthCommitmentTotal: Double {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        
        return items
            .filter { item in
                guard !item.isCompleted, let _ = item.amount else { return false }
                let itemMonth = calendar.component(.month, from: item.dueDate)
                let itemYear = calendar.component(.year, from: item.dueDate)
                return itemMonth == currentMonth && itemYear == currentYear
            }
            .compactMap { $0.amount }
            .reduce(0, +)
    }
    
    /// Count of renewals and events happening in the current calendar month.
    public var thisMonthRenewalsCount: Int {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        
        return items.filter { item in
            guard !item.isCompleted else { return false }
            let itemMonth = calendar.component(.month, from: item.dueDate)
            let itemYear = calendar.component(.year, from: item.dueDate)
            return itemMonth == currentMonth && itemYear == currentYear
        }.count
    }
    
    /// Returns items filtered by category.
    public func items(for category: LifeCategory) -> [LifeItem] {
        items.filter { $0.category == category }
    }
    
    // MARK: - Mutations (LifeItems)
    
    public func addItem(_ item: LifeItem) {
        items.append(item)
        ReminderEngine.shared.scheduleReminders(for: item)
    }
    
    public func updateItem(_ item: LifeItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            ReminderEngine.shared.scheduleReminders(for: item)
        }
    }
    
    public func deleteItem(at offsets: IndexSet) {
        for index in offsets {
            let item = items[index]
            ReminderEngine.shared.cancelReminders(for: item)
        }
        items.remove(atOffsets: offsets)
    }
    
    public func deleteItem(_ item: LifeItem) {
        ReminderEngine.shared.cancelReminders(for: item)
        items.removeAll { $0.id == item.id }
    }
    
    public func toggleCompleted(_ item: LifeItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = items[index]
        
        if updated.repeatFrequency == .monthly {
            if let nextDate = Calendar.current.date(byAdding: .month, value: 1, to: updated.dueDate) {
                updated.dueDate = nextDate
                updated.isCompleted = false
            }
        } else if updated.repeatFrequency == .yearly {
            if let nextDate = Calendar.current.date(byAdding: .year, value: 1, to: updated.dueDate) {
                updated.dueDate = nextDate
                updated.isCompleted = false
            }
        } else {
            updated.isCompleted.toggle()
        }
        
        items[index] = updated
        if updated.isCompleted {
            ReminderEngine.shared.cancelReminders(for: updated)
        } else {
            ReminderEngine.shared.scheduleReminders(for: updated)
        }
    }
    
    // MARK: - Mutations (Credit Cards)
    
    public func addCreditCard(_ card: CreditCardAccount) {
        creditCards.append(card)
        HapticManager.success()
        if let dueDay = card.dueDay {
            let cardItem = LifeItem(
                title: "\(card.bankName) \(card.cardName)",
                subtitle: "Ending in \(card.lastFourDigits) • Exp: \(card.expiryDate)",
                category: .creditCard,
                dueDate: nextDateForDay(dueDay),
                repeatFrequency: .monthly
            )
            addItem(cardItem)
        }
    }
    
    public func deleteCreditCard(_ card: CreditCardAccount) {
        HapticManager.light()
        creditCards.removeAll { $0.id == card.id }
        // Also remove associated life items
        items.removeAll { $0.category == .creditCard && $0.title.contains(card.cardName) }
    }
    
    public func updateCreditCard(_ card: CreditCardAccount) {
        guard let index = creditCards.firstIndex(where: { $0.id == card.id }) else { return }
        creditCards[index] = card
        HapticManager.success()
        // Synchronize with LifeItem
        if let dueDay = card.dueDay {
            if let itemIndex = items.firstIndex(where: { $0.category == .creditCard && $0.title.contains(card.cardName) }) {
                items[itemIndex].title = "\(card.bankName) \(card.cardName)"
                items[itemIndex].subtitle = "Ending in \(card.lastFourDigits) • Exp: \(card.expiryDate)"
                items[itemIndex].dueDate = nextDateForDay(dueDay)
                ReminderEngine.shared.scheduleReminders(for: items[itemIndex])
            }
        }
    }
    
    // MARK: - Mutations (Bank Accounts)
    
    public func addBankAccount(_ account: BankAccount) {
        bankAccounts.append(account)
        HapticManager.success()
    }
    
    public func updateBankAccount(_ account: BankAccount) {
        if let index = bankAccounts.firstIndex(where: { $0.id == account.id }) {
            bankAccounts[index] = account
            HapticManager.success()
        }
    }
    
    public func deleteBankAccount(_ account: BankAccount) {
        HapticManager.light()
        bankAccounts.removeAll { $0.id == account.id }
    }
    
    // MARK: - Mutations (Loans)
    
    public var totalLoanOutstanding: Double {
        loans.reduce(0) { total, loan in
            if loan.remainingPrincipal > 0 {
                return total + loan.remainingPrincipal
            } else {
                return total + loan.remainingEmiAmount
            }
        }
    }
    
    public var totalMonthlyLoanEmi: Double {
        loans.reduce(0) { $0 + $1.emiAmount }
    }
    
    public func recordEmiPayment(for loan: LoanAccount) {
        if let index = loans.firstIndex(where: { $0.id == loan.id }) {
            var updated = loans[index]
            let newPaid = updated.emisPaid + 1
            if newPaid <= updated.tenureMonths {
                updated.emisPaidOverride = newPaid
                if updated.remainingPrincipal >= updated.emiAmount {
                    updated.remainingPrincipal -= updated.emiAmount
                }
                updateLoan(updated)
            }
        }
    }
    
    public func addLoan(_ loan: LoanAccount) {
        loans.append(loan)
        HapticManager.success()
        // Register or sync monthly EMI in attention list
        let emiItem = LifeItem(
            title: "\(loan.lenderName) EMI",
            subtitle: "\(loan.loanName) • Due on \(loan.dueDay)th",
            category: .loan,
            dueDate: loan.nextDueDate,
            amount: loan.emiAmount,
            repeatFrequency: .monthly
        )
        if !items.contains(where: { $0.category == .loan && $0.title.contains(loan.lenderName) && $0.subtitle.contains(loan.loanName) }) {
            addItem(emiItem)
        }
    }
    
    public func updateLoan(_ loan: LoanAccount) {
        if let index = loans.firstIndex(where: { $0.id == loan.id }) {
            loans[index] = loan
            HapticManager.success()
            if let itemIndex = items.firstIndex(where: { $0.category == .loan && $0.title.contains(loan.lenderName) && $0.subtitle.contains(loan.loanName) }) {
                items[itemIndex].title = "\(loan.lenderName) EMI"
                items[itemIndex].subtitle = "\(loan.loanName) • Due on \(loan.dueDay)th"
                items[itemIndex].amount = loan.emiAmount
                items[itemIndex].dueDate = loan.nextDueDate
                ReminderEngine.shared.scheduleReminders(for: items[itemIndex])
            }
        }
    }
    
    public func deleteLoan(_ loan: LoanAccount) {
        HapticManager.light()
        loans.removeAll { $0.id == loan.id }
        items.removeAll { $0.category == .loan && $0.title.contains(loan.lenderName) && $0.subtitle.contains(loan.loanName) }
    }
    
    // MARK: - Mutations (LIC & Insurance)
    
    public var totalInsuranceSumAssured: Double {
        licPolicies.reduce(0) { $0 + $1.sumAssured }
    }
    
    public var totalAnnualInsurancePremiums: Double {
        licPolicies.reduce(0) { total, policy in
            switch policy.premiumFrequency.lowercased() {
            case "monthly": return total + (policy.premiumAmount * 12)
            case "quarterly": return total + (policy.premiumAmount * 4)
            case "half-yearly": return total + (policy.premiumAmount * 2)
            default: return total + policy.premiumAmount
            }
        }
    }
    
    public func addInsurancePolicy(_ policy: InsurancePolicyRecord) {
        licPolicies.append(policy)
        HapticManager.success()
        let freq: RepeatFrequency = {
            switch policy.premiumFrequency.lowercased() {
            case "monthly": return .monthly
            case "yearly", "annual": return .yearly
            default: return .never
            }
        }()
        let policyItem = LifeItem(
            title: "\(policy.insurerName) Premium",
            subtitle: "\(policy.policyName) • Pol: \(policy.policyNumber)",
            category: .insurance,
            dueDate: policy.nextDueDate,
            amount: policy.premiumAmount,
            repeatFrequency: freq
        )
        if !items.contains(where: { $0.category == .insurance && $0.subtitle.contains(policy.policyNumber) }) {
            addItem(policyItem)
        }
    }
    
    public func updateInsurancePolicy(_ policy: InsurancePolicyRecord) {
        if let index = licPolicies.firstIndex(where: { $0.id == policy.id }) {
            licPolicies[index] = policy
            HapticManager.success()
            if let itemIndex = items.firstIndex(where: { $0.category == .insurance && $0.subtitle.contains(policy.policyNumber) }) {
                items[itemIndex].title = "\(policy.insurerName) Premium"
                items[itemIndex].subtitle = "\(policy.policyName) • Pol: \(policy.policyNumber)"
                items[itemIndex].amount = policy.premiumAmount
                items[itemIndex].dueDate = policy.nextDueDate
                ReminderEngine.shared.scheduleReminders(for: items[itemIndex])
            }
        }
    }
    
    public func deleteInsurancePolicy(_ policy: InsurancePolicyRecord) {
        HapticManager.light()
        licPolicies.removeAll { $0.id == policy.id }
        items.removeAll { $0.category == .insurance && $0.subtitle.contains(policy.policyNumber) }
    }
    
    // MARK: - Mutations (Vehicle)
    
    public func updateOdometer(newKm: Int) {
        vehicleProfile.currentOdometerKm = newKm
        HapticManager.success()
    }
    
    public func updateNextServiceKm(newKm: Int) {
        vehicleProfile.nextServiceDueKm = newKm
        HapticManager.success()
    }
    
    public func updateInsuranceExpiry(newDate: Date) {
        vehicleProfile.insuranceExpiryDate = newDate
        HapticManager.success()
        // Sync or create LifeItem for Insurance
        if let itemIndex = items.firstIndex(where: { $0.category == .vehicle && $0.title.contains("Insurance") }) {
            items[itemIndex].dueDate = newDate
            ReminderEngine.shared.scheduleReminders(for: items[itemIndex])
        } else {
            let item = LifeItem(
                title: "\(vehicleProfile.makeModel) Insurance",
                subtitle: "Policy Renewal",
                category: .vehicle,
                dueDate: newDate,
                repeatFrequency: .yearly
            )
            addItem(item)
        }
    }
    
    public func updatePUCExpiry(newDate: Date) {
        vehicleProfile.pucExpiryDate = newDate
        HapticManager.success()
        // Sync or create LifeItem for PUC
        if let itemIndex = items.firstIndex(where: { $0.category == .document && $0.title.contains("PUC") }) {
            items[itemIndex].dueDate = newDate
            ReminderEngine.shared.scheduleReminders(for: items[itemIndex])
        } else {
            let item = LifeItem(
                title: "\(vehicleProfile.makeModel) PUC Certificate",
                subtitle: "Pollution Expiry",
                category: .document,
                dueDate: newDate,
                repeatFrequency: .yearly
            )
            addItem(item)
        }
    }
    
    public func updateFastagBalance(newBalance: Double) {
        vehicleProfile.fastagBalance = newBalance
        HapticManager.success()
    }
    
    public func updateVehicleInfo(makeModel: String, regNo: String, fuelType: String) {
        vehicleProfile.makeModel = makeModel
        vehicleProfile.registrationNumber = regNo
        vehicleProfile.fuelType = fuelType
        HapticManager.success()
    }
    
    public func updateFullVehicleProfile(_ profile: VehicleProfile) {
        vehicleProfile = profile
        HapticManager.success()
    }
    
    public func addServiceRecord(_ record: VehicleServiceRecord) {
        vehicleProfile.serviceHistory.insert(record, at: 0)
        vehicleProfile.currentOdometerKm = max(vehicleProfile.currentOdometerKm, record.odometerKm)
        vehicleProfile.nextServiceDueKm = record.odometerKm + 10000
        HapticManager.success()
    }
    
    public func updateServiceRecord(_ record: VehicleServiceRecord) {
        if let index = vehicleProfile.serviceHistory.firstIndex(where: { $0.id == record.id }) {
            vehicleProfile.serviceHistory[index] = record
            HapticManager.success()
        }
    }
    
    public func deleteServiceRecord(id: UUID) {
        vehicleProfile.serviceHistory.removeAll { $0.id == id }
        HapticManager.light()
    }
    
    public func addFuelRecord(_ record: FuelRecord) {
        vehicleProfile.fuelHistory.insert(record, at: 0)
        vehicleProfile.currentOdometerKm = max(vehicleProfile.currentOdometerKm, record.odometerKm)
        HapticManager.success()
    }
    
    public func updateFuelRecord(_ record: FuelRecord) {
        if let index = vehicleProfile.fuelHistory.firstIndex(where: { $0.id == record.id }) {
            vehicleProfile.fuelHistory[index] = record
            HapticManager.success()
        }
    }
    
    public func deleteFuelRecord(id: UUID) {
        vehicleProfile.fuelHistory.removeAll { $0.id == id }
        HapticManager.light()
    }
    
    // MARK: - Mutations (Documents & Attachments)
    
    /// Returns the directory URL for storing encrypted/local vault attachments.
    public var vaultAttachmentsDirectoryURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("vault_attachments", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    /// Saves raw document data (image or PDF) to the vault attachments directory.
    public func saveAttachmentData(_ data: Data, fileExtension: String, originalName: String? = nil) -> (fileName: String, fileType: String)? {
        let dir = vaultAttachmentsDirectoryURL
        let cleanExt = fileExtension.replacingOccurrences(of: ".", with: "").lowercased()
        let uniqueName = "\(UUID().uuidString).\(cleanExt)"
        let targetURL = dir.appendingPathComponent(uniqueName)
        
        do {
            try data.write(to: targetURL, options: .atomic)
            let type: String
            if ["jpg", "jpeg", "png", "heic", "webp"].contains(cleanExt) {
                type = "image"
            } else if cleanExt == "pdf" {
                type = "pdf"
            } else {
                type = "document"
            }
            return (fileName: uniqueName, fileType: type)
        } catch {
            print("Failed to save attachment file: \(error)")
            return nil
        }
    }
    
    /// Deletes an attachment file by filename from disk.
    public func deleteAttachmentFile(fileName: String?) {
        guard let name = fileName, !name.isEmpty else { return }
        let fileURL = vaultAttachmentsDirectoryURL.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    public func addDocument(_ doc: DocumentRecord) {
        documents.append(doc)
        HapticManager.success()
        if let expiry = doc.expiryDate {
            let docItem = LifeItem(
                title: doc.title,
                subtitle: "\(doc.documentType) Expiry (\(doc.documentNumber))",
                category: .document,
                dueDate: expiry,
                repeatFrequency: .never
            )
            addItem(docItem)
        }
    }
    
    public func updateDocument(_ doc: DocumentRecord) {
        guard let index = documents.firstIndex(where: { $0.id == doc.id }) else { return }
        let oldDoc = documents[index]
        
        // Clean up old attachment if it was replaced or removed
        if let oldAttachment = oldDoc.attachmentFileName, oldAttachment != doc.attachmentFileName {
            deleteAttachmentFile(fileName: oldAttachment)
        }
        
        documents[index] = doc
        HapticManager.success()
        
        // Update corresponding LifeItem
        if let itemIndex = items.firstIndex(where: { $0.category == .document && $0.title == oldDoc.title }) {
            items[itemIndex].title = doc.title
            items[itemIndex].subtitle = "\(doc.documentType) Expiry (\(doc.documentNumber))"
            if let expiry = doc.expiryDate {
                items[itemIndex].dueDate = expiry
                ReminderEngine.shared.scheduleReminders(for: items[itemIndex])
            }
        }
    }
    
    public func deleteDocument(_ doc: DocumentRecord) {
        HapticManager.light()
        deleteAttachmentFile(fileName: doc.attachmentFileName)
        documents.removeAll { $0.id == doc.id }
        items.removeAll { $0.category == .document && $0.title == doc.title }
    }
    
    // MARK: - Mutations (Quick Notes & Reminders)
    
    @discardableResult
    public func addQuickNote(
        title: String = "",
        content: String,
        colorTag: String = "yellow",
        isPinned: Bool = false,
        reminderDate: Date? = nil
    ) -> QuickNote {
        let note = QuickNote(
            title: title,
            content: content,
            isPinned: isPinned,
            colorTag: colorTag,
            reminderDate: reminderDate,
            isReminderCompleted: false
        )
        quickNotes.insert(note, at: 0)
        HapticManager.success()
        
        if reminderDate != nil {
            ReminderEngine.shared.scheduleNoteReminder(for: note)
        }
        
        return note
    }
    
    public func updateQuickNote(_ note: QuickNote) {
        if let index = quickNotes.firstIndex(where: { $0.id == note.id }) {
            var updated = note
            updated.updatedAt = Date()
            quickNotes[index] = updated
            HapticManager.selection()
            ReminderEngine.shared.scheduleNoteReminder(for: updated)
        }
    }
    
    public func deleteQuickNote(_ note: QuickNote) {
        ReminderEngine.shared.cancelNoteReminder(for: note.id)
        quickNotes.removeAll { $0.id == note.id }
        HapticManager.light()
    }
    
    public func togglePinQuickNote(_ note: QuickNote) {
        if let index = quickNotes.firstIndex(where: { $0.id == note.id }) {
            quickNotes[index].isPinned.toggle()
            quickNotes[index].updatedAt = Date()
            HapticManager.selection()
        }
    }
    
    public func toggleNoteReminderCompleted(_ note: QuickNote) {
        if let index = quickNotes.firstIndex(where: { $0.id == note.id }) {
            quickNotes[index].isReminderCompleted.toggle()
            quickNotes[index].updatedAt = Date()
            let updated = quickNotes[index]
            if updated.isReminderCompleted {
                ReminderEngine.shared.cancelNoteReminder(for: updated.id)
                HapticManager.success()
            } else {
                ReminderEngine.shared.scheduleNoteReminder(for: updated)
                HapticManager.selection()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func nextDateForDay(_ day: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()
        var components = calendar.dateComponents([.year, .month], from: today)
        components.day = day
        
        if let candidate = calendar.date(from: components), candidate > today {
            return candidate
        } else {
            components.month = (components.month ?? 1) + 1
            return calendar.date(from: components) ?? today
        }
    }
    
    // MARK: - Persistence & Seeds
    
    private func getURL(for fileName: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
    }
    
    private func saveLoansToDisk() {
        try? JSONEncoder().encode(loans).write(to: getURL(for: loansFileName), options: .atomic)
    }
    
    private func savePoliciesToDisk() {
        try? JSONEncoder().encode(licPolicies).write(to: getURL(for: insuranceFileName), options: .atomic)
    }
    
    private func saveToDisk() {
        try? JSONEncoder().encode(items).write(to: getURL(for: itemsFileName), options: .atomic)
    }
    
    private func saveCardsToDisk() {
        try? JSONEncoder().encode(creditCards).write(to: getURL(for: cardsFileName), options: .atomic)
    }
    
    private func saveBankAccountsToDisk() {
        try? JSONEncoder().encode(bankAccounts).write(to: getURL(for: bankAccountsFileName), options: .atomic)
    }
    
    private func saveVehicleToDisk() {
        try? JSONEncoder().encode(vehicleProfile).write(to: getURL(for: vehicleFileName), options: .atomic)
    }
    
    private func saveDocumentsToDisk() {
        try? JSONEncoder().encode(documents).write(to: getURL(for: documentsFileName), options: .atomic)
    }
    
    private func saveNotesToDisk() {
        try? JSONEncoder().encode(quickNotes).write(to: getURL(for: notesFileName), options: .atomic)
    }
    
    private func loadFromDisk() {
        // One-time purge of legacy dummy seed data
        let purgeKey = "has_purged_dummy_seed_data_v2"
        if !UserDefaults.standard.bool(forKey: purgeKey) {
            try? FileManager.default.removeItem(at: getURL(for: itemsFileName))
            try? FileManager.default.removeItem(at: getURL(for: cardsFileName))
            try? FileManager.default.removeItem(at: getURL(for: vehicleFileName))
            try? FileManager.default.removeItem(at: getURL(for: documentsFileName))
            try? FileManager.default.removeItem(at: getURL(for: notesFileName))
            UserDefaults.standard.set(true, forKey: purgeKey)
        }
        
        let itemsURL = getURL(for: itemsFileName)
        if FileManager.default.fileExists(atPath: itemsURL.path),
           let data = try? Data(contentsOf: itemsURL),
           let loaded = try? JSONDecoder().decode([LifeItem].self, from: data) {
            self.items = loaded
        } else {
            self.items = []
        }
        
        let cardsURL = getURL(for: cardsFileName)
        if FileManager.default.fileExists(atPath: cardsURL.path),
           let data = try? Data(contentsOf: cardsURL),
           let loaded = try? JSONDecoder().decode([CreditCardAccount].self, from: data) {
            self.creditCards = loaded
        } else {
            self.creditCards = []
        }
        
        let bankAccountsURL = getURL(for: bankAccountsFileName)
        if FileManager.default.fileExists(atPath: bankAccountsURL.path),
           let data = try? Data(contentsOf: bankAccountsURL),
           let loaded = try? JSONDecoder().decode([BankAccount].self, from: data) {
            self.bankAccounts = loaded
        } else {
            self.bankAccounts = []
        }
        
        let loansURL = getURL(for: loansFileName)
        if FileManager.default.fileExists(atPath: loansURL.path),
           let data = try? Data(contentsOf: loansURL),
           let loaded = try? JSONDecoder().decode([LoanAccount].self, from: data) {
            self.loans = loaded
        } else {
            self.loans = []
        }
        
        let insuranceURL = getURL(for: insuranceFileName)
        if FileManager.default.fileExists(atPath: insuranceURL.path),
           let data = try? Data(contentsOf: insuranceURL),
           let loaded = try? JSONDecoder().decode([InsurancePolicyRecord].self, from: data) {
            self.licPolicies = loaded
        } else {
            self.licPolicies = []
        }
        
        let vehicleURL = getURL(for: vehicleFileName)
        if FileManager.default.fileExists(atPath: vehicleURL.path),
           let data = try? Data(contentsOf: vehicleURL),
           let loaded = try? JSONDecoder().decode(VehicleProfile.self, from: data) {
            self.vehicleProfile = loaded
        } else {
            self.vehicleProfile = VehicleProfile()
        }
        
        let docsURL = getURL(for: documentsFileName)
        if FileManager.default.fileExists(atPath: docsURL.path),
           let data = try? Data(contentsOf: docsURL),
           let loaded = try? JSONDecoder().decode([DocumentRecord].self, from: data) {
            self.documents = loaded
        } else {
            self.documents = []
        }
        
        let notesURL = getURL(for: notesFileName)
        if FileManager.default.fileExists(atPath: notesURL.path),
           let data = try? Data(contentsOf: notesURL),
           let loaded = try? JSONDecoder().decode([QuickNote].self, from: data) {
            self.quickNotes = loaded
        } else {
            self.quickNotes = []
        }
    }
    
    // MARK: - Google Backup & Full Archive Export/Restore
    
    public func exportBackupArchive() throws -> URL {
        // Collect and embed all vault attachment files into the backup archive
        var backupAttachments: [BackupAttachmentPayload] = []
        for doc in self.documents {
            if let fileName = doc.attachmentFileName,
               let fileURL = doc.attachmentURL,
               FileManager.default.fileExists(atPath: fileURL.path),
               let data = try? Data(contentsOf: fileURL) {
                let payload = BackupAttachmentPayload(
                    fileName: fileName,
                    fileType: doc.attachmentFileType ?? "file",
                    originalName: doc.attachmentOriginalName,
                    base64Data: data.base64EncodedString()
                )
                backupAttachments.append(payload)
            }
        }
        
        let archive = PrabuOneBackupArchive(
            items: self.items,
            creditCards: self.creditCards,
            bankAccounts: self.bankAccounts,
            loans: self.loans,
            licPolicies: self.licPolicies,
            vehicleProfile: self.vehicleProfile,
            documents: self.documents,
            quickNotes: self.quickNotes,
            attachments: backupAttachments
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(archive)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let dateStr = formatter.string(from: Date())
        let fileName = "PrabuOne_Backup_\(dateStr).json"
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL, options: .atomic)
        
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "last_google_backup_timestamp")
        return tempURL
    }
    
    public func restoreFromBackup(url: URL) throws -> (items: Int, cards: Int, banks: Int, loans: Int, policies: Int, docs: Int, notes: Int, attachments: Int) {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let archive: PrabuOneBackupArchive
        if let decoded = try? decoder.decode(PrabuOneBackupArchive.self, from: data) {
            archive = decoded
        } else {
            archive = try JSONDecoder().decode(PrabuOneBackupArchive.self, from: data)
        }
        
        self.items = archive.items
        self.creditCards = archive.creditCards
        self.bankAccounts = archive.bankAccounts
        self.loans = archive.loans
        self.licPolicies = archive.licPolicies
        self.vehicleProfile = archive.vehicleProfile
        self.documents = archive.documents
        self.quickNotes = archive.quickNotes
        
        // Restore all document attachments to vault_attachments directory
        let dir = self.vaultAttachmentsDirectoryURL
        var restoredAttachmentCount = 0
        for attachment in archive.attachments {
            if let attachmentData = Data(base64Encoded: attachment.base64Data) {
                let targetURL = dir.appendingPathComponent(attachment.fileName)
                try? attachmentData.write(to: targetURL, options: .atomic)
                restoredAttachmentCount += 1
            }
        }
        
        saveToDisk()
        saveCardsToDisk()
        saveBankAccountsToDisk()
        saveLoansToDisk()
        savePoliciesToDisk()
        saveVehicleToDisk()
        saveDocumentsToDisk()
        saveNotesToDisk()
        
        ReminderEngine.shared.cancelAllReminders()
        for item in self.items {
            ReminderEngine.shared.scheduleReminders(for: item)
        }
        for note in self.quickNotes {
            ReminderEngine.shared.scheduleNoteReminder(for: note)
        }
        
        HapticManager.success()
        return (
            archive.items.count,
            archive.creditCards.count,
            archive.bankAccounts.count,
            archive.loans.count,
            archive.licPolicies.count,
            archive.documents.count,
            archive.quickNotes.count,
            restoredAttachmentCount
        )
    }
    
    /// Complete purge to reset app data if needed.
    public func clearAllData() {
        self.items = []
        self.creditCards = []
        self.bankAccounts = []
        self.loans = []
        self.licPolicies = []
        self.vehicleProfile = VehicleProfile()
        self.documents = []
        self.quickNotes = []
        ReminderEngine.shared.cancelAllReminders()
        saveToDisk()
        saveCardsToDisk()
        saveBankAccountsToDisk()
        saveLoansToDisk()
        savePoliciesToDisk()
        saveVehicleToDisk()
        saveDocumentsToDisk()
        saveNotesToDisk()
        
        // Remove attachments directory
        let dir = vaultAttachmentsDirectoryURL
        try? FileManager.default.removeItem(at: dir)
    }
}

/// Raw file attachment payload encoded into portable base64 for cloud backup.
public struct BackupAttachmentPayload: Codable {
    public var fileName: String
    public var fileType: String
    public var originalName: String?
    public var base64Data: String
    
    public init(fileName: String, fileType: String, originalName: String? = nil, base64Data: String) {
        self.fileName = fileName
        self.fileType = fileType
        self.originalName = originalName
        self.base64Data = base64Data
    }
}

/// Unified portable snapshot of all Prabu One data for backup to Google Drive / local storage.
public struct PrabuOneBackupArchive: Codable {
    public var version: Int = 1
    public var exportDate: Date = Date()
    public var items: [LifeItem]
    public var creditCards: [CreditCardAccount]
    public var bankAccounts: [BankAccount]
    public var loans: [LoanAccount]
    public var licPolicies: [InsurancePolicyRecord]
    public var vehicleProfile: VehicleProfile
    public var documents: [DocumentRecord]
    public var quickNotes: [QuickNote]
    public var attachments: [BackupAttachmentPayload]
    
    public init(
        version: Int = 1,
        exportDate: Date = Date(),
        items: [LifeItem],
        creditCards: [CreditCardAccount],
        bankAccounts: [BankAccount],
        loans: [LoanAccount],
        licPolicies: [InsurancePolicyRecord],
        vehicleProfile: VehicleProfile,
        documents: [DocumentRecord],
        quickNotes: [QuickNote],
        attachments: [BackupAttachmentPayload] = []
    ) {
        self.version = version
        self.exportDate = exportDate
        self.items = items
        self.creditCards = creditCards
        self.bankAccounts = bankAccounts
        self.loans = loans
        self.licPolicies = licPolicies
        self.vehicleProfile = vehicleProfile
        self.documents = documents
        self.quickNotes = quickNotes
        self.attachments = attachments
    }
    
    private enum CodingKeys: String, CodingKey {
        case version, exportDate, items, creditCards, bankAccounts, loans, licPolicies, vehicleProfile, documents, quickNotes, attachments
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        exportDate = try container.decodeIfPresent(Date.self, forKey: .exportDate) ?? Date()
        items = try container.decodeIfPresent([LifeItem].self, forKey: .items) ?? []
        creditCards = try container.decodeIfPresent([CreditCardAccount].self, forKey: .creditCards) ?? []
        bankAccounts = try container.decodeIfPresent([BankAccount].self, forKey: .bankAccounts) ?? []
        loans = try container.decodeIfPresent([LoanAccount].self, forKey: .loans) ?? []
        licPolicies = try container.decodeIfPresent([InsurancePolicyRecord].self, forKey: .licPolicies) ?? []
        vehicleProfile = try container.decodeIfPresent(VehicleProfile.self, forKey: .vehicleProfile) ?? VehicleProfile()
        documents = try container.decodeIfPresent([DocumentRecord].self, forKey: .documents) ?? []
        quickNotes = try container.decodeIfPresent([QuickNote].self, forKey: .quickNotes) ?? []
        attachments = try container.decodeIfPresent([BackupAttachmentPayload].self, forKey: .attachments) ?? []
    }
}
