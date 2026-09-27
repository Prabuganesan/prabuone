import Foundation

/// Vehicle maintenance service record.
public struct VehicleServiceRecord: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var date: Date
    public var odometerKm: Int
    public var cost: Double
    public var itemsReplaced: [String]
    public var serviceCenter: String
    
    public init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        odometerKm: Int,
        cost: Double,
        itemsReplaced: [String],
        serviceCenter: String
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.odometerKm = odometerKm
        self.cost = cost
        self.itemsReplaced = itemsReplaced
        self.serviceCenter = serviceCenter
    }
}

/// Fuel and recharge log entry.
public struct FuelRecord: Identifiable, Codable, Equatable {
    public var id: UUID
    public var date: Date
    public var odometerKm: Int
    public var liters: Double
    public var totalCost: Double
    
    public init(
        id: UUID = UUID(),
        date: Date,
        odometerKm: Int,
        liters: Double,
        totalCost: Double
    ) {
        self.id = id
        self.date = date
        self.odometerKm = odometerKm
        self.liters = liters
        self.totalCost = totalCost
    }
    
    public var ratePerLiter: Double {
        liters > 0 ? totalCost / liters : 0
    }
}

/// Vehicle Profile representation (e.g. Kia Sonet).
public struct VehicleProfile: Identifiable, Codable, Equatable {
    public var id: UUID
    public var makeModel: String
    public var registrationNumber: String
    public var fuelType: String
    public var currentOdometerKm: Int
    public var nextServiceDueKm: Int
    public var insuranceExpiryDate: Date
    public var pucExpiryDate: Date
    public var fastagBalance: Double
    public var serviceHistory: [VehicleServiceRecord]
    public var fuelHistory: [FuelRecord]
    
    public init(
        id: UUID = UUID(),
        makeModel: String = "Kia Sonet",
        registrationNumber: String = "",
        fuelType: String = "Diesel",
        currentOdometerKm: Int = 0,
        nextServiceDueKm: Int = 10000,
        insuranceExpiryDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date(),
        pucExpiryDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date(),
        fastagBalance: Double = 0,
        serviceHistory: [VehicleServiceRecord] = [],
        fuelHistory: [FuelRecord] = []
    ) {
        self.id = id
        self.makeModel = makeModel
        self.registrationNumber = registrationNumber
        self.fuelType = fuelType
        self.currentOdometerKm = currentOdometerKm
        self.nextServiceDueKm = nextServiceDueKm
        self.insuranceExpiryDate = insuranceExpiryDate
        self.pucExpiryDate = pucExpiryDate
        self.fastagBalance = fastagBalance
        self.serviceHistory = serviceHistory
        self.fuelHistory = fuelHistory
    }
    
    public var kmUntilService: Int {
        max(0, nextServiceDueKm - currentOdometerKm)
    }
    
    public var totalFuelSpend: Double {
        fuelHistory.reduce(0) { $0 + $1.totalCost }
    }
    
    public var totalServiceSpend: Double {
        serviceHistory.reduce(0) { $0 + $1.cost }
    }
    
    /// Estimated fuel economy (km/L) from fuel entries.
    public var averageFuelEconomy: Double? {
        guard fuelHistory.count >= 2 else { return nil }
        let sorted = fuelHistory.sorted { $0.odometerKm < $1.odometerKm }
        guard let first = sorted.first, let last = sorted.last, last.odometerKm > first.odometerKm else {
            return nil
        }
        let totalKm = Double(last.odometerKm - first.odometerKm)
        let totalLiters = sorted.dropFirst().reduce(0.0) { $0 + $1.liters }
        return totalLiters > 0 ? (totalKm / totalLiters) : nil
    }
}
