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

/// Category of vehicle supported in personal garage.
public enum VehicleType: String, Codable, CaseIterable, Identifiable {
    case fourWheeler = "4-Wheeler (Car / SUV)"
    case twoWheeler = "2-Wheeler (Bike / Scooter)"
    case electricCar = "Electric Car (EV)"
    case electricBike = "Electric 2W (EV)"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .fourWheeler: return "car.side.fill"
        case .twoWheeler: return "motorcycle.fill"
        case .electricCar: return "bolt.car.fill"
        case .electricBike: return "bolt.shield.fill"
        }
    }
    
    public var isTwoWheeler: Bool {
        self == .twoWheeler || self == .electricBike
    }
}

/// Vehicle Profile representation (car, bike, or personal vehicle).
public struct VehicleProfile: Identifiable, Codable, Equatable {
    public var id: UUID
    public var vehicleType: VehicleType
    public var nickName: String
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
    
    // Connected Documents from Document Vault
    public var rcDocumentId: UUID?
    public var insuranceDocumentId: UUID?
    public var pucDocumentId: UUID?
    
    public init(
        id: UUID = UUID(),
        vehicleType: VehicleType = .fourWheeler,
        nickName: String = "",
        makeModel: String = "",
        registrationNumber: String = "",
        fuelType: String = "Petrol",
        currentOdometerKm: Int = 0,
        nextServiceDueKm: Int = 10000,
        insuranceExpiryDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date(),
        pucExpiryDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date(),
        fastagBalance: Double = 0,
        serviceHistory: [VehicleServiceRecord] = [],
        fuelHistory: [FuelRecord] = [],
        rcDocumentId: UUID? = nil,
        insuranceDocumentId: UUID? = nil,
        pucDocumentId: UUID? = nil
    ) {
        self.id = id
        self.vehicleType = vehicleType
        self.nickName = nickName
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
        self.rcDocumentId = rcDocumentId
        self.insuranceDocumentId = insuranceDocumentId
        self.pucDocumentId = pucDocumentId
    }
    
    public var displayTitle: String {
        if !nickName.isEmpty {
            return nickName
        }
        if !makeModel.isEmpty {
            return makeModel
        }
        return vehicleType.isTwoWheeler ? "Two-Wheeler" : "Vehicle"
    }
    
    public var formattedRegistration: String {
        registrationNumber.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
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
    
    private enum CodingKeys: String, CodingKey {
        case id, vehicleType, nickName, makeModel, registrationNumber, fuelType
        case currentOdometerKm, nextServiceDueKm, insuranceExpiryDate, pucExpiryDate
        case fastagBalance, serviceHistory, fuelHistory
        case rcDocumentId, insuranceDocumentId, pucDocumentId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        vehicleType = try container.decodeIfPresent(VehicleType.self, forKey: .vehicleType) ?? .fourWheeler
        nickName = try container.decodeIfPresent(String.self, forKey: .nickName) ?? ""
        makeModel = try container.decodeIfPresent(String.self, forKey: .makeModel) ?? ""
        registrationNumber = try container.decodeIfPresent(String.self, forKey: .registrationNumber) ?? ""
        fuelType = try container.decodeIfPresent(String.self, forKey: .fuelType) ?? "Petrol"
        currentOdometerKm = try container.decodeIfPresent(Int.self, forKey: .currentOdometerKm) ?? 0
        nextServiceDueKm = try container.decodeIfPresent(Int.self, forKey: .nextServiceDueKm) ?? 10000
        insuranceExpiryDate = try container.decodeIfPresent(Date.self, forKey: .insuranceExpiryDate) ?? Date()
        pucExpiryDate = try container.decodeIfPresent(Date.self, forKey: .pucExpiryDate) ?? Date()
        fastagBalance = try container.decodeIfPresent(Double.self, forKey: .fastagBalance) ?? 0
        serviceHistory = try container.decodeIfPresent([VehicleServiceRecord].self, forKey: .serviceHistory) ?? []
        fuelHistory = try container.decodeIfPresent([FuelRecord].self, forKey: .fuelHistory) ?? []
        rcDocumentId = try container.decodeIfPresent(UUID.self, forKey: .rcDocumentId)
        insuranceDocumentId = try container.decodeIfPresent(UUID.self, forKey: .insuranceDocumentId)
        pucDocumentId = try container.decodeIfPresent(UUID.self, forKey: .pucDocumentId)
    }
}
