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
    @Published public var vehicleProfile: VehicleProfile = VehicleProfile() { didSet { saveVehicleToDisk() } }
    @Published public var documents: [DocumentRecord] = [] { didSet { saveDocumentsToDisk() } }
    
    private let itemsFileName = "prabuone_life_items.json"
    private let cardsFileName = "prabuone_credit_cards.json"
    private let vehicleFileName = "prabuone_vehicle.json"
    private let documentsFileName = "prabuone_documents.json"
    
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
        let cardItem = LifeItem(
            title: "\(card.bankName) \(card.cardName)",
            subtitle: "Ending in \(card.lastFourDigits) • Limit ₹\(Int(card.creditLimit))",
            category: .creditCard,
            dueDate: nextDateForDay(card.dueDay),
            amount: card.outstandingAmount,
            repeatFrequency: .monthly
        )
        addItem(cardItem)
    }
    
    public func deleteCreditCard(_ card: CreditCardAccount) {
        HapticManager.light()
        creditCards.removeAll { $0.id == card.id }
        // Also remove associated life items
        items.removeAll { $0.category == .creditCard && $0.title.contains(card.cardName) }
    }
    
    public func toggleCardPaid(_ card: CreditCardAccount) {
        guard let index = creditCards.firstIndex(where: { $0.id == card.id }) else { return }
        creditCards[index].isPaidThisMonth.toggle()
        if creditCards[index].isPaidThisMonth {
            creditCards[index].outstandingAmount = 0
            HapticManager.success()
        } else {
            HapticManager.selection()
        }
        
        // Also sync status with corresponding LifeItem
        if let itemIndex = items.firstIndex(where: { $0.category == .creditCard && $0.title.contains(card.cardName) }) {
            items[itemIndex].isCompleted = creditCards[index].isPaidThisMonth
        }
    }
    
    // MARK: - Mutations (Vehicle)
    
    public func updateOdometer(newKm: Int) {
        vehicleProfile.currentOdometerKm = newKm
        HapticManager.success()
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
    
    public func addServiceRecord(_ record: VehicleServiceRecord) {
        vehicleProfile.serviceHistory.insert(record, at: 0)
        vehicleProfile.currentOdometerKm = max(vehicleProfile.currentOdometerKm, record.odometerKm)
        vehicleProfile.nextServiceDueKm = record.odometerKm + 10000
        HapticManager.success()
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
    
    public func deleteFuelRecord(id: UUID) {
        vehicleProfile.fuelHistory.removeAll { $0.id == id }
        HapticManager.light()
    }
    
    // MARK: - Mutations (Documents)
    
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
    
    public func deleteDocument(_ doc: DocumentRecord) {
        HapticManager.light()
        documents.removeAll { $0.id == doc.id }
        items.removeAll { $0.category == .document && $0.title == doc.title }
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
    
    private func saveToDisk() {
        try? JSONEncoder().encode(items).write(to: getURL(for: itemsFileName), options: .atomic)
    }
    
    private func saveCardsToDisk() {
        try? JSONEncoder().encode(creditCards).write(to: getURL(for: cardsFileName), options: .atomic)
    }
    
    private func saveVehicleToDisk() {
        try? JSONEncoder().encode(vehicleProfile).write(to: getURL(for: vehicleFileName), options: .atomic)
    }
    
    private func saveDocumentsToDisk() {
        try? JSONEncoder().encode(documents).write(to: getURL(for: documentsFileName), options: .atomic)
    }
    
    private func loadFromDisk() {
        // One-time purge of legacy dummy seed data
        let purgeKey = "has_purged_dummy_seed_data_v2"
        if !UserDefaults.standard.bool(forKey: purgeKey) {
            try? FileManager.default.removeItem(at: getURL(for: itemsFileName))
            try? FileManager.default.removeItem(at: getURL(for: cardsFileName))
            try? FileManager.default.removeItem(at: getURL(for: vehicleFileName))
            try? FileManager.default.removeItem(at: getURL(for: documentsFileName))
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
    }
    
    /// Complete purge to reset app data if needed.
    public func clearAllData() {
        self.items = []
        self.creditCards = []
        self.vehicleProfile = VehicleProfile()
        self.documents = []
        ReminderEngine.shared.cancelAllReminders()
        saveToDisk()
        saveCardsToDisk()
        saveVehicleToDisk()
        saveDocumentsToDisk()
    }
}
