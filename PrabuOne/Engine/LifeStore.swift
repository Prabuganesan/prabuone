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
        let itemsURL = getURL(for: itemsFileName)
        if FileManager.default.fileExists(atPath: itemsURL.path),
           let data = try? Data(contentsOf: itemsURL),
           let loaded = try? JSONDecoder().decode([LifeItem].self, from: data) {
            self.items = loaded
        } else {
            seedInitialItems()
        }
        
        let cardsURL = getURL(for: cardsFileName)
        if FileManager.default.fileExists(atPath: cardsURL.path),
           let data = try? Data(contentsOf: cardsURL),
           let loaded = try? JSONDecoder().decode([CreditCardAccount].self, from: data) {
            self.creditCards = loaded
        } else {
            seedInitialCards()
        }
        
        let vehicleURL = getURL(for: vehicleFileName)
        if FileManager.default.fileExists(atPath: vehicleURL.path),
           let data = try? Data(contentsOf: vehicleURL),
           let loaded = try? JSONDecoder().decode(VehicleProfile.self, from: data) {
            self.vehicleProfile = loaded
        } else {
            seedInitialVehicle()
        }
        
        let docsURL = getURL(for: documentsFileName)
        if FileManager.default.fileExists(atPath: docsURL.path),
           let data = try? Data(contentsOf: docsURL),
           let loaded = try? JSONDecoder().decode([DocumentRecord].self, from: data) {
            self.documents = loaded
        } else {
            seedInitialDocuments()
        }
    }
    
    private func seedInitialItems() {
        let calendar = Calendar.current
        let today = Date()
        
        let sampleItems: [LifeItem] = [
            LifeItem(
                title: "HDFC Regalia Card",
                subtitle: "Payment Due • Outstanding ₹42,350",
                category: .creditCard,
                dueDate: calendar.date(byAdding: .day, value: 2, to: today) ?? today,
                amount: 42350,
                repeatFrequency: .monthly
            ),
            LifeItem(
                title: "Jio Mobile Recharge",
                subtitle: "SIM 1 • ₹299 Unlimited Plan",
                category: .mobileBill,
                dueDate: calendar.date(byAdding: .day, value: 4, to: today) ?? today,
                amount: 299,
                repeatFrequency: .monthly
            ),
            LifeItem(
                title: "Kia Sonet Insurance",
                subtitle: "Annual Comprehensive Policy Renewal",
                category: .vehicle,
                dueDate: calendar.date(byAdding: .day, value: 12, to: today) ?? today,
                amount: 18500,
                repeatFrequency: .yearly
            ),
            LifeItem(
                title: "Cursor Pro Subscription",
                subtitle: "AI Coding Assistant Plan ($20)",
                category: .subscription,
                dueDate: calendar.date(byAdding: .day, value: 16, to: today) ?? today,
                amount: 1700,
                repeatFrequency: .monthly
            ),
            LifeItem(
                title: "Netflix Premium",
                subtitle: "4K Family Plan",
                category: .subscription,
                dueDate: calendar.date(byAdding: .day, value: 18, to: today) ?? today,
                amount: 649,
                repeatFrequency: .monthly
            ),
            LifeItem(
                title: "Thaya's Birthday",
                subtitle: "Family Celebration & Gift",
                category: .birthday,
                dueDate: calendar.date(byAdding: .day, value: 24, to: today) ?? today,
                repeatFrequency: .yearly
            ),
            LifeItem(
                title: "Kia Sonet PUC Certificate",
                subtitle: "Vehicle Pollution Expiry",
                category: .document,
                dueDate: calendar.date(byAdding: .day, value: 35, to: today) ?? today,
                amount: 100,
                repeatFrequency: .yearly
            )
        ]
        
        self.items = sampleItems
        for item in sampleItems {
            ReminderEngine.shared.scheduleReminders(for: item)
        }
        saveToDisk()
    }
    
    private func seedInitialCards() {
        self.creditCards = [
            CreditCardAccount(
                bankName: "HDFC Bank",
                cardName: "Regalia Gold",
                lastFourDigits: "4821",
                creditLimit: 500000,
                outstandingAmount: 42350,
                statementDay: 15,
                dueDay: 5,
                rewardPoints: 14200,
                cardNetwork: "Visa"
            ),
            CreditCardAccount(
                bankName: "ICICI Bank",
                cardName: "Amazon Pay",
                lastFourDigits: "9102",
                creditLimit: 250000,
                outstandingAmount: 8200,
                statementDay: 20,
                dueDay: 10,
                rewardPoints: 3450,
                cardNetwork: "Visa"
            )
        ]
        saveCardsToDisk()
    }
    
    private func seedInitialVehicle() {
        self.vehicleProfile = VehicleProfile(
            makeModel: "Kia Sonet HTX",
            registrationNumber: "TN 01 AB 1234",
            fuelType: "Diesel",
            currentOdometerKm: 45320,
            nextServiceDueKm: 50000,
            serviceHistory: [
                VehicleServiceRecord(
                    title: "Periodic 40,000 km Service",
                    date: Calendar.current.date(byAdding: .month, value: -4, to: Date()) ?? Date(),
                    odometerKm: 40210,
                    cost: 8450,
                    itemsReplaced: ["Engine Oil (Fully Synthetic)", "Oil Filter", "Air Filter", "Cabin AC Filter"],
                    serviceCenter: "Kia Authorized Service Center"
                )
            ],
            fuelHistory: [
                FuelRecord(
                    date: Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date(),
                    odometerKm: 45050,
                    liters: 38.5,
                    totalCost: 3650
                )
            ]
        )
        saveVehicleToDisk()
    }
    
    private func seedInitialDocuments() {
        let calendar = Calendar.current
        let today = Date()
        
        self.documents = [
            DocumentRecord(
                title: "Kia Sonet Registration Certificate (RC)",
                documentType: "RC Book",
                documentNumber: "TN01AB1234",
                expiryDate: calendar.date(byAdding: .year, value: 12, to: today)
            ),
            DocumentRecord(
                title: "Driving License",
                documentType: "Driving License",
                documentNumber: "DL-0420110012345",
                expiryDate: calendar.date(byAdding: .year, value: 8, to: today)
            ),
            DocumentRecord(
                title: "Indian Passport",
                documentType: "Passport",
                documentNumber: "Z4829104",
                expiryDate: calendar.date(byAdding: .year, value: 4, to: today)
            ),
            DocumentRecord(
                title: "Kia Sonet Comprehensive Insurance",
                documentType: "Insurance Policy",
                documentNumber: "POL-ICICI-849201",
                expiryDate: calendar.date(byAdding: .day, value: 12, to: today)
            ),
            DocumentRecord(
                title: "Pollution Under Control (PUC)",
                documentType: "PUC Certificate",
                documentNumber: "PUC-TN-94021",
                expiryDate: calendar.date(byAdding: .day, value: 35, to: today)
            )
        ]
        saveDocumentsToDisk()
    }
}
