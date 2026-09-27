import SwiftUI

/// Sheet view allowing the user to add any commitment, renewal, birthday, or vehicle event.
public struct AddLifeItemView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var category: LifeCategory = .creditCard
    @State private var dueDate: Date = Date().addingTimeInterval(86400 * 3) // 3 days from now
    @State private var amountText: String = ""
    @State private var repeatFrequency: RepeatFrequency = .monthly
    @State private var notes: String = ""
    
    public init(store: LifeStore) {
        self.store = store
    }
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Title (e.g. HDFC Card, Sonet Service)", text: $title)
                    TextField("Subtitle (e.g. Outstanding bill, 20k km)", text: $subtitle)
                    
                    Picker("Category", selection: $category) {
                        ForEach(LifeCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.iconName).tag(cat)
                        }
                    }
                }
                
                Section("Timeline & Amount") {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])
                    
                    HStack {
                        Text("₹")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        TextField("Amount (Optional)", text: $amountText)
                            .keyboardType(.numberPad)
                    }
                    
                    Picker("Repeat", selection: $repeatFrequency) {
                        ForEach(RepeatFrequency.allCases) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Additional details, account / policy number", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Life Commitment")
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
    
    private func saveItem() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ""))
        let newItem = LifeItem(
            title: title.trimmingCharacters(in: .whitespaces),
            subtitle: subtitle.trimmingCharacters(in: .whitespaces),
            category: category,
            dueDate: dueDate,
            amount: amount,
            repeatFrequency: repeatFrequency,
            notes: notes.isEmpty ? nil : notes
        )
        
        store.addItem(newItem)
        dismiss()
    }
}
