import Foundation

/// Secure Document Record for Document Vault.
public struct DocumentRecord: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var documentType: String // e.g. RC Book, Driving License, Passport, Aadhaar, Insurance Policy
    public var documentNumber: String
    public var expiryDate: Date?
    public var isExpiringSoon: Bool {
        guard let expiry = expiryDate else { return false }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
        return days <= 30 && days >= 0
    }
    public var isExpired: Bool {
        guard let expiry = expiryDate else { return false }
        return expiry < Date()
    }
    public var notes: String?
    public var attachmentFileName: String?
    public var attachmentFileType: String? // "image" or "pdf" or "file"
    public var attachmentOriginalName: String?
    
    public var hasAttachment: Bool {
        attachmentFileName != nil
    }
    
    public var attachmentURL: URL? {
        guard let name = attachmentFileName else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("vault_attachments", isDirectory: true)
        return dir.appendingPathComponent(name)
    }
    
    public init(
        id: UUID = UUID(),
        title: String,
        documentType: String,
        documentNumber: String,
        expiryDate: Date? = nil,
        notes: String? = nil,
        attachmentFileName: String? = nil,
        attachmentFileType: String? = nil,
        attachmentOriginalName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.documentType = documentType
        self.documentNumber = documentNumber
        self.expiryDate = expiryDate
        self.notes = notes
        self.attachmentFileName = attachmentFileName
        self.attachmentFileType = attachmentFileType
        self.attachmentOriginalName = attachmentOriginalName
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, title, documentType, documentNumber, expiryDate, notes
        case attachmentFileName, attachmentFileType, attachmentOriginalName
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        documentType = try container.decode(String.self, forKey: .documentType)
        documentNumber = try container.decode(String.self, forKey: .documentNumber)
        expiryDate = try container.decodeIfPresent(Date.self, forKey: .expiryDate)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        attachmentFileName = try container.decodeIfPresent(String.self, forKey: .attachmentFileName)
        attachmentFileType = try container.decodeIfPresent(String.self, forKey: .attachmentFileType)
        attachmentOriginalName = try container.decodeIfPresent(String.self, forKey: .attachmentOriginalName)
    }
}
