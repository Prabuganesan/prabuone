import SwiftUI

/// Universal Document Picker and Linker component.
/// Connects documents from Document Vault to any entity in My One (Vehicles, Loans, LIC, Cards, Subscriptions).
public struct UniversalDocumentPickerRow: View {
    let title: String
    @Binding var documentId: UUID?
    @ObservedObject var store: LifeStore
    var suggestedKeywords: [String] = []
    
    @State private var showingSelector = false
    @State private var viewingDocument: DocumentRecord? = nil
    
    public init(
        title: String,
        documentId: Binding<UUID?>,
        store: LifeStore,
        suggestedKeywords: [String] = []
    ) {
        self.title = title
        self._documentId = documentId
        self.store = store
        self.suggestedKeywords = suggestedKeywords
    }
    
    private var linkedDocument: DocumentRecord? {
        guard let id = documentId else { return nil }
        return store.documents.first { $0.id == id }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                if linkedDocument != nil {
                    Button(action: {
                        HapticManager.selection()
                        showingSelector = true
                    }) {
                        Text("Change")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    
                    Text("•")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        HapticManager.selection()
                        documentId = nil
                    }) {
                        Text("Unlink")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if let doc = linkedDocument {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(doc.hasAttachment ? Color.blue.opacity(0.12) : Color.gray.opacity(0.12))
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: doc.attachmentFileType == "pdf" ? "doc.richtext.fill" : (doc.hasAttachment ? "photo.fill" : "doc.text.fill"))
                            .font(.system(size: 17))
                            .foregroundColor(doc.hasAttachment ? .blue : .gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(doc.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        HStack(spacing: 6) {
                            Text(doc.documentType)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            if !doc.documentNumber.isEmpty {
                                Text("•")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                Text(doc.documentNumber)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if doc.hasAttachment {
                        Button(action: {
                            HapticManager.light()
                            viewingDocument = doc
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 10))
                                Text("View")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            } else {
                Button(action: {
                    HapticManager.selection()
                    showingSelector = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "paperclip.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        Text("Choose from Document Vault")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingSelector) {
            DocumentSelectorModalView(
                selectedDocumentId: $documentId,
                store: store,
                suggestedKeywords: suggestedKeywords,
                title: "Select \(title)"
            )
        }
        .sheet(item: $viewingDocument) { doc in
            DocumentAttachmentViewerSheet(document: doc)
        }
    }
}

/// Modal picker sheet to browse, search, and pick a document from the vault, or scan a new one.
public struct DocumentSelectorModalView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDocumentId: UUID?
    @ObservedObject var store: LifeStore
    var suggestedKeywords: [String] = []
    var title: String = "Select Document"
    
    @State private var searchText = ""
    @State private var showingScanner = false
    @State private var previewDocument: DocumentRecord? = nil
    
    private var filteredDocuments: [DocumentRecord] {
        let docs = store.documents
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty { return docs }
        return docs.filter {
            $0.title.lowercased().contains(query) ||
            $0.documentType.lowercased().contains(query) ||
            $0.documentNumber.lowercased().contains(query) ||
            ($0.notes?.lowercased().contains(query) ?? false)
        }
    }
    
    private var suggestedDocuments: [DocumentRecord] {
        guard !suggestedKeywords.isEmpty else { return [] }
        return store.documents.filter { doc in
            suggestedKeywords.contains { kw in
                doc.title.localizedCaseInsensitiveContains(kw) ||
                doc.documentType.localizedCaseInsensitiveContains(kw)
            }
        }
    }
    
    public var body: some View {
        NavigationStack {
            List {
                // Quick Scan Banner
                Section {
                    Button(action: {
                        HapticManager.light()
                        showingScanner = true
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "doc.viewfinder.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Scan New Document Now")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("Multi-page camera scanner with auto-crop & PDF")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "camera.fill")
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Suggested matches if available
                if searchText.isEmpty && !suggestedDocuments.isEmpty {
                    Section("Suggested Documents") {
                        ForEach(suggestedDocuments) { doc in
                            documentRow(doc)
                        }
                    }
                }
                
                // All Documents in Vault
                Section(searchText.isEmpty ? "All Vault Documents (\(filteredDocuments.count))" : "Search Results (\(filteredDocuments.count))") {
                    if filteredDocuments.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text("No matching documents in Vault")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(filteredDocuments) { doc in
                            documentRow(doc)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search by title, type, or number...")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingScanner) {
                DocumentScannerView(store: store)
            }
            .sheet(item: $previewDocument) { doc in
                DocumentAttachmentViewerSheet(document: doc)
            }
        }
    }
    
    private func documentRow(_ doc: DocumentRecord) -> some View {
        Button(action: {
            HapticManager.selection()
            selectedDocumentId = doc.id
            dismiss()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(doc.hasAttachment ? Color.blue.opacity(0.12) : Color.gray.opacity(0.12))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: doc.attachmentFileType == "pdf" ? "doc.richtext.fill" : (doc.hasAttachment ? "photo.fill" : "doc.text.fill"))
                        .font(.system(size: 16))
                        .foregroundColor(doc.hasAttachment ? .blue : .gray)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        Text(doc.documentType)
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                        
                        if !doc.documentNumber.isEmpty {
                            Text("•")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(doc.documentNumber)
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                if doc.hasAttachment {
                    Button(action: {
                        HapticManager.light()
                        previewDocument = doc
                    }) {
                        Image(systemName: "eye")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.blue)
                            .padding(6)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                
                if selectedDocumentId == doc.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

/// Inline compact badge to view a linked document from any card / list row.
public struct LinkedDocumentBadge: View {
    let documentId: UUID?
    @ObservedObject var store: LifeStore
    let label: String
    
    @State private var viewingDoc: DocumentRecord? = nil
    
    public init(documentId: UUID?, store: LifeStore, label: String = "Attached Document", customLabel: String? = nil) {
        self.documentId = documentId
        self.store = store
        self.label = customLabel ?? label
    }
    
    private var doc: DocumentRecord? {
        guard let id = documentId else { return nil }
        return store.documents.first { $0.id == id }
    }
    
    public var body: some View {
        if let d = doc {
            Button(action: {
                HapticManager.light()
                viewingDoc = d
            }) {
                HStack(spacing: 5) {
                    Image(systemName: d.attachmentFileType == "pdf" ? "doc.richtext.fill" : (d.hasAttachment ? "photo.fill" : "doc.text.fill"))
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                    Text(d.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.blue.opacity(0.6))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .sheet(item: $viewingDoc) { document in
                DocumentAttachmentViewerSheet(document: document)
            }
        }
    }
}
