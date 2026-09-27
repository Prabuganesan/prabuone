import SwiftUI

/// Complete Vehicle Hub tailored for Kia Sonet tracking:
/// Service timeline, odometer telemetry, fuel logs, and insurance/PUC countdowns.
public struct VehicleHubView: View {
    @ObservedObject var store: LifeStore
    @State private var showingAddService = false
    @State private var showingAddFuel = false
    @State private var showingUpdateOdometer = false
    @State private var showingUpdateServiceKm = false
    @State private var showingUpdateInsurance = false
    @State private var showingUpdatePUC = false
    @State private var showingUpdateFastag = false
    @State private var showingEditProfile = false
    @State private var selectedServiceToEdit: VehicleServiceRecord? = nil
    @State private var selectedFuelToEdit: FuelRecord? = nil
    @State private var newOdometerText = ""
    @State private var newServiceKmText = ""
    @State private var newFastagText = ""
    
    public init(store: LifeStore) {
        self.store = store
    }
    
    private var vehicle: VehicleProfile {
        store.vehicleProfile
    }
    
    private var insuranceDaysLeft: Int {
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: vehicle.insuranceExpiryDate).day ?? 0
        return max(0, diff)
    }
    
    private var pucDaysLeft: Int {
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: vehicle.pucExpiryDate).day ?? 0
        return max(0, diff)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Vehicle Hero Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(vehicle.makeModel)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(vehicle.registrationNumber.isEmpty ? vehicle.fuelType : "\(vehicle.registrationNumber) • \(vehicle.fuelType)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "car.side.fill")
                            .font(.system(size: 38))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ODOMETER")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                            Text("\(vehicle.currentOdometerKm) km")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            HapticManager.light()
                            newOdometerText = vehicle.currentOdometerKm > 0 ? "\(vehicle.currentOdometerKm)" : ""
                            showingUpdateOdometer = true
                        }) {
                            Text("Update km")
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(20)
                .background(LinearGradient(
                    colors: [Color(red: 0.85, green: 0.35, blue: 0.1), Color(red: 0.95, green: 0.5, blue: 0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .cornerRadius(20)
                .shadow(color: Color.orange.opacity(0.25), radius: 8, x: 0, y: 4)
                
                // Key Reminders & Health Row - ALL EDITABLE
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    // 1. Next Service (Tap to edit target km)
                    Button(action: {
                        HapticManager.light()
                        newServiceKmText = "\(vehicle.nextServiceDueKm)"
                        showingUpdateServiceKm = true
                    }) {
                        VehicleStatCard(
                            title: "Next Service",
                            value: "\(vehicle.kmUntilService) km",
                            subtitle: "Target \(vehicle.nextServiceDueKm) km (Tap)",
                            icon: "wrench.and.screwdriver.fill",
                            color: .blue
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // 2. Fuel Economy
                    VehicleStatCard(
                        title: "Fuel Economy",
                        value: vehicle.averageFuelEconomy != nil ? "\(String(format: "%.1f", vehicle.averageFuelEconomy!)) km/L" : "--",
                        subtitle: vehicle.averageFuelEconomy != nil ? "\(vehicle.fuelType) avg" : "Log 2 refuels to view",
                        icon: "gauge.with.needle.fill",
                        color: .purple
                    )
                    
                    // 3. FASTag Balance (Tap to edit)
                    Button(action: {
                        HapticManager.light()
                        newFastagText = "\(Int(vehicle.fastagBalance))"
                        showingUpdateFastag = true
                    }) {
                        VehicleStatCard(
                            title: "FASTag Balance",
                            value: "₹\(Int(vehicle.fastagBalance))",
                            subtitle: "Tap to update",
                            icon: "wave.3.forward.circle.fill",
                            color: .teal
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // 4. Insurance (Tap to edit expiry date)
                    Button(action: {
                        HapticManager.light()
                        showingUpdateInsurance = true
                    }) {
                        VehicleStatCard(
                            title: "Insurance",
                            value: "\(insuranceDaysLeft) Days",
                            subtitle: "Expires \(formatDate(vehicle.insuranceExpiryDate))",
                            icon: "shield.checkerboard",
                            color: .green
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // 5. PUC Pollution (Tap to edit expiry date)
                    Button(action: {
                        HapticManager.light()
                        showingUpdatePUC = true
                    }) {
                        VehicleStatCard(
                            title: "PUC Pollution",
                            value: "\(pucDaysLeft) Days",
                            subtitle: "Expires \(formatDate(vehicle.pucExpiryDate))",
                            icon: "leaf.fill",
                            color: .mint
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // 6. Total Service Spend
                    VehicleStatCard(
                        title: "Total Service",
                        value: "₹\(Int(vehicle.totalServiceSpend))",
                        subtitle: "\(vehicle.serviceHistory.count) records logged",
                        icon: "banknote.fill",
                        color: .indigo
                    )
                }
                
                // Quick Actions
                HStack(spacing: 12) {
                    Button(action: {
                        HapticManager.light()
                        showingAddFuel = true
                    }) {
                        Label("Log Fuel", systemImage: "fuelpump.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        HapticManager.light()
                        showingAddService = true
                    }) {
                        Label("Log Service", systemImage: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                
                // Maintenance History Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Service History")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    
                    if vehicle.serviceHistory.isEmpty {
                        Text("No maintenance logs yet.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(vehicle.serviceHistory) { record in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(record.title)
                                        .font(.system(size: 16, weight: .semibold))
                                    Spacer()
                                    Text("₹\(Int(record.cost))")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                    
                                    Button(action: {
                                        selectedServiceToEdit = record
                                    }) {
                                        Image(systemName: "pencil.circle")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 18))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Text("\(record.odometerKm) km • \(record.serviceCenter)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                
                                Text("Replaced: " + record.itemsReplaced.joined(separator: ", "))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(14)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(14)
                            .contextMenu {
                                Button {
                                    selectedServiceToEdit = record
                                } label: {
                                    Label("Edit Service Record", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive) {
                                    store.deleteServiceRecord(id: record.id)
                                } label: {
                                    Label("Delete Entry", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                
                // Fuel History Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fuel Logs")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    
                    ForEach(vehicle.fuelHistory) { fuel in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(String(format: "%.1f", fuel.liters)) Liters \(vehicle.fuelType)")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("At \(fuel.odometerKm) km • ₹\(String(format: "%.1f", fuel.ratePerLiter))/L")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("₹\(Int(fuel.totalCost))")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            
                            Button(action: {
                                selectedFuelToEdit = fuel
                            }) {
                                Image(systemName: "pencil.circle")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 18))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .contextMenu {
                            Button {
                                selectedFuelToEdit = fuel
                            } label: {
                                Label("Edit Fuel Log", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                store.deleteFuelRecord(id: fuel.id)
                            } label: {
                                Label("Delete Log", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .navigationTitle(vehicle.makeModel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    HapticManager.light()
                    showingEditProfile = true
                }) {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 18))
                }
            }
        }
        .alert("Update Odometer", isPresented: $showingUpdateOdometer) {
            TextField("Current Odometer km", text: $newOdometerText)
                .keyboardType(.numberPad)
            Button("Save") {
                if let km = Int(newOdometerText) {
                    store.updateOdometer(newKm: km)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Next Service Due Target", isPresented: $showingUpdateServiceKm) {
            TextField("Next Service Target km (e.g. 50000)", text: $newServiceKmText)
                .keyboardType(.numberPad)
            Button("Save") {
                if let km = Int(newServiceKmText) {
                    store.updateNextServiceKm(newKm: km)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Update FASTag Balance", isPresented: $showingUpdateFastag) {
            TextField("New Balance (₹)", text: $newFastagText)
                .keyboardType(.numberPad)
            Button("Save") {
                if let bal = Double(newFastagText) {
                    store.updateFastagBalance(newBalance: bal)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingUpdateInsurance) {
            EditInsuranceSheet(store: store)
        }
        .sheet(isPresented: $showingUpdatePUC) {
            EditPUCSheet(store: store)
        }
        .sheet(isPresented: $showingAddService) {
            AddServiceSheet(store: store)
        }
        .sheet(isPresented: $showingAddFuel) {
            AddFuelSheet(store: store)
        }
        .sheet(isPresented: $showingEditProfile) {
            EditVehicleProfileSheet(store: store)
        }
        .sheet(item: $selectedServiceToEdit) { record in
            EditServiceSheet(store: store, record: record)
        }
        .sheet(item: $selectedFuelToEdit) { fuel in
            EditFuelSheet(store: store, record: fuel)
        }
    }
}

/// Sheet for editing all vehicle profile metadata.
struct EditVehicleProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var makeModel: String = ""
    @State private var registrationNumber: String = ""
    @State private var fuelType: String = "Diesel"
    @State private var odometerText: String = ""
    @State private var nextServiceKmText: String = ""
    @State private var fastagBalanceText: String = ""
    @State private var insuranceExpiry: Date = Date()
    @State private var pucExpiry: Date = Date()
    
    let fuelTypes = ["Petrol", "Diesel", "Electric", "Hybrid", "CNG"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle Information") {
                    TextField("Make & Model (e.g. Kia Sonet HTX)", text: $makeModel)
                    TextField("Registration No. (e.g. TN 01 AB 1234)", text: $registrationNumber)
                    Picker("Fuel Type", selection: $fuelType) {
                        ForEach(fuelTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }
                
                Section("Telemetry & Service Due") {
                    TextField("Current Odometer (km)", text: $odometerText)
                        .keyboardType(.numberPad)
                    TextField("Next Service Target (km)", text: $nextServiceKmText)
                        .keyboardType(.numberPad)
                    TextField("FASTag Balance (₹)", text: $fastagBalanceText)
                        .keyboardType(.numberPad)
                }
                
                Section("Validity Dates") {
                    DatePicker("Insurance Expiry", selection: $insuranceExpiry, displayedComponents: [.date])
                    DatePicker("PUC Certificate Expiry", selection: $pucExpiry, displayedComponents: [.date])
                }
            }
            .navigationTitle("Edit Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                let v = store.vehicleProfile
                makeModel = v.makeModel
                registrationNumber = v.registrationNumber
                fuelType = v.fuelType
                odometerText = "\(v.currentOdometerKm)"
                nextServiceKmText = "\(v.nextServiceDueKm)"
                fastagBalanceText = "\(Int(v.fastagBalance))"
                insuranceExpiry = v.insuranceExpiryDate
                pucExpiry = v.pucExpiryDate
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var v = store.vehicleProfile
                        v.makeModel = makeModel
                        v.registrationNumber = registrationNumber
                        v.fuelType = fuelType
                        if let odo = Int(odometerText) { v.currentOdometerKm = odo }
                        if let srv = Int(nextServiceKmText) { v.nextServiceDueKm = srv }
                        if let fast = Double(fastagBalanceText) { v.fastagBalance = fast }
                        v.insuranceExpiryDate = insuranceExpiry
                        v.pucExpiryDate = pucExpiry
                        store.updateFullVehicleProfile(v)
                        dismiss()
                    }
                    .disabled(makeModel.isEmpty)
                }
            }
        }
    }
}

/// Quick Sheet for editing Vehicle Insurance expiry date.
struct EditInsuranceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    @State private var expiryDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle Insurance") {
                    DatePicker("Policy Expiry Date", selection: $expiryDate, displayedComponents: [.date])
                }
            }
            .navigationTitle("Update Insurance")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                expiryDate = store.vehicleProfile.insuranceExpiryDate
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateInsuranceExpiry(newDate: expiryDate)
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Quick Sheet for editing Vehicle PUC Certificate expiry date.
struct EditPUCSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    @State private var expiryDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Pollution Certificate (PUC)") {
                    DatePicker("PUC Expiry Date", selection: $expiryDate, displayedComponents: [.date])
                }
            }
            .navigationTitle("Update PUC")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                expiryDate = store.vehicleProfile.pucExpiryDate
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updatePUCExpiry(newDate: expiryDate)
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Stat Card for vehicle parameters.
struct VehicleStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
    }
}

/// Sheet for recording vehicle service.
struct AddServiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var title = "Periodic Service"
    @State private var odometerText = ""
    @State private var costText = ""
    @State private var itemsText = "Engine Oil, Oil Filter"
    @State private var serviceCenter = "Kia Authorized Service Center"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Service Details") {
                    TextField("Title", text: $title)
                    TextField("Odometer (km)", text: $odometerText)
                        .keyboardType(.numberPad)
                    TextField("Total Cost (₹)", text: $costText)
                        .keyboardType(.numberPad)
                    TextField("Service Center", text: $serviceCenter)
                }
                
                Section("Items Replaced (Comma-separated)") {
                    TextField("e.g. Engine Oil, Brake Pads", text: $itemsText)
                }
            }
            .navigationTitle("Log Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let odo = Int(odometerText) ?? store.vehicleProfile.currentOdometerKm
                        let cost = Double(costText) ?? 0
                        let items = itemsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        let record = VehicleServiceRecord(
                            title: title,
                            date: Date(),
                            odometerKm: odo,
                            cost: cost,
                            itemsReplaced: items,
                            serviceCenter: serviceCenter
                        )
                        store.addServiceRecord(record)
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Sheet for logging fuel refill.
struct AddFuelSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var odometerText = ""
    @State private var litersText = ""
    @State private var costText = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Refuel Details") {
                    TextField("Odometer (km)", text: $odometerText)
                        .keyboardType(.numberPad)
                    TextField("Liters", text: $litersText)
                        .keyboardType(.decimalPad)
                    TextField("Total Cost (₹)", text: $costText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Log Fuel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let odo = Int(odometerText) ?? store.vehicleProfile.currentOdometerKm
                        let liters = Double(litersText) ?? 0
                        let cost = Double(costText) ?? 0
                        let record = FuelRecord(
                            date: Date(),
                            odometerKm: odo,
                            liters: liters,
                            totalCost: cost
                        )
                        store.addFuelRecord(record)
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Sheet for editing an existing vehicle service record.
struct EditServiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    let record: VehicleServiceRecord
    
    @State private var title = ""
    @State private var odometerText = ""
    @State private var costText = ""
    @State private var itemsText = ""
    @State private var serviceCenter = ""
    @State private var serviceDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Service Details") {
                    TextField("Title", text: $title)
                    DatePicker("Service Date", selection: $serviceDate, displayedComponents: [.date])
                    TextField("Odometer (km)", text: $odometerText)
                        .keyboardType(.numberPad)
                    TextField("Total Cost (₹)", text: $costText)
                        .keyboardType(.numberPad)
                    TextField("Service Center", text: $serviceCenter)
                }
                
                Section("Items Replaced (Comma-separated)") {
                    TextField("e.g. Engine Oil, Brake Pads", text: $itemsText)
                }
            }
            .navigationTitle("Edit Service Record")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                title = record.title
                odometerText = "\(record.odometerKm)"
                costText = "\(Int(record.cost))"
                itemsText = record.itemsReplaced.joined(separator: ", ")
                serviceCenter = record.serviceCenter
                serviceDate = record.date
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = record
                        updated.title = title
                        updated.date = serviceDate
                        if let odo = Int(odometerText) { updated.odometerKm = odo }
                        if let cost = Double(costText) { updated.cost = cost }
                        updated.itemsReplaced = itemsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        updated.serviceCenter = serviceCenter
                        store.updateServiceRecord(updated)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

/// Sheet for editing an existing fuel record.
struct EditFuelSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    let record: FuelRecord
    
    @State private var odometerText = ""
    @State private var litersText = ""
    @State private var costText = ""
    @State private var fuelDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Refuel Details") {
                    DatePicker("Refuel Date", selection: $fuelDate, displayedComponents: [.date])
                    TextField("Odometer (km)", text: $odometerText)
                        .keyboardType(.numberPad)
                    TextField("Liters", text: $litersText)
                        .keyboardType(.decimalPad)
                    TextField("Total Cost (₹)", text: $costText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Edit Fuel Log")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                odometerText = "\(record.odometerKm)"
                litersText = String(format: "%.2f", record.liters)
                costText = "\(Int(record.totalCost))"
                fuelDate = record.date
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = record
                        updated.date = fuelDate
                        if let odo = Int(odometerText) { updated.odometerKm = odo }
                        if let lit = Double(litersText) { updated.liters = lit }
                        if let cost = Double(costText) { updated.totalCost = cost }
                        store.updateFuelRecord(updated)
                        dismiss()
                    }
                }
            }
        }
    }
}
