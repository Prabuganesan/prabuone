import SwiftUI
import HealthKit

/// Dedicated Executive Health Profile & Emergency Medical ID Hub for My One.
/// Displays vital medical information, blood group, emergency contacts, active prescriptions,
/// known allergies, chronic conditions, health insurance, and LIVE TELEMETRY from Apple Health.
public struct HealthProfileHubView: View {
    @ObservedObject var store: LifeStore
    @StateObject private var healthKit = AppleHealthManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingEditProfile = false
    @State private var showingAddContact = false
    @State private var showingAddMedication = false
    @State private var showingAddAllergy = false
    @State private var showingShareMedicalCard = false
    @State private var renderedCardImage: UIImage? = nil
    @State private var toastMessage: String? = nil
    
    public init(store: LifeStore) {
        self.store = store
    }
    
    private var profile: HealthProfileRecord {
        store.healthProfile
    }
    
    public var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 18) {
                    // 1. Hero Emergency Medical Card
                    emergencyMedicalCard
                    
                    // 2. Apple Health Live Sync Banner
                    appleHealthSyncBanner
                    
                    // 3. Apple Health Live Vitals Telemetry Grid
                    liveVitalsTelemetryGrid
                    
                    // 4. Emergency Contacts Section
                    emergencyContactsSection
                    
                    // 5. Allergies & Critical Reactions
                    allergiesSection
                    
                    // 6. Current Regular Medications
                    medicationsSection
                    
                    // 7. Chronic Conditions & Vitals
                    conditionsAndVitalsSection
                    
                    // 8. Mediclaim & Health Insurance
                    healthInsuranceCard
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            
            // Toast HUD
            if let toast = toastMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(toast)
                            .font(.system(size: 13.5, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.88))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(radius: 6)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Medical ID & Health")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: {
                        Task {
                            await healthKit.syncFromAppleHealth(store: store)
                            withAnimation { toastMessage = "Synced with Apple Health" }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation { toastMessage = nil }
                            }
                        }
                    }) {
                        Label("Sync Apple Health", systemImage: "arrow.triangle.2.circlepath")
                    }
                    
                    Button(action: { showingEditProfile = true }) {
                        Label("Edit Health Profile", systemImage: "pencil")
                    }
                    Button(action: { showingAddContact = true }) {
                        Label("Add Emergency Contact", systemImage: "phone.badge.plus")
                    }
                    Button(action: { showingAddMedication = true }) {
                        Label("Add Medication", systemImage: "pills.fill")
                    }
                    Button(action: { showingAddAllergy = true }) {
                        Label("Add Allergy", systemImage: "allergens")
                    }
                    Button(action: { renderAndShareEmergencyCard() }) {
                        Label("Export Emergency Card", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 19))
                        .foregroundColor(.red)
                }
            }
        }
        .task {
            if healthKit.isAvailable {
                await healthKit.syncFromAppleHealth(store: store)
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditHealthProfileSheet(store: store)
        }
        .sheet(isPresented: $showingAddContact) {
            AddEmergencyContactSheet(store: store)
        }
        .sheet(isPresented: $showingAddMedication) {
            AddMedicationSheet(store: store)
        }
        .sheet(isPresented: $showingAddAllergy) {
            AddAllergySheet(store: store)
        }
        .sheet(isPresented: $showingShareMedicalCard) {
            if let img = renderedCardImage {
                ShareSheetView(activityItems: [img])
            }
        }
    }
    
    // MARK: - 1. Hero Emergency Medical Card
    private var emergencyMedicalCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "cross.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                        Text("EMERGENCY MEDICAL ID")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .tracking(0.8)
                    }
                    
                    Text(profile.fullName)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    
                    if profile.lastHealthAppSyncDate != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.red)
                            Text("Apple Health Synchronized")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                // Blood Group Badge
                VStack(spacing: 2) {
                    Text(profile.bloodGroup.rawValue)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("BLOOD")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.85))
                .cornerRadius(12)
                .shadow(color: Color.red.opacity(0.4), radius: 6, x: 0, y: 3)
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            // Vitals Grid: Age, Height, Weight, BMI
            HStack(spacing: 12) {
                vitalPill(title: "Age", value: profile.age != nil ? "\(profile.age!) yrs" : (profile.biologicalSex ?? "N/A"))
                vitalPill(title: "Height", value: profile.heightCm > 0 ? "\(Int(profile.heightCm)) cm" : "N/A")
                vitalPill(title: "Weight", value: profile.weightKg > 0 ? "\(Int(profile.weightKg)) kg" : "N/A")
                if let bmi = profile.bmi {
                    vitalPill(title: "BMI", value: String(format: "%.1f", bmi), subtitle: profile.bmiCategory.title, subColor: profile.bmiCategory.color)
                }
                if profile.isOrganDonor {
                    vitalPill(title: "Donor", value: "YES", subtitle: "Organ", subColor: .green)
                }
            }
            
            // 1-Tap Primary Emergency Call Button
            if let primary = profile.emergencyContacts.first(where: { $0.isPrimary }) ?? profile.emergencyContacts.first {
                Button(action: {
                    callPhoneNumber(primary.phoneNumber)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Call Emergency Contact (\(primary.name) • \(primary.relationship))")
                            .font(.system(size: 13.5, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: Color.red.opacity(0.4), radius: 5, x: 0, y: 2)
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(red: 0.18, green: 0.06, blue: 0.08), Color(red: 0.08, green: 0.03, blue: 0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    private func vitalPill(title: String, value: String, subtitle: String? = nil, subColor: Color = .secondary) -> some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(subColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .cornerRadius(8)
    }
    
    // MARK: - 2. Apple Health Live Sync Banner
    private var appleHealthSyncBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.18))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Apple Health")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if healthKit.isSyncing {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Reading...")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.red)
                        }
                    } else if healthKit.isAuthorized || profile.lastHealthAppSyncDate != nil {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Connected")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                        }
                    } else {
                        Text("Not Linked")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
                
                if let lastSync = profile.lastHealthAppSyncDate ?? healthKit.lastSyncDate {
                    Text("Last read: \(formattedTimeAgo(lastSync))")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                } else {
                    Text("Auto-reads blood group, vitals & metrics")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    await healthKit.syncFromAppleHealth(store: store)
                    withAnimation {
                        toastMessage = "Synced with Apple Health"
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { toastMessage = nil }
                    }
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: healthKit.isSyncing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                    Text(healthKit.isSyncing ? "Reading..." : "Sync Now")
                        .font(.system(size: 12, weight: .bold))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Color.red.opacity(0.14))
                .foregroundColor(.red)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(healthKit.isSyncing)
        }
        .padding(13)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.18), lineWidth: 1)
        )
    }
    
    // MARK: - 3. Apple Health Live Vitals Telemetry Grid
    private var liveVitalsTelemetryGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                    Text("Live Vitals & Telemetry")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                Spacer()
                Text("HealthKit")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.12))
                    .foregroundColor(.red)
                    .cornerRadius(4)
            }
            
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                telemetryCard(
                    icon: "heart.fill",
                    color: .red,
                    title: "Resting Heart Rate",
                    value: profile.formattedRestingHR ?? (healthKit.restingHeartRate != nil ? "\(Int(healthKit.restingHeartRate!)) bpm" : "—"),
                    status: (profile.restingHeartRate ?? healthKit.restingHeartRate) != nil ? "Resting" : "Awaiting"
                )
                
                telemetryCard(
                    icon: "lungs.fill",
                    color: .cyan,
                    title: "Blood Oxygen (SpO2)",
                    value: profile.formattedSpO2 ?? (healthKit.bloodOxygenSpO2 != nil ? "\(Int(healthKit.bloodOxygenSpO2! * 100))%" : "—"),
                    status: (profile.bloodOxygenSpO2 ?? healthKit.bloodOxygenSpO2) != nil ? "Optimal" : "Awaiting"
                )
                
                telemetryCard(
                    icon: "gauge.with.needle.fill",
                    color: .purple,
                    title: "Blood Pressure",
                    value: profile.formattedBloodPressure ?? (healthKit.bloodPressureSystolic != nil ? "\(Int(healthKit.bloodPressureSystolic!))/\(Int(healthKit.bloodPressureDiastolic!))" : "—/—"),
                    status: profile.bloodPressureSystolic != nil ? "Optimal" : "mmHg"
                )
                
                telemetryCard(
                    icon: "figure.walk",
                    color: .green,
                    title: "Today's Steps",
                    value: profile.formattedTodaySteps ?? (healthKit.todaySteps != nil ? "\(healthKit.todaySteps!) steps" : "—"),
                    status: "Daily Total"
                )
                
                telemetryCard(
                    icon: "flame.fill",
                    color: .orange,
                    title: "Active Burn",
                    value: profile.todayActiveCalories != nil ? "\(Int(profile.todayActiveCalories!)) kcal" : (healthKit.todayActiveCalories != nil ? "\(Int(healthKit.todayActiveCalories!)) kcal" : "—"),
                    status: "Calories"
                )
                
                telemetryCard(
                    icon: "bed.double.fill",
                    color: .indigo,
                    title: "Last Night Sleep",
                    value: profile.formattedSleepHours ?? (healthKit.lastNightSleepHours != nil ? String(format: "%.1f hrs", healthKit.lastNightSleepHours!) : "—"),
                    status: "Sleep Rest"
                )
                
                telemetryCard(
                    icon: "wind",
                    color: .teal,
                    title: "Respiratory Rate",
                    value: profile.respiratoryRate != nil ? "\(Int(profile.respiratoryRate!)) br/min" : (healthKit.respiratoryRate != nil ? "\(Int(healthKit.respiratoryRate!)) br/min" : "—"),
                    status: "Breathing"
                )
                
                telemetryCard(
                    icon: "scalemass.fill",
                    color: .blue,
                    title: "Weight & BMI",
                    value: profile.weightKg > 0 ? "\(Int(profile.weightKg)) kg" : (healthKit.weightKg != nil ? "\(Int(healthKit.weightKg!)) kg" : "—"),
                    status: profile.bmi != nil ? String(format: "BMI %.1f", profile.bmi!) : "Body Mass"
                )
            }
        }
    }
    
    private func telemetryCard(icon: String, color: Color, title: String, value: String, status: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.18))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(color)
                }
                Spacer()
                Text(status)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }
            
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Text(value)
                .font(.system(size: 16.5, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.16), lineWidth: 1)
        )
    }
    
    private func formattedTimeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            return "\(seconds / 60)m ago"
        } else if seconds < 86400 {
            return "\(seconds / 3600)h ago"
        } else {
            let df = DateFormatter()
            df.dateFormat = "d MMM"
            return df.string(from: date)
        }
    }
    
    // MARK: - 4. Emergency Contacts Section
    private var emergencyContactsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "phone.circle.fill")
                        .foregroundColor(.green)
                    Text("Emergency Contacts (\(profile.emergencyContacts.count))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                Spacer()
                Button(action: { showingAddContact = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(6)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            
            if profile.emergencyContacts.isEmpty {
                emptyPlaceholder(title: "No Emergency Contacts", detail: "Add next of kin or physician to contact in an emergency.")
            } else {
                ForEach(profile.emergencyContacts) { contact in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(contact.isPrimary ? Color.red.opacity(0.18) : Color.green.opacity(0.18))
                                .frame(width: 40, height: 40)
                            Image(systemName: contact.isPrimary ? "star.fill" : "phone.fill")
                                .font(.system(size: 16))
                                .foregroundColor(contact.isPrimary ? .red : .green)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(contact.name)
                                    .font(.system(size: 14.5, weight: .semibold))
                                if contact.isPrimary {
                                    Text("PRIMARY")
                                        .font(.system(size: 8.5, weight: .black))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.15))
                                        .foregroundColor(.red)
                                        .cornerRadius(4)
                                }
                            }
                            Text("\(contact.relationship) • \(contact.phoneNumber)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Call & WhatsApp buttons
                        HStack(spacing: 8) {
                            Button(action: {
                                callPhoneNumber(contact.phoneNumber)
                            }) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.green)
                                    .padding(8)
                                    .background(Color.green.opacity(0.14))
                                    .clipShape(Circle())
                            }
                            
                            Button(action: {
                                openWhatsApp(contact.phoneNumber)
                            }) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.blue)
                                    .padding(8)
                                    .background(Color.blue.opacity(0.14))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                    .contextMenu {
                        Button(role: .destructive) {
                            store.deleteEmergencyContact(id: contact.id)
                        } label: {
                            Label("Delete Contact", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 5. Allergies & Critical Reactions
    private var allergiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "allergens")
                        .foregroundColor(.orange)
                    Text("Allergies & Critical Reactions (\(profile.allergies.count))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                Spacer()
                Button(action: { showingAddAllergy = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(6)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            
            if profile.allergies.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("No Known Medical or Drug Allergies Recorded.")
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.08))
                .cornerRadius(12)
            } else {
                ForEach(profile.allergies) { allergy in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(allergy.severityColor.opacity(0.18))
                                .frame(width: 36, height: 36)
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 15))
                                .foregroundColor(allergy.severityColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(allergy.allergen)
                                .font(.system(size: 14.5, weight: .semibold))
                            Text("Reaction: \(allergy.reaction)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(allergy.severity.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(allergy.severityColor.opacity(0.16))
                            .foregroundColor(allergy.severityColor)
                            .cornerRadius(6)
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                    .contextMenu {
                        Button(role: .destructive) {
                            store.deleteAllergy(id: allergy.id)
                        } label: {
                            Label("Delete Allergy", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 6. Current Regular Medications
    private var medicationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "pills.fill")
                        .foregroundColor(.purple)
                    Text("Active Medications (\(profile.medications.count))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                Spacer()
                Button(action: { showingAddMedication = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(6)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            
            if profile.medications.isEmpty {
                emptyPlaceholder(title: "No Daily Prescriptions", detail: "Add regular medicines, dosage, and schedule.")
            } else {
                ForEach(profile.medications) { med in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.18))
                                .frame(width: 38, height: 38)
                            Image(systemName: "pills.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.purple)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(med.name)
                                    .font(.system(size: 14.5, weight: .semibold))
                                Text(med.dosage)
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.12))
                                    .foregroundColor(.purple)
                                    .cornerRadius(4)
                            }
                            
                            Text("\(med.frequency) • \(med.instructions)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                    .contextMenu {
                        Button(role: .destructive) {
                            store.deleteMedication(id: med.id)
                        } label: {
                            Label("Delete Medication", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 7. Chronic Conditions & Vitals
    private var conditionsAndVitalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Chronic Conditions & Medical Notes")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 10) {
                if !profile.chronicConditions.isEmpty {
                    Text("Diagnosed Conditions:")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(profile.chronicConditions, id: \.self) { condition in
                                HStack(spacing: 4) {
                                    Image(systemName: "cross.circle.fill")
                                        .font(.system(size: 10))
                                    Text(condition)
                                        .font(.system(size: 11.5, weight: .semibold))
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color.red.opacity(0.12))
                                .foregroundColor(.red)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                if !profile.medicalNotes.isEmpty {
                    Divider()
                    Text("Clinical Notes / Instructions:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(profile.medicalNotes)
                        .font(.system(size: 12.5))
                        .foregroundColor(.primary)
                }
            }
            .padding(14)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(14)
        }
    }
    
    // MARK: - 8. Mediclaim & Health Insurance
    private var healthInsuranceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(.emeraldAccent)
                Text("Mediclaim & Health Insurance")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.insurance.providerName.isEmpty ? "Star Health / Mediclaim" : profile.insurance.providerName)
                            .font(.system(size: 16, weight: .bold))
                        Text("Policy No: \(profile.insurance.policyNumber.isEmpty ? "Not Provided" : profile.insurance.policyNumber)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("SUM INSURED")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(profile.insurance.formattedSumInsured)
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            .foregroundColor(.emeraldAccent)
                    }
                }
                
                if !profile.insurance.tpaName.isEmpty {
                    HStack {
                        Text("TPA Desk:")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(profile.insurance.tpaName)
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                    }
                }
                
                if !profile.insurance.cashlessHotline.isEmpty {
                    Button(action: {
                        callPhoneNumber(profile.insurance.cashlessHotline)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "cross.case.fill")
                                .font(.system(size: 12))
                            Text("Call 24/7 Cashless Hospitalization Hotline: \(profile.insurance.cashlessHotline)")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.emeraldAccent.opacity(0.15))
                        .foregroundColor(.emeraldAccent)
                        .cornerRadius(10)
                    }
                }
            }
            .padding(14)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(14)
        }
    }
    
    private func emptyPlaceholder(title: String, detail: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(.primary)
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func callPhoneNumber(_ num: String) {
        let clean = num.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "tel://\(clean)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openWhatsApp(_ num: String) {
        let clean = num.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "https://wa.me/\(clean)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func renderAndShareEmergencyCard() {
        HapticManager.light()
        let renderer = ImageRenderer(content:
            emergencyMedicalCard
                .frame(width: 380)
                .padding(20)
                .background(Color.black)
        )
        renderer.scale = 2.0
        if let uiImg = renderer.uiImage {
            self.renderedCardImage = uiImg
            self.showingShareMedicalCard = true
        }
    }
}

// MARK: - Edit Health Profile Sheet
struct EditHealthProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var fullName: String = ""
    @State private var bloodGroup: BloodGroup = .unknown
    @State private var heightString: String = ""
    @State private var weightString: String = ""
    @State private var isOrganDonor: Bool = true
    @State private var chronicConditionsText: String = ""
    @State private var medicalNotes: String = ""
    
    @State private var insuranceProvider: String = ""
    @State private var insurancePolicyNo: String = ""
    @State private var insuranceTpa: String = ""
    @State private var insuranceSumInsuredString: String = ""
    @State private var insuranceCashlessHotline: String = ""
    @State private var isImportingFromHealth = false
    
    init(store: LifeStore) {
        self._store = ObservedObject(wrappedValue: store)
        let p = store.healthProfile
        _fullName = State(initialValue: p.fullName)
        _bloodGroup = State(initialValue: p.bloodGroup)
        _heightString = State(initialValue: p.heightCm > 0 ? "\(Int(p.heightCm))" : "")
        _weightString = State(initialValue: p.weightKg > 0 ? "\(Int(p.weightKg))" : "")
        _isOrganDonor = State(initialValue: p.isOrganDonor)
        _chronicConditionsText = State(initialValue: p.chronicConditions.joined(separator: ", "))
        _medicalNotes = State(initialValue: p.medicalNotes)
        
        _insuranceProvider = State(initialValue: p.insurance.providerName)
        _insurancePolicyNo = State(initialValue: p.insurance.policyNumber)
        _insuranceTpa = State(initialValue: p.insurance.tpaName)
        _insuranceSumInsuredString = State(initialValue: p.insurance.sumInsured > 0 ? String(format: "%.0f", p.insurance.sumInsured) : "")
        _insuranceCashlessHotline = State(initialValue: p.insurance.cashlessHotline)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(action: {
                        isImportingFromHealth = true
                        Task {
                            await AppleHealthManager.shared.syncFromAppleHealth(store: store)
                            let p = store.healthProfile
                            fullName = p.fullName
                            bloodGroup = p.bloodGroup
                            if p.heightCm > 0 { heightString = "\(Int(p.heightCm))" }
                            if p.weightKg > 0 { weightString = "\(Int(p.weightKg))" }
                            isImportingFromHealth = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text(isImportingFromHealth ? "Reading from Apple Health..." : "Import Vitals from Apple Health")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.red)
                            Spacer()
                            if isImportingFromHealth {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                } footer: {
                    Text("Auto-fills blood group, body height, and weight directly from your Apple Health profile.")
                }
                
                Section("Personal Vitals") {
                    TextField("Full Name", text: $fullName)
                    Picker("Blood Group", selection: $bloodGroup) {
                        ForEach(BloodGroup.allCases) { bg in
                            Text(bg.rawValue).tag(bg)
                        }
                    }
                    HStack {
                        TextField("Height (cm)", text: $heightString)
                            .keyboardType(.numberPad)
                        TextField("Weight (kg)", text: $weightString)
                            .keyboardType(.numberPad)
                    }
                    Toggle("Organ Donor", isOn: $isOrganDonor)
                }
                
                Section("Chronic Conditions & Allergies") {
                    TextField("Chronic Conditions (comma separated)", text: $chronicConditionsText)
                    TextField("Doctor / Clinical Notes", text: $medicalNotes, axis: .vertical)
                        .lineLimit(3)
                }
                
                Section("Health Insurance / Mediclaim") {
                    TextField("Insurance Company (e.g. Star Health)", text: $insuranceProvider)
                    TextField("Policy Number", text: $insurancePolicyNo)
                    TextField("TPA Desk Name", text: $insuranceTpa)
                    TextField("Sum Insured (₹)", text: $insuranceSumInsuredString)
                        .keyboardType(.numberPad)
                    TextField("24/7 Cashless Hospitalization Hotline", text: $insuranceCashlessHotline)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Edit Health Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                }
            }
        }
    }
    
    private func saveProfile() {
        var p = store.healthProfile
        p.fullName = fullName.trimmingCharacters(in: .whitespaces)
        p.bloodGroup = bloodGroup
        p.heightCm = Double(heightString) ?? 0
        p.weightKg = Double(weightString) ?? 0
        p.isOrganDonor = isOrganDonor
        p.chronicConditions = chronicConditionsText.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        p.medicalNotes = medicalNotes.trimmingCharacters(in: .whitespaces)
        
        p.insurance.providerName = insuranceProvider.trimmingCharacters(in: .whitespaces)
        p.insurance.policyNumber = insurancePolicyNo.trimmingCharacters(in: .whitespaces)
        p.insurance.tpaName = insuranceTpa.trimmingCharacters(in: .whitespaces)
        p.insurance.sumInsured = Double(insuranceSumInsuredString) ?? 0
        p.insurance.cashlessHotline = insuranceCashlessHotline.trimmingCharacters(in: .whitespaces)
        
        store.updateHealthProfile(p)
        dismiss()
    }
}

// MARK: - Add Emergency Contact Sheet
struct AddEmergencyContactSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var name: String = ""
    @State private var relationship: String = "Spouse"
    @State private var phoneNumber: String = ""
    @State private var isPrimary: Bool = false
    
    private let relationships = ["Spouse", "Parent", "Sibling", "Child", "Doctor", "Friend", "Colleague", "Other"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Contact Details") {
                    TextField("Name", text: $name)
                    Picker("Relationship", selection: $relationship) {
                        ForEach(relationships, id: \.self) { r in
                            Text(r).tag(r)
                        }
                    }
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    Toggle("Primary Emergency Contact", isOn: $isPrimary)
                }
            }
            .navigationTitle("New Emergency Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let contact = EmergencyContact(name: name, relationship: relationship, phoneNumber: phoneNumber, isPrimary: isPrimary)
                        store.addEmergencyContact(contact)
                        dismiss()
                    }
                    .disabled(name.isEmpty || phoneNumber.isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Medication Sheet
struct AddMedicationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var name: String = ""
    @State private var dosage: String = ""
    @State private var frequency: String = "Once Daily"
    @State private var instructions: String = "After meals"
    
    private let frequencies = ["Once Daily", "Twice Daily", "Thrice Daily", "As Needed (SOS)", "Weekly"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Prescription Details") {
                    TextField("Medicine Name (e.g. Telmisartan, Metformin)", text: $name)
                    TextField("Dosage (e.g. 40mg, 500mg, 1 tablet)", text: $dosage)
                    Picker("Frequency", selection: $frequency) {
                        ForEach(frequencies, id: \.self) { f in
                            Text(f).tag(f)
                        }
                    }
                    TextField("Timing / Instructions (e.g. Morning after breakfast)", text: $instructions)
                }
            }
            .navigationTitle("New Daily Prescription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let med = MedicationRecord(name: name, dosage: dosage, frequency: frequency, instructions: instructions)
                        store.addMedication(med)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Allergy Sheet
struct AddAllergySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var allergen: String = ""
    @State private var reaction: String = ""
    @State private var severity: String = "Moderate"
    
    private let severities = ["Mild", "Moderate", "Severe / Anaphylactic"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Allergy Details") {
                    TextField("Allergen (e.g. Penicillin, Peanuts, Sulfa)", text: $allergen)
                    TextField("Reaction (e.g. Hives, Breathing issue, Swelling)", text: $reaction)
                    Picker("Severity", selection: $severity) {
                        ForEach(severities, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }
                }
            }
            .navigationTitle("Record Allergy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let allergy = AllergyRecord(allergen: allergen, reaction: reaction, severity: severity)
                        store.addAllergy(allergy)
                        dismiss()
                    }
                    .disabled(allergen.isEmpty)
                }
            }
        }
    }
}
