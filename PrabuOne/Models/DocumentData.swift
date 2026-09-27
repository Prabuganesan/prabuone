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
    
    public init(
        id: UUID = UUID(),
        title: String,
        documentType: String,
        documentNumber: String,
        expiryDate: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.documentType = documentType
        self.documentNumber = documentNumber
        self.expiryDate = expiryDate
        self.notes = notes
    }
}
