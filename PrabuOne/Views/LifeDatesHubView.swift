import SwiftUI

/// Family Birthdays, Anniversaries, and Milestone Events Hub.
public struct LifeDatesHubView: View {
    @ObservedObject var store: LifeStore
    @State private var showingAddDate = false
    @State private var selectedItemToEdit: LifeItem? = nil
    
    public init(store: LifeStore) {
        self.store = store
    }
    
    private var birthdayItems: [LifeItem] {
        store.items(for: .birthday).sorted { $0.daysRemaining < $1.daysRemaining }
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Banner
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Never Forget a Moment")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("Smart reminders 30d, 7d, 1d, and on the day")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "gift.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.pink)
                }
                .padding(16)
                .background(Color.pink.opacity(0.1))
                .cornerRadius(16)
                
                // List of Life Dates
                VStack(spacing: 14) {
                    if birthdayItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "gift")
                                .font(.system(size: 36))
                                .foregroundColor(.pink.opacity(0.6))
                            Text("No Birthdays or Anniversaries")
                                .font(.headline)
                            Text("Tap + above to add family milestones.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 32)
                    } else {
                        ForEach(birthdayItems) { item in
                            LifeDateCard(item: item, onEdit: {
                                selectedItemToEdit = item
                            })
                            .contextMenu {
                                Button {
                                    selectedItemToEdit = item
                                } label: {
                                    Label("Edit Event", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive) {
                                    withAnimation {
                                        store.deleteItem(item)
                                    }
                                } label: {
                                    Label("Delete Event", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .navigationTitle("Birthdays & Life")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    HapticManager.light()
                    showingAddDate = true
                }) {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingAddDate) {
            AddLifeDateSheet(store: store)
        }
        .sheet(item: $selectedItemToEdit) { item in
            EditLifeDateSheet(store: store, item: item)
        }
    }
}

/// Card showing milestone countdown and gift notes.
struct LifeDateCard: View {
    let item: LifeItem
    var onEdit: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.pink.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: "birthday.cake.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.pink)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 17, weight: .semibold))
                
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                if let notes = item.notes {
                    Text("💡 \(notes)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(item.daysRemaining)")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(.pink)
                Text("DAYS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}

/// Sheet for adding birthday or anniversary.
struct AddLifeDateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var name = ""
    @State private var relationship = "Family"
    @State private var eventDate = Date()
    @State private var giftNotes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Person or Event") {
                    TextField("Name (e.g. Thaya, Dhanshika)", text: $name)
                    TextField("Event Description (e.g. Birthday, Anniversary)", text: $relationship)
                }
                
                Section("Date") {
                    DatePicker("Date", selection: $eventDate, displayedComponents: [.date])
                }
                
                Section("Gift & Planning Notes") {
                    TextField("Ideas, dinner reservations, gift plans", text: $giftNotes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Add Life Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let item = LifeItem(
                            title: "\(name)'s \(relationship)",
                            subtitle: "Annual Celebration",
                            category: .birthday,
                            dueDate: eventDate,
                            repeatFrequency: .yearly,
                            notes: giftNotes.isEmpty ? nil : giftNotes
                        )
                        store.addItem(item)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

/// Sheet for editing an existing milestone or birthday event.
struct EditLifeDateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    let item: LifeItem
    
    @State private var title = ""
    @State private var subtitle = ""
    @State private var eventDate = Date()
    @State private var giftNotes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Person & Event") {
                    TextField("Title (e.g. Thaya's Birthday)", text: $title)
                    TextField("Description (e.g. Annual Celebration)", text: $subtitle)
                }
                
                Section("Event Date") {
                    DatePicker("Date", selection: $eventDate, displayedComponents: [.date])
                }
                
                Section("Gift & Planning Notes") {
                    TextField("Ideas, dinner reservations, gift plans", text: $giftNotes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Edit Life Date")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                title = item.title
                subtitle = item.subtitle
                eventDate = item.dueDate
                giftNotes = item.notes ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = item
                        updated.title = title.trimmingCharacters(in: .whitespaces)
                        updated.subtitle = subtitle.trimmingCharacters(in: .whitespaces)
                        updated.dueDate = eventDate
                        updated.notes = giftNotes.isEmpty ? nil : giftNotes
                        store.updateItem(updated)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
