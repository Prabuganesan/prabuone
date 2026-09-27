import SwiftUI

/// Secure Digital Vault for critical vehicle, personal, and property documents.
public struct DocumentVaultView: View {
    @ObservedObject var store: LifeStore
    @State private var showingAddDocument = false
    @State private var copiedToastText: String? = nil
    
    public init(store: LifeStore) {
        self.store = store
    }
    
    public var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.documents.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No Documents in Vault")
                                .font(.headline)
                            Text("Store vehicle RC, DL, Passport, Insurance, and PUC certificates.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 40)
                    } else {
                        ForEach(store.documents) { doc in
                            DocumentCard(document: doc, onCopy: {
                                UIPasteboard.general.string = doc.documentNumber
                                HapticManager.success()
                                withAnimation {
                                    copiedToastText = "Copied \(doc.documentNumber)"
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        copiedToastText = nil
                                    }
                                }
                            })
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = doc.documentNumber
                                    HapticManager.success()
                                } label: {
                                    Label("Copy Document Number", systemImage: "doc.on.doc")
                                }
                                
                                Button(role: .destructive) {
                                    withAnimation {
                                        store.deleteDocument(doc)
                                    }
                                } label: {
                                    Label("Delete Document", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            
            // Copied Toast
            if let toast = copiedToastText {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .shadow(radius: 6)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("Document Vault")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    HapticManager.light()
                    showingAddDocument = true
                }) {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingAddDocument) {
            AddDocumentSheet(store: store)
        }
    }
}

/// Visual card for stored document.
struct DocumentCard: View {
    let document: DocumentRecord
    let onCopy: () -> Void
    
    private var iconName: String {
        switch document.documentType {
        case "Passport": return "globe.americas.fill"
        case "Driving License": return "person.text.rectangle.fill"
        case "RC Book": return "car.fill"
        case "Insurance Policy": return "shield.checkerboard"
        case "PUC Certificate": return "leaf.fill"
        case "Aadhaar Card", "PAN Card": return "person.crop.square.filled.and.at.rectangle"
        default: return "doc.text.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.teal.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: iconName)
                        .foregroundColor(.teal)
                        .font(.system(size: 20))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.title)
                        .font(.system(size: 16, weight: .semibold))
                    Text(document.documentType)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                statusBadge
            }
            
            Divider()
            
            HStack {
                Button(action: onCopy) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("DOCUMENT NUMBER")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                                .foregroundColor(.teal)
                        }
                        Text(document.documentNumber)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if let expiry = document.expiryDate {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("EXPIRES")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(formatDate(expiry))
                            .font(.system(size: 13, weight: .medium))
                    }
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        if document.isExpired {
            Text("EXPIRED")
                .font(.system(size: 9, weight: .black))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(4)
        } else if document.isExpiringSoon {
            Text("EXPIRING SOON")
                .font(.system(size: 9, weight: .black))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(4)
        } else {
            Text("VALID")
                .font(.system(size: 9, weight: .black))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(4)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

/// Sheet for adding a new document to the vault.
struct AddDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var title = ""
    @State private var documentType = "RC Book"
    @State private var documentNumber = ""
    @State private var hasExpiry = true
    @State private var expiryDate = Date().addingTimeInterval(86400 * 365)
    
    let types = ["RC Book", "Driving License", "Passport", "Aadhaar Card", "PAN Card", "Insurance Policy", "PUC Certificate", "Agreement"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Document Information") {
                    TextField("Document Name (e.g. Kia Sonet RC)", text: $title)
                    Picker("Type", selection: $documentType) {
                        ForEach(types, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    TextField("Document Number / ID", text: $documentNumber)
                }
                
                Section("Validity") {
                    Toggle("Has Expiry Date", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: [.date])
                    }
                }
            }
            .navigationTitle("Add Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let doc = DocumentRecord(
                            title: title,
                            documentType: documentType,
                            documentNumber: documentNumber,
                            expiryDate: hasExpiry ? expiryDate : nil
                        )
                        store.addDocument(doc)
                        dismiss()
                    }
                    .disabled(title.isEmpty || documentNumber.isEmpty)
                }
            }
        }
    }
}
