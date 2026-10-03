import SwiftUI

/// Sheet view allowing the user to add any commitment, renewal, birthday, or vehicle event.
public struct AddLifeItemView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var category: LifeCategory
    @State private var dueDate: Date = Date().addingTimeInterval(86400 * 3) // 3 days from now
    @State private var amountText: String = ""
    @State private var repeatFrequency: RepeatFrequency = .monthly
    @State private var notes: String = ""
    
    @State private var planTier: String = ""
    @State private var paymentMethod: String = ""
    @State private var accountEmail: String = ""
    @State private var sharedWith: String = ""
    @State private var autoRenew: Bool = true
    @State private var selectedPreset: OTTServicePreset? = nil
    
    public init(store: LifeStore, initialCategory: LifeCategory = .creditCard) {
        self.store = store
        _category = State(initialValue: initialCategory)
    }
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private var effectiveMonthlyBurn: Double {
        let val = Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        switch repeatFrequency {
        case .monthly: return val
        case .quarterly: return val / 3.0
        case .halfYearly: return val / 6.0
        case .yearly: return val / 12.0
        case .never: return val
        }
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    Picker("Category", selection: $category) {
                        ForEach(LifeCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.iconName).tag(cat)
                        }
                    }
                    
                    if category == .subscription {
                        // Quick OTT Presets Carousel
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Popular OTT / Digital Presets")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(popularSubscriptionPresets) { preset in
                                        Button {
                                            HapticManager.selection()
                                            selectPreset(preset)
                                        } label: {
                                            HStack(spacing: 5) {
                                                Image(systemName: preset.icon)
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(preset.brandColor)
                                                Text(preset.name)
                                                    .font(.system(size: 11.5, weight: selectedPreset?.id == preset.id ? .bold : .medium))
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(selectedPreset?.id == preset.id ? preset.brandColor.opacity(0.18) : Color(UIColor.secondarySystemBackground))
                                            .foregroundColor(selectedPreset?.id == preset.id ? preset.brandColor : .primary)
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule().stroke(selectedPreset?.id == preset.id ? preset.brandColor : Color.clear, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        
                        TextField("Service Name (e.g. Netflix, Prime Video)", text: $title)
                        
                        if let preset = selectedPreset, !preset.plans.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Suggested Plans")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(preset.plans) { plan in
                                            Button {
                                                HapticManager.selection()
                                                planTier = plan.name
                                                amountText = "\(Int(plan.price))"
                                                repeatFrequency = plan.frequency
                                            } label: {
                                                Text("\(plan.name) (₹\(Int(plan.price)))")
                                                    .font(.system(size: 11, weight: planTier == plan.name ? .bold : .medium))
                                                    .padding(.horizontal, 9)
                                                    .padding(.vertical, 5)
                                                    .background(planTier == plan.name ? Color.purple.opacity(0.18) : Color(UIColor.secondarySystemBackground))
                                                    .foregroundColor(planTier == plan.name ? .purple : .primary)
                                                    .cornerRadius(8)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        
                        TextField("Plan Tier (e.g. Premium 4K UHD, Family, VIP)", text: $planTier)
                    } else {
                        TextField("Title (e.g. Electricity Bill, Car Service)", text: $title)
                        TextField("Subtitle (e.g. Outstanding bill, 20k km)", text: $subtitle)
                    }
                }
                
                Section("Timeline & Amount") {
                    DatePicker(category == .subscription ? "Next Renewal Date" : "Due Date", selection: $dueDate, displayedComponents: [.date])
                    
                    HStack {
                        Text("₹")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        TextField("Amount (Optional)", text: $amountText)
                            .keyboardType(.numberPad)
                    }
                    
                    Picker("Repeat Frequency", selection: $repeatFrequency) {
                        ForEach(RepeatFrequency.allCases) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    
                    if category == .subscription && effectiveMonthlyBurn > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill").foregroundColor(.purple)
                            Text("Effective Monthly Burn: ₹\(Int(effectiveMonthlyBurn))/month")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.purple)
                        }
                    }
                }
                
                if category == .subscription {
                    Section("Payment & Account Details") {
                        TextField("Payment Method (e.g. HDFC Card, UPI AutoPay)", text: $paymentMethod)
                        TextField("Registered Email / Phone ID", text: $accountEmail)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        TextField("Screens / Family Sharing (e.g. 4 Screens)", text: $sharedWith)
                        Toggle("Auto-Debit (e-Mandate) Active", isOn: $autoRenew)
                    }
                }
                
                Section("Notes") {
                    TextField("Additional details, account / login hints", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(category == .subscription ? "New Subscription" : "New Life Commitment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func selectPreset(_ preset: OTTServicePreset) {
        selectedPreset = preset
        title = preset.name
        if let first = preset.plans.first {
            planTier = first.name
            amountText = "\(Int(first.price))"
            repeatFrequency = first.frequency
        }
    }
    
    private func saveItem() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ""))
        let finalSubtitle: String
        if category == .subscription {
            finalSubtitle = "\(planTier.isEmpty ? "Plan" : planTier) • \(repeatFrequency.rawValue)"
        } else {
            finalSubtitle = subtitle.trimmingCharacters(in: .whitespaces)
        }
        
        let newItem = LifeItem(
            title: title.trimmingCharacters(in: .whitespaces),
            subtitle: finalSubtitle,
            category: category,
            dueDate: dueDate,
            amount: amount,
            repeatFrequency: repeatFrequency,
            isCompleted: false,
            notes: notes.isEmpty ? nil : notes,
            planTier: planTier.isEmpty ? nil : planTier,
            billingCycle: repeatFrequency.rawValue,
            paymentMethod: paymentMethod.isEmpty ? nil : paymentMethod,
            accountEmail: accountEmail.isEmpty ? nil : accountEmail,
            sharedWith: sharedWith.isEmpty ? nil : sharedWith,
            autoRenew: category == .subscription ? autoRenew : nil,
            serviceBrand: selectedPreset?.id ?? (category == .subscription ? title : nil)
        )
        
        store.addItem(newItem)
        dismiss()
    }
}
