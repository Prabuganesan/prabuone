import Foundation
import SwiftUI
import HealthKit

/// Apple Health (HealthKit) Integration Manager.
/// Securely reads biological characteristics, emergency medical vitals,
/// body metrics (height, weight, BMI), cardiovascular health, and daily activity.
@MainActor
public final class AppleHealthManager: ObservableObject {
    public static let shared = AppleHealthManager()
    
    private let healthStore = HKHealthStore()
    
    @Published public var isAvailable: Bool = false
    @Published public var isAuthorized: Bool = false
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncDate: Date? = nil
    @Published public var errorMessage: String? = nil
    
    // Live Telemetry Snapshot
    @Published public var bloodType: BloodGroup = .unknown
    @Published public var biologicalSex: String? = nil
    @Published public var dateOfBirth: Date? = nil
    @Published public var heightCm: Double? = nil
    @Published public var weightKg: Double? = nil
    @Published public var restingHeartRate: Double? = nil
    @Published public var latestHeartRate: Double? = nil
    @Published public var bloodOxygenSpO2: Double? = nil
    @Published public var bloodPressureSystolic: Double? = nil
    @Published public var bloodPressureDiastolic: Double? = nil
    @Published public var todaySteps: Int? = nil
    @Published public var todayActiveCalories: Double? = nil
    @Published public var todayDistanceKm: Double? = nil
    @Published public var lastNightSleepHours: Double? = nil
    @Published public var respiratoryRate: Double? = nil
    @Published public var bodyTemperatureCelsius: Double? = nil
    
    private init() {
        self.isAvailable = HKHealthStore.isHealthDataAvailable()
    }
    
    // MARK: - HealthKit Types Requested
    
    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        
        // Characteristics (Medical ID attributes)
        if let dob = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) {
            types.insert(dob)
        }
        if let blood = HKObjectType.characteristicType(forIdentifier: .bloodType) {
            types.insert(blood)
        }
        if let sex = HKObjectType.characteristicType(forIdentifier: .biologicalSex) {
            types.insert(sex)
        }
        
        // Body Measurements
        if let height = HKQuantityType.quantityType(forIdentifier: .height) {
            types.insert(height)
        }
        if let weight = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(weight)
        }
        
        // Vitals & Cardiovascular
        if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(hr)
        }
        if let restingHR = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHR)
        }
        if let o2 = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
            types.insert(o2)
        }
        if let bpSys = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic) {
            types.insert(bpSys)
        }
        if let bpDia = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) {
            types.insert(bpDia)
        }
        if let resp = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) {
            types.insert(resp)
        }
        if let temp = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) {
            types.insert(temp)
        }
        
        // Daily Activity
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        
        // Sleep & Correlation
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        if let bpCorr = HKCorrelationType.correlationType(forIdentifier: .bloodPressure) {
            types.insert(bpCorr)
        }
        
        return types
    }
    
    // MARK: - Authorization
    
    public func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.errorMessage = "Apple Health is not supported on this device architecture."
            return false
        }
        
        let typesToRead = self.readTypes
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            self.isAuthorized = true
            return true
        } catch {
            self.errorMessage = "Apple Health authorization failed: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Full Sync Pipeline
    
    @discardableResult
    public func syncFromAppleHealth(store: LifeStore) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.errorMessage = "Apple Health is unavailable."
            return false
        }
        
        self.isSyncing = true
        self.errorMessage = nil
        
        // 1. Ensure authorization
        let authorized = await requestAuthorization()
        guard authorized else {
            self.isSyncing = false
            return false
        }
        
        // 2. Read Characteristics (Synchronous from HealthStore)
        readCharacteristics()
        
        // 3. Read Body Quantities
        if let heightType = HKQuantityType.quantityType(forIdentifier: .height) {
            self.heightCm = await fetchLatestQuantitySample(for: heightType, unit: HKUnit.meterUnit(with: .centi))
        }
        if let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            self.weightKg = await fetchLatestQuantitySample(for: weightType, unit: HKUnit.gramUnit(with: .kilo))
        }
        
        // 4. Read Vitals & Cardiovascular
        if let restingType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            self.restingHeartRate = await fetchLatestQuantitySample(for: restingType, unit: HKUnit.count().unitDivided(by: .minute()))
        }
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            self.latestHeartRate = await fetchLatestQuantitySample(for: hrType, unit: HKUnit.count().unitDivided(by: .minute()))
        }
        if let o2Type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
            self.bloodOxygenSpO2 = await fetchLatestQuantitySample(for: o2Type, unit: HKUnit.percent())
        }
        if let respType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) {
            self.respiratoryRate = await fetchLatestQuantitySample(for: respType, unit: HKUnit.count().unitDivided(by: .minute()))
        }
        if let tempType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) {
            self.bodyTemperatureCelsius = await fetchLatestQuantitySample(for: tempType, unit: HKUnit.degreeCelsius())
        }
        
        // 5. Read Blood Pressure Correlation
        if let bp = await fetchLatestBloodPressure() {
            self.bloodPressureSystolic = bp.systolic
            self.bloodPressureDiastolic = bp.diastolic
        }
        
        // 6. Read Today's Cumulative Totals
        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let count = await fetchTodayCumulativeSum(for: stepsType, unit: HKUnit.count())
            self.todaySteps = count != nil ? Int(count!) : nil
        }
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            self.todayActiveCalories = await fetchTodayCumulativeSum(for: energyType, unit: HKUnit.kilocalorie())
        }
        if let distType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            self.todayDistanceKm = await fetchTodayCumulativeSum(for: distType, unit: HKUnit.meterUnit(with: .kilo))
        }
        
        // 7. Read Last Night's Sleep
        self.lastNightSleepHours = await fetchLastNightSleepDuration()
        
        // 8. Update LifeStore Health Profile
        var profile = store.healthProfile
        
        // Only update blood group if Apple Health has a definitive blood type
        if self.bloodType != .unknown {
            profile.bloodGroup = self.bloodType
        }
        if let dob = self.dateOfBirth {
            profile.dateOfBirth = dob
        }
        if let biologicalSex = self.biologicalSex {
            profile.biologicalSex = biologicalSex
        }
        if let h = self.heightCm, h > 0 {
            profile.heightCm = h
        }
        if let w = self.weightKg, w > 0 {
            profile.weightKg = w
        }
        
        // Telemetry
        profile.restingHeartRate = self.restingHeartRate
        profile.latestHeartRate = self.latestHeartRate
        profile.bloodOxygenSpO2 = self.bloodOxygenSpO2
        profile.bloodPressureSystolic = self.bloodPressureSystolic
        profile.bloodPressureDiastolic = self.bloodPressureDiastolic
        profile.todaySteps = self.todaySteps
        profile.todayActiveCalories = self.todayActiveCalories
        profile.todayDistanceKm = self.todayDistanceKm
        profile.lastNightSleepHours = self.lastNightSleepHours
        profile.respiratoryRate = self.respiratoryRate
        profile.bodyTemperatureCelsius = self.bodyTemperatureCelsius
        profile.lastHealthAppSyncDate = Date()
        
        store.updateHealthProfile(profile)
        
        self.lastSyncDate = Date()
        self.isSyncing = false
        HapticManager.success()
        return true
    }
    
    // MARK: - Characteristics Fetcher
    
    private func readCharacteristics() {
        // Blood Type
        if let blood = try? healthStore.bloodType() {
            switch blood.bloodType {
            case .aPositive: self.bloodType = .aPositive
            case .aNegative: self.bloodType = .aNegative
            case .bPositive: self.bloodType = .bPositive
            case .bNegative: self.bloodType = .bNegative
            case .abPositive: self.bloodType = .abPositive
            case .abNegative: self.bloodType = .abNegative
            case .oPositive: self.bloodType = .oPositive
            case .oNegative: self.bloodType = .oNegative
            case .notSet: break
            @unknown default: break
            }
        }
        
        // Date of Birth
        if let dobComponents = try? healthStore.dateOfBirthComponents(),
           let dob = Calendar.current.date(from: dobComponents) {
            self.dateOfBirth = dob
        }
        
        // Biological Sex
        if let sex = try? healthStore.biologicalSex() {
            switch sex.biologicalSex {
            case .male: self.biologicalSex = "Male"
            case .female: self.biologicalSex = "Female"
            case .other: self.biologicalSex = "Other"
            case .notSet: break
            @unknown default: break
            }
        }
    }
    
    // MARK: - Quantity Sample Query
    
    private func fetchLatestQuantitySample(for sampleType: HKQuantityType, unit: HKUnit) async -> Double? {
        await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Cumulative Statistics Query (Today)
    
    private func fetchTodayCumulativeSum(for quantityType: HKQuantityType, unit: HKUnit) async -> Double? {
        await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
            
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                guard let sum = statistics?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sum.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Blood Pressure Correlation Query
    
    private func fetchLatestBloodPressure() async -> (systolic: Double, diastolic: Double)? {
        await withCheckedContinuation { continuation in
            guard let correlationType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure) else {
                continuation.resume(returning: nil)
                return
            }
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKCorrelationQuery(
                type: correlationType,
                predicate: nil,
                samplePredicates: nil
            ) { _, correlations, error in
                guard let bpSample = correlations?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                guard let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
                      let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
                    continuation.resume(returning: nil)
                    return
                }
                let mmhg = HKUnit.millimeterOfMercury()
                
                var sys: Double?
                var dia: Double?
                
                for sample in bpSample.objects {
                    if let qSample = sample as? HKQuantitySample {
                        if qSample.quantityType == systolicType {
                            sys = qSample.quantity.doubleValue(for: mmhg)
                        } else if qSample.quantityType == diastolicType {
                            dia = qSample.quantity.doubleValue(for: mmhg)
                        }
                    }
                }
                
                if let s = sys, let d = dia {
                    continuation.resume(returning: (s, d))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Sleep Analysis Query
    
    private func fetchLastNightSleepDuration() async -> Double? {
        await withCheckedContinuation { continuation in
            guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
                continuation.resume(returning: nil)
                return
            }
            let calendar = Calendar.current
            let now = Date()
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
                continuation.resume(returning: nil)
                return
            }
            let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictEndDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let categorySamples = samples as? [HKCategorySample], !categorySamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                
                var totalSeconds: TimeInterval = 0
                for s in categorySamples {
                    if s.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                        s.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                        s.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                        s.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                        totalSeconds += s.endDate.timeIntervalSince(s.startDate)
                    }
                }
                
                if totalSeconds > 0 {
                    continuation.resume(returning: totalSeconds / 3600.0)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
}
