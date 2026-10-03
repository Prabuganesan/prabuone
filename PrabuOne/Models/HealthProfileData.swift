import Foundation
import SwiftUI

// MARK: - Blood Group
public enum BloodGroup: String, Codable, CaseIterable, Identifiable {
    case aPositive = "A+"
    case aNegative = "A-"
    case bPositive = "B+"
    case bNegative = "B-"
    case abPositive = "AB+"
    case abNegative = "AB-"
    case oPositive = "O+"
    case oNegative = "O-"
    case unknown = "Not Set"
    
    public var id: String { rawValue }
    
    public var badgeColor: Color {
        switch self {
        case .oPositive, .oNegative: return .red
        case .aPositive, .aNegative: return .blue
        case .bPositive, .bNegative: return .purple
        case .abPositive, .abNegative: return .orange
        case .unknown: return .secondary
        }
    }
}

// MARK: - Emergency Contact
public struct EmergencyContact: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var name: String
    public var relationship: String
    public var phoneNumber: String
    public var isPrimary: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        relationship: String,
        phoneNumber: String,
        isPrimary: Bool = false
    ) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.phoneNumber = phoneNumber
        self.isPrimary = isPrimary
    }
}

// MARK: - Active Medication
public struct MedicationRecord: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var name: String
    public var dosage: String
    public var frequency: String
    public var instructions: String // e.g., "After breakfast", "Before sleep"
    public var isActive: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        dosage: String,
        frequency: String,
        instructions: String = "",
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.instructions = instructions
        self.isActive = isActive
    }
}

// MARK: - Health Allergy Record
public struct AllergyRecord: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var allergen: String
    public var reaction: String
    public var severity: String // e.g. "Mild", "Moderate", "Severe / Anaphylactic"
    
    public init(
        id: UUID = UUID(),
        allergen: String,
        reaction: String,
        severity: String = "Moderate"
    ) {
        self.id = id
        self.allergen = allergen
        self.reaction = reaction
        self.severity = severity
    }
    
    public var severityColor: Color {
        switch severity.lowercased() {
        case let s where s.contains("severe") || s.contains("anaphylactic"): return .red
        case let s where s.contains("moderate"): return .orange
        default: return .yellow
        }
    }
}

// MARK: - Mediclaim Insurance Card
public struct HealthInsuranceRecord: Codable, Equatable, Hashable {
    public var providerName: String
    public var policyNumber: String
    public var tpaName: String
    public var sumInsured: Double
    public var cashlessHotline: String
    public var expiryDate: Date?
    
    public init(
        providerName: String = "",
        policyNumber: String = "",
        tpaName: String = "",
        sumInsured: Double = 0,
        cashlessHotline: String = "",
        expiryDate: Date? = nil
    ) {
        self.providerName = providerName
        self.policyNumber = policyNumber
        self.tpaName = tpaName
        self.sumInsured = sumInsured
        self.cashlessHotline = cashlessHotline
        self.expiryDate = expiryDate
    }
    
    public var formattedSumInsured: String {
        guard sumInsured > 0 else { return "Not Specified" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: sumInsured)) ?? "₹\(Int(sumInsured))"
    }
}

// MARK: - Comprehensive Personal Health Profile
public struct HealthProfileRecord: Codable, Equatable, Hashable {
    public var fullName: String
    public var dateOfBirth: Date?
    public var bloodGroup: BloodGroup
    public var heightCm: Double
    public var weightKg: Double
    public var isOrganDonor: Bool
    public var chronicConditions: [String]
    public var allergies: [AllergyRecord]
    public var medications: [MedicationRecord]
    public var emergencyContacts: [EmergencyContact]
    public var insurance: HealthInsuranceRecord
    public var medicalNotes: String
    
    // MARK: - Live Apple Health Telemetry (Read from Health App)
    public var biologicalSex: String?
    public var restingHeartRate: Double?
    public var latestHeartRate: Double?
    public var bloodOxygenSpO2: Double?
    public var bloodPressureSystolic: Double?
    public var bloodPressureDiastolic: Double?
    public var todaySteps: Int?
    public var todayActiveCalories: Double?
    public var todayDistanceKm: Double?
    public var lastNightSleepHours: Double?
    public var respiratoryRate: Double?
    public var bodyTemperatureCelsius: Double?
    public var lastHealthAppSyncDate: Date?
    
    public init(
        fullName: String = "Prabu Ganesan",
        dateOfBirth: Date? = nil,
        bloodGroup: BloodGroup = .unknown,
        heightCm: Double = 0,
        weightKg: Double = 0,
        isOrganDonor: Bool = true,
        chronicConditions: [String] = [],
        allergies: [AllergyRecord] = [],
        medications: [MedicationRecord] = [],
        emergencyContacts: [EmergencyContact] = [],
        insurance: HealthInsuranceRecord = HealthInsuranceRecord(),
        medicalNotes: String = "",
        biologicalSex: String? = nil,
        restingHeartRate: Double? = nil,
        latestHeartRate: Double? = nil,
        bloodOxygenSpO2: Double? = nil,
        bloodPressureSystolic: Double? = nil,
        bloodPressureDiastolic: Double? = nil,
        todaySteps: Int? = nil,
        todayActiveCalories: Double? = nil,
        todayDistanceKm: Double? = nil,
        lastNightSleepHours: Double? = nil,
        respiratoryRate: Double? = nil,
        bodyTemperatureCelsius: Double? = nil,
        lastHealthAppSyncDate: Date? = nil
    ) {
        self.fullName = fullName
        self.dateOfBirth = dateOfBirth
        self.bloodGroup = bloodGroup
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.isOrganDonor = isOrganDonor
        self.chronicConditions = chronicConditions
        self.allergies = allergies
        self.medications = medications
        self.emergencyContacts = emergencyContacts
        self.insurance = insurance
        self.medicalNotes = medicalNotes
        self.biologicalSex = biologicalSex
        self.restingHeartRate = restingHeartRate
        self.latestHeartRate = latestHeartRate
        self.bloodOxygenSpO2 = bloodOxygenSpO2
        self.bloodPressureSystolic = bloodPressureSystolic
        self.bloodPressureDiastolic = bloodPressureDiastolic
        self.todaySteps = todaySteps
        self.todayActiveCalories = todayActiveCalories
        self.todayDistanceKm = todayDistanceKm
        self.lastNightSleepHours = lastNightSleepHours
        self.respiratoryRate = respiratoryRate
        self.bodyTemperatureCelsius = bodyTemperatureCelsius
        self.lastHealthAppSyncDate = lastHealthAppSyncDate
    }
    
    public var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }
    
    public var bmi: Double? {
        guard heightCm > 50 && weightKg > 20 else { return nil }
        let heightM = heightCm / 100.0
        return weightKg / (heightM * heightM)
    }
    
    public var bmiCategory: (title: String, color: Color) {
        guard let b = bmi else { return ("N/A", .secondary) }
        switch b {
        case ..<18.5: return ("Underweight", .blue)
        case 18.5..<24.9: return ("Normal Weight", .green)
        case 25.0..<29.9: return ("Overweight", .orange)
        default: return ("Obese", .red)
        }
    }
    
    public var formattedBloodPressure: String? {
        guard let sys = bloodPressureSystolic, let dia = bloodPressureDiastolic else { return nil }
        return "\(Int(sys))/\(Int(dia)) mmHg"
    }
    
    public var formattedRestingHR: String? {
        guard let hr = restingHeartRate ?? latestHeartRate else { return nil }
        return "\(Int(hr)) bpm"
    }
    
    public var formattedSpO2: String? {
        guard let spo2 = bloodOxygenSpO2 else { return nil }
        // SpO2 can be 0.98 or 98.0
        let val = spo2 <= 1.0 ? spo2 * 100.0 : spo2
        return "\(Int(val))%"
    }
    
    public var formattedTodaySteps: String? {
        guard let steps = todaySteps else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: steps)) ?? "\(steps)") + " steps"
    }
    
    public var formattedSleepHours: String? {
        guard let sleep = lastNightSleepHours, sleep > 0 else { return nil }
        return String(format: "%.1f hrs", sleep)
    }
}
