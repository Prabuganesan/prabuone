import SwiftUI

/// Dedicated view displaying items belonging to a specific Life Pillar.
public struct CategoryDetailView: View {
    let category: LifeCategory
    @ObservedObject var store: LifeStore
    @State private var showingAddSheet = false
    
    public init(category: LifeCategory, store: LifeStore) {
        self.category = category
        self.store = store
    }
    
    private var categoryItems: [LifeItem] {
        store.items(for: category).sorted { $0.dueDate < $1.dueDate }
    }
    
    public var body: some View {
        List {
            if categoryItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: category.iconName)
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text("No items recorded yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Tap + above to add your first \(category.rawValue.lowercased()) entry.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(categoryItems) { item in
                    LifeItemRow(item: item, store: store, onTogglePaid: {
                        withAnimation {
                            store.toggleCompleted(item)
                        }
                    })
                }
                .onDelete { indexSet in
                    let itemsToDelete = indexSet.map { categoryItems[$0] }
                    for item in itemsToDelete {
                        store.deleteItem(item)
                    }
                }
            }
        }
        .navigationTitle(category.rawValue)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddLifeItemView(store: store)
        }
    }
}

/// Reusable row component for Life Items.
public struct LifeItemRow: View {
    let item: LifeItem
    var store: LifeStore? = nil
    let onTogglePaid: () -> Void
    
    public var body: some View {
        HStack(spacing: 14) {
            // Category Icon with Status Color
            ZStack {
                Circle()
                    .fill(item.isCompleted ? Color.gray.opacity(0.2) : urgencyColor(item.urgency).opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: item.category.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(item.isCompleted ? .gray : urgencyColor(item.urgency))
            }
            
            // Text Details
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .strikethrough(item.isCompleted)
                        .foregroundColor(item.isCompleted ? .secondary : .primary)
                    
                    if !item.isCompleted && item.urgency <= .in7Days {
                        Text(item.urgency.badgeText)
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(urgencyColor(item.urgency))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 6) {
                    Text("\(item.daysRemainingText) • \(item.formattedDueDate)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    if let docId = item.linkedDocumentId, let s = store {
                        LinkedDocumentBadge(documentId: docId, store: s, customLabel: "Document")
                    }
                }
            }
            
            Spacer()
            
            // Amount & Checkbox Action
            VStack(alignment: .trailing, spacing: 6) {
                if let amountStr = item.formattedAmount {
                    Text(amountStr)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(item.isCompleted ? .secondary : .primary)
                }
                
                Button(action: onTogglePaid) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(item.isCompleted ? .green : .secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func urgencyColor(_ urgency: UrgencyLevel) -> Color {
        switch urgency {
        case .overdue: return .red
        case .today: return .red
        case .in3Days: return .orange
        case .in7Days: return .blue
        case .upcoming: return .blue
        }
    }
}
