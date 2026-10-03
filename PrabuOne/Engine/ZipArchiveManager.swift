import Foundation
import zlib

/// Native lightweight ZIP archive creation and extraction engine for Prabu One backups.
/// Packages full database JSON and physical scanned attachments/PDFs into a single .zip file.
public enum ZipArchiveManager {
    
    public struct ExtractedFile {
        public let relativePath: String
        public let data: Data
        
        public var fileName: String {
            (relativePath as NSString).lastPathComponent
        }
    }
    
    // MARK: - Native Compression / Zipping via NSFileCoordinator
    
    /// Compresses a directory into a standard .zip archive using iOS system coordinator.
    public static func createZip(from sourceDirectoryURL: URL, destinationZipURL: URL) throws -> URL {
        var coordError: NSError?
        var producedTempZipURL: URL?
        
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: sourceDirectoryURL, options: .forUploading, error: &coordError) { zipURL in
            producedTempZipURL = zipURL
            // Copy out of the coordinator block to destination
            if FileManager.default.fileExists(atPath: destinationZipURL.path) {
                try? FileManager.default.removeItem(at: destinationZipURL)
            }
            try? FileManager.default.copyItem(at: zipURL, to: destinationZipURL)
        }
        
        if let error = coordError {
            throw error
        }
        
        guard FileManager.default.fileExists(atPath: destinationZipURL.path) else {
            throw NSError(
                domain: "ZipArchiveManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to generate ZIP archive at \(destinationZipURL.lastPathComponent)"]
            )
        }
        
        return destinationZipURL
    }
    
    // MARK: - Native Unzipping via Central Directory Parser & zlib
    
    /// Extracts all files from a ZIP archive data into in-memory entries.
    public static func extractAllFiles(from zipData: Data) -> [ExtractedFile] {
        var extractedFiles: [ExtractedFile] = []
        let totalBytes = zipData.count
        guard totalBytes >= 22 else { return [] }
        
        // 1. Locate End of Central Directory Record (EOCD signature: 0x06054b50)
        var eocdOffset = -1
        let maxSearch = max(0, totalBytes - 65557)
        for i in stride(from: totalBytes - 22, through: maxSearch, by: -1) {
            if readUInt32LE(data: zipData, offset: i) == 0x06054b50 {
                eocdOffset = i
                break
            }
        }
        guard eocdOffset >= 0 else { return [] }
        
        let totalEntries = Int(readUInt16LE(data: zipData, offset: eocdOffset + 10) ?? 0)
        let cdOffset = Int(readUInt32LE(data: zipData, offset: eocdOffset + 16) ?? 0)
        
        var currentOffset = cdOffset
        
        // 2. Iterate each Central Directory Header (signature: 0x02014b50)
        for _ in 0..<totalEntries {
            guard currentOffset + 46 <= totalBytes else { break }
            guard readUInt32LE(data: zipData, offset: currentOffset) == 0x02014b50 else { break }
            
            let method = Int(readUInt16LE(data: zipData, offset: currentOffset + 10) ?? 0)
            let compSize = Int(readUInt32LE(data: zipData, offset: currentOffset + 20) ?? 0)
            let uncompSize = Int(readUInt32LE(data: zipData, offset: currentOffset + 24) ?? 0)
            let nameLen = Int(readUInt16LE(data: zipData, offset: currentOffset + 28) ?? 0)
            let extraLen = Int(readUInt16LE(data: zipData, offset: currentOffset + 30) ?? 0)
            let commentLen = Int(readUInt16LE(data: zipData, offset: currentOffset + 32) ?? 0)
            let localHeaderOffset = Int(readUInt32LE(data: zipData, offset: currentOffset + 42) ?? 0)
            
            let nameStart = currentOffset + 46
            guard nameStart + nameLen <= totalBytes else { break }
            let nameData = zipData.subdata(in: nameStart..<(nameStart + nameLen))
            let rawPath = String(data: nameData, encoding: .utf8) ?? ""
            
            // 3. Locate file data offset from Local File Header (signature: 0x04034b50)
            if localHeaderOffset + 30 <= totalBytes && readUInt32LE(data: zipData, offset: localHeaderOffset) == 0x04034b50 {
                let localNameLen = Int(readUInt16LE(data: zipData, offset: localHeaderOffset + 26) ?? 0)
                let localExtraLen = Int(readUInt16LE(data: zipData, offset: localHeaderOffset + 28) ?? 0)
                let dataStart = localHeaderOffset + 30 + localNameLen + localExtraLen
                
                if dataStart + compSize <= totalBytes {
                    let compressedSlice = zipData.subdata(in: dataStart..<(dataStart + compSize))
                    var decompressedData: Data? = nil
                    
                    if method == 0 {
                        // Stored / Uncompressed
                        decompressedData = compressedSlice
                    } else if method == 8 {
                        // Deflated
                        decompressedData = decompressDeflate(compressedData: compressedSlice, uncompressedSize: uncompSize)
                    }
                    
                    if let fileData = decompressedData, !rawPath.hasSuffix("/") {
                        // Strip root folder prefix if present (e.g. "Backup_UUID/documents/a.pdf" -> "documents/a.pdf")
                        let cleanedPath = cleanZipPath(rawPath)
                        extractedFiles.append(ExtractedFile(relativePath: cleanedPath, data: fileData))
                    }
                }
            }
            
            currentOffset += 46 + nameLen + extraLen + commentLen
        }
        
        return extractedFiles
    }
    
    // MARK: - Private Helpers
    
    private static func cleanZipPath(_ path: String) -> String {
        let parts = path.components(separatedBy: "/")
        if parts.count > 1 && parts[0].contains("-") && parts[0].count >= 30 {
            // Strip UUID folder prefix created by NSFileCoordinator
            return parts.dropFirst().joined(separator: "/")
        }
        return path
    }
    
    private static func decompressDeflate(compressedData: Data, uncompressedSize: Int) -> Data? {
        var stream = z_stream()
        let initStatus = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initStatus == Z_OK else { return nil }
        defer { inflateEnd(&stream) }
        
        var output = Data(count: max(uncompressedSize, 2048))
        let outputCount = output.count
        
        compressedData.withUnsafeBytes { inPtr in
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inPtr.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(compressedData.count)
            
            output.withUnsafeMutableBytes { outPtr in
                stream.next_out = outPtr.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(outputCount)
                _ = inflate(&stream, Z_FINISH)
            }
        }
        
        output.count = Int(stream.total_out)
        return output
    }
    
    private static func readUInt16LE(data: Data, offset: Int) -> UInt16? {
        guard offset + 2 <= data.count else { return nil }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }
    
    private static func readUInt32LE(data: Data, offset: Int) -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        return UInt32(data[offset]) |
               (UInt32(data[offset + 1]) << 8) |
               (UInt32(data[offset + 2]) << 16) |
               (UInt32(data[offset + 3]) << 24)
    }
}
