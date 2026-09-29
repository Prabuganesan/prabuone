import SwiftUI
import PhotosUI
import PDFKit
import UniformTypeIdentifiers

/// Secure Digital Vault for critical vehicle, personal, and property documents.
public struct DocumentVaultView: View {
    @ObservedObject var store: LifeStore
    @State private var showingAddDocument = false
    @State private var selectedDocToEdit: DocumentRecord? = nil
    @State private var selectedDocToView: DocumentRecord? = nil
    @State private var copiedToastText: String? = nil
    
    public init(store: LifeStore) {
        self.store = store
    }
    
    public var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.documents.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 46))
                                .foregroundColor(.teal)
                                .padding(.top, 40)
                            
                            Text("No Documents in Vault")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Text("Store vehicle RC, DL, Passport, Insurance, and PUC certificates with original uploaded scans/PDFs.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            Button(action: {
                                HapticManager.light()
                                showingAddDocument = true
                            }) {
                                Label("Add First Document", systemImage: "plus")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.teal)
                                    .cornerRadius(12)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 20)
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
                            }, onEdit: {
                                selectedDocToEdit = doc
                            }, onViewAttachment: {
                                selectedDocToView = doc
                            })
                            .contextMenu {
                                if doc.hasAttachment {
                                    Button {
                                        selectedDocToView = doc
                                    } label: {
                                        Label("View Attached File", systemImage: doc.attachmentFileType == "pdf" ? "doc.richtext" : "photo")
                                    }
                                }
                                
                                Button {
                                    selectedDocToEdit = doc
                                } label: {
                                    Label("Edit Document", systemImage: "pencil")
                                }
                                
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
        .sheet(item: $selectedDocToEdit) { doc in
            EditDocumentSheet(store: store, document: doc)
        }
        .sheet(item: $selectedDocToView) { doc in
            DocumentAttachmentViewerSheet(document: doc)
        }
    }
}

/// Visual card for stored document.
struct DocumentCard: View {
    let document: DocumentRecord
    let onCopy: () -> Void
    var onEdit: (() -> Void)? = nil
    var onViewAttachment: (() -> Void)? = nil
    
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
        VStack(alignment: .leading, spacing: 12) {
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
                
                if let onEdit = onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
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
            
            // Attachment Preview Strip
            if document.hasAttachment {
                Button(action: { onViewAttachment?() }) {
                    HStack(spacing: 8) {
                        Image(systemName: document.attachmentFileType == "pdf" ? "doc.richtext.fill" : "photo.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.teal)
                        
                        Text(document.attachmentOriginalName ?? "View Attached Document")
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text("View")
                                .font(.system(size: 11, weight: .bold))
                            Image(systemName: "arrow.up.right.square.fill")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.teal)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.teal.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
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
    
    // Attachment State
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showingFileImporter = false
    @State private var pendingAttachmentData: Data? = nil
    @State private var pendingAttachmentFileName: String? = nil
    @State private var pendingAttachmentFileType: String? = nil
    @State private var pendingAttachmentOriginalName: String? = nil
    
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
                
                Section("Document Upload (Photo or PDF)") {
                    if let data = pendingAttachmentData {
                        HStack(spacing: 12) {
                            if pendingAttachmentFileType == "image", let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.teal.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: pendingAttachmentFileType == "pdf" ? "doc.richtext.fill" : "photo.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.teal)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pendingAttachmentOriginalName ?? "Uploaded Document")
                                    .font(.system(size: 14, weight: .semibold))
                                    .lineLimit(1)
                                Text(formatBytes(data.count))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(role: .destructive) {
                                pendingAttachmentData = nil
                                pendingAttachmentOriginalName = nil
                                pendingAttachmentFileType = nil
                                selectedPhotoItem = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 10) {
                            HStack(spacing: 12) {
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    HStack {
                                        Image(systemName: "photo.badge.plus")
                                        Text("Upload Photo")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.teal.opacity(0.12))
                                    .foregroundColor(.teal)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { showingFileImporter = true }) {
                                    HStack {
                                        Image(systemName: "doc.badge.plus")
                                        Text("Upload PDF")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.teal.opacity(0.12))
                                    .foregroundColor(.teal)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Text("Attach vehicle RC, DL scans, or insurance policy PDFs securely.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Add Document")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedPhotoItem) { newItem in
                guard let newItem = newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            self.pendingAttachmentData = data
                            self.pendingAttachmentFileType = "image"
                            self.pendingAttachmentOriginalName = "Photo_\(Int(Date().timeIntervalSince1970)).jpg"
                            HapticManager.selection()
                        }
                    }
                }
            }
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.pdf, .image, .data]) { result in
                switch result {
                case .success(let url):
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) {
                        self.pendingAttachmentData = data
                        let ext = url.pathExtension.lowercased()
                        self.pendingAttachmentFileType = (ext == "pdf") ? "pdf" : "image"
                        self.pendingAttachmentOriginalName = url.lastPathComponent
                        HapticManager.selection()
                    }
                case .failure(let error):
                    print("Document import failed: \(error)")
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNewDocument()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || documentNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveNewDocument() {
        var savedFileName: String? = nil
        var savedFileType: String? = nil
        var savedOriginalName: String? = nil
        
        if let data = pendingAttachmentData {
            let ext = (pendingAttachmentOriginalName as NSString?)?.pathExtension ?? (pendingAttachmentFileType == "pdf" ? "pdf" : "jpg")
            if let saved = store.saveAttachmentData(data, fileExtension: ext, originalName: pendingAttachmentOriginalName) {
                savedFileName = saved.fileName
                savedFileType = saved.fileType
                savedOriginalName = pendingAttachmentOriginalName
            }
        }
        
        let doc = DocumentRecord(
            title: title.trimmingCharacters(in: .whitespaces),
            documentType: documentType,
            documentNumber: documentNumber.trimmingCharacters(in: .whitespaces),
            expiryDate: hasExpiry ? expiryDate : nil,
            attachmentFileName: savedFileName,
            attachmentFileType: savedFileType,
            attachmentOriginalName: savedOriginalName
        )
        store.addDocument(doc)
        dismiss()
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useMB, .useKB]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: Int64(bytes))
    }
}

/// Sheet for editing an existing document in the vault.
struct EditDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    let document: DocumentRecord
    
    @State private var title = ""
    @State private var documentType = "RC Book"
    @State private var documentNumber = ""
    @State private var hasExpiry = true
    @State private var expiryDate = Date().addingTimeInterval(86400 * 365)
    
    // Attachment State
    @State private var existingAttachmentFileName: String? = nil
    @State private var existingAttachmentFileType: String? = nil
    @State private var existingAttachmentOriginalName: String? = nil
    @State private var wasAttachmentRemoved = false
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showingFileImporter = false
    @State private var pendingAttachmentData: Data? = nil
    @State private var pendingAttachmentFileType: String? = nil
    @State private var pendingAttachmentOriginalName: String? = nil
    
    let types = ["RC Book", "Driving License", "Passport", "Aadhaar Card", "PAN Card", "Insurance Policy", "PUC Certificate", "Agreement"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Document Information") {
                    TextField("Document Name", text: $title)
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
                
                Section("Document Upload (Photo or PDF)") {
                    if let data = pendingAttachmentData {
                        HStack(spacing: 12) {
                            if pendingAttachmentFileType == "image", let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.teal.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: pendingAttachmentFileType == "pdf" ? "doc.richtext.fill" : "photo.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.teal)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pendingAttachmentOriginalName ?? "New Upload")
                                    .font(.system(size: 14, weight: .semibold))
                                    .lineLimit(1)
                                Text("Replaces existing attachment")
                                    .font(.system(size: 11))
                                    .foregroundColor(.teal)
                            }
                            
                            Spacer()
                            
                            Button(role: .destructive) {
                                pendingAttachmentData = nil
                                pendingAttachmentOriginalName = nil
                                pendingAttachmentFileType = nil
                                selectedPhotoItem = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    } else if let originalName = existingAttachmentOriginalName, !wasAttachmentRemoved {
                        HStack(spacing: 12) {
                            if existingAttachmentFileType == "image",
                               let url = document.attachmentURL,
                               let uiImage = UIImage(contentsOfFile: url.path) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.teal.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: existingAttachmentFileType == "pdf" ? "doc.richtext.fill" : "photo.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.teal)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(originalName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .lineLimit(1)
                                Text("Attached File")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(role: .destructive) {
                                wasAttachmentRemoved = true
                                HapticManager.light()
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 10) {
                            HStack(spacing: 12) {
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    HStack {
                                        Image(systemName: "photo.badge.plus")
                                        Text("Upload Photo")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.teal.opacity(0.12))
                                    .foregroundColor(.teal)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { showingFileImporter = true }) {
                                    HStack {
                                        Image(systemName: "doc.badge.plus")
                                        Text("Upload PDF")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.teal.opacity(0.12))
                                    .foregroundColor(.teal)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Text("Upload a new photo or PDF document to this record.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Edit Document")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                title = document.title
                documentType = document.documentType
                documentNumber = document.documentNumber
                hasExpiry = document.expiryDate != nil
                if let exp = document.expiryDate {
                    expiryDate = exp
                }
                existingAttachmentFileName = document.attachmentFileName
                existingAttachmentFileType = document.attachmentFileType
                existingAttachmentOriginalName = document.attachmentOriginalName
            }
            .onChange(of: selectedPhotoItem) { newItem in
                guard let newItem = newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            self.pendingAttachmentData = data
                            self.pendingAttachmentFileType = "image"
                            self.pendingAttachmentOriginalName = "Photo_\(Int(Date().timeIntervalSince1970)).jpg"
                            HapticManager.selection()
                        }
                    }
                }
            }
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.pdf, .image, .data]) { result in
                switch result {
                case .success(let url):
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) {
                        self.pendingAttachmentData = data
                        let ext = url.pathExtension.lowercased()
                        self.pendingAttachmentFileType = (ext == "pdf") ? "pdf" : "image"
                        self.pendingAttachmentOriginalName = url.lastPathComponent
                        HapticManager.selection()
                    }
                case .failure(let error):
                    print("Document import failed: \(error)")
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveUpdatedDocument()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || documentNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveUpdatedDocument() {
        var finalFileName = existingAttachmentFileName
        var finalFileType = existingAttachmentFileType
        var finalOriginalName = existingAttachmentOriginalName
        
        if let data = pendingAttachmentData {
            let ext = (pendingAttachmentOriginalName as NSString?)?.pathExtension ?? (pendingAttachmentFileType == "pdf" ? "pdf" : "jpg")
            if let saved = store.saveAttachmentData(data, fileExtension: ext, originalName: pendingAttachmentOriginalName) {
                finalFileName = saved.fileName
                finalFileType = saved.fileType
                finalOriginalName = pendingAttachmentOriginalName
            }
        } else if wasAttachmentRemoved {
            finalFileName = nil
            finalFileType = nil
            finalOriginalName = nil
        }
        
        var updated = document
        updated.title = title.trimmingCharacters(in: .whitespaces)
        updated.documentType = documentType
        updated.documentNumber = documentNumber.trimmingCharacters(in: .whitespaces)
        updated.expiryDate = hasExpiry ? expiryDate : nil
        updated.attachmentFileName = finalFileName
        updated.attachmentFileType = finalFileType
        updated.attachmentOriginalName = finalOriginalName
        
        store.updateDocument(updated)
        dismiss()
    }
}

/// In-App Fullscreen Attachment Viewer for Photos & PDFs with Screen-Fitting & Interactive Zoom.
struct DocumentAttachmentViewerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let document: DocumentRecord
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.black)
                    .ignoresSafeArea()
                
                if let url = document.attachmentURL, FileManager.default.fileExists(atPath: url.path) {
                    if document.attachmentFileType == "pdf" {
                        PDFKitRepresentable(url: url)
                            .ignoresSafeArea(edges: .bottom)
                    } else if let uiImage = UIImage(contentsOfFile: url.path) {
                        ZoomableImageView(image: uiImage)
                            .ignoresSafeArea(edges: .bottom)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 54))
                                .foregroundColor(.teal)
                            Text(document.attachmentOriginalName ?? "Document File")
                                .font(.headline)
                                .foregroundColor(.white)
                            ShareLink(item: url) {
                                Label("Share / Export File", systemImage: "square.and.arrow.up")
                                    .font(.headline)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.teal)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.orange)
                        Text("Document File Not Found")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("The attached scan or PDF is not available in local storage.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                }
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
                
                if let url = document.attachmentURL, FileManager.default.fileExists(atPath: url.path) {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
    }
}

/// Interactive image viewer that fits the image to the screen on launch and supports pinch-to-zoom and double-tap.
struct ZoomableImageView: View {
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                let newScale = scale * delta
                                scale = min(max(newScale, 1.0), 5.0)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale <= 1.0 {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                if scale > 1.0 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                if scale > 1.0 {
                                    lastOffset = offset
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if scale > 1.05 {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.5
                            }
                        }
                    }
                
                // Bottom control overlay
                VStack {
                    Spacer()
                    if scale > 1.05 {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                Text("Fit to Screen")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.25))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                        }
                        .padding(.bottom, 24)
                    } else {
                        Text("Double-tap or pinch to zoom")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(12)
                            .padding(.bottom, 24)
                    }
                }
            }
        }
    }
}

/// Native PDF Viewer with automatic screen-fit layout.
struct PDFKitRepresentable: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = UIColor.black
        
        if let doc = PDFDocument(url: url) {
            pdfView.document = doc
        }
        
        // Auto scale to fit page width to screen
        pdfView.autoScales = true
        DispatchQueue.main.async {
            pdfView.autoScales = true
            if pdfView.scaleFactorForSizeToFit > 0 {
                pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit * 0.5
                pdfView.maxScaleFactor = 5.0
                pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
            }
        }
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document == nil || uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
            DispatchQueue.main.async {
                uiView.autoScales = true
                if uiView.scaleFactorForSizeToFit > 0 {
                    uiView.minScaleFactor = uiView.scaleFactorForSizeToFit * 0.5
                    uiView.maxScaleFactor = 5.0
                    uiView.scaleFactor = uiView.scaleFactorForSizeToFit
                }
            }
        }
    }
}
