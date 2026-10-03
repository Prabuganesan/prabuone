import Foundation
import Photos
import UIKit
import ImageIO
import CoreLocation
import SwiftUI

// MARK: - Screenshot Item
public struct ScreenshotItem: Identifiable, Equatable {
    public var id: String { asset.localIdentifier }
    public let asset: PHAsset
    public let creationDate: Date
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let estimatedSizeBytes: Int64
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: estimatedSizeBytes, countStyle: .file)
    }
    
    public var resolutionString: String {
        "\(pixelWidth) × \(pixelHeight)"
    }
    
    public var relativeDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: creationDate)
    }
}

// MARK: - EXIF Metadata Record
public struct MediaExifRecord: Equatable {
    public var fileName: String = "Selected Media"
    public var fileSizeString: String = ""
    public var pixelWidth: Int = 0
    public var pixelHeight: Int = 0
    public var megapixels: String = ""
    public var fileType: String = ""
    public var colorProfile: String = "Display P3"
    
    // Camera Hardware
    public var cameraMake: String? = nil
    public var cameraModel: String? = nil
    public var lensModel: String? = nil
    public var softwareVersion: String? = nil
    
    // Shot Settings
    public var aperture: String? = nil           // e.g. "f/1.8"
    public var shutterSpeed: String? = nil      // e.g. "1/125s"
    public var iso: String? = nil               // e.g. "ISO 64"
    public var focalLength: String? = nil       // e.g. "26 mm"
    public var focalLength35mm: String? = nil   // e.g. "26 mm (35mm equiv)"
    public var exposureBias: String? = nil      // e.g. "0 EV"
    public var meteringMode: String? = nil
    public var flashFired: Bool? = nil
    public var whiteBalance: String? = nil
    
    // Timestamp
    public var captureDate: Date? = nil
    public var captureDateString: String? = nil
    
    // GPS Location
    public var latitude: Double? = nil
    public var longitude: Double? = nil
    public var altitudeMeters: Double? = nil
    public var locationName: String? = nil
    
    public var hasGPS: Bool {
        latitude != nil && longitude != nil
    }
    
    public var coordinatesString: String? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return String(format: "%.5f°, %.5f°", lat, lon)
    }
}

// MARK: - Photo Tools Manager
@MainActor
public final class PhotoToolsManager: ObservableObject {
    public static let shared = PhotoToolsManager()
    
    @Published public var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published public var isScanningScreenshots: Bool = false
    @Published public var screenshots: [ScreenshotItem] = []
    @Published public var selectedScreenshotIds: Set<String> = []
    @Published public var isDeleting: Bool = false
    @Published public var statusMessage: String? = nil
    
    private let imageManager = PHCachingImageManager.default()
    
    private init() {
        self.authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                self.authorizationStatus = status
                completion(status == .authorized || status == .limited)
            }
        }
    }
    
    // MARK: - Screenshot Scanner & Cleanup
    
    public func scanScreenshots() {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            requestAuthorization { granted in
                if granted {
                    self.scanScreenshots()
                }
            }
            return
        }
        
        self.isScanningScreenshots = true
        self.selectedScreenshotIds.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async {
            var items: [ScreenshotItem] = []
            
            // Fetch screenshots from Smart Album or mediaSubtypes
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumScreenshots, options: nil)
            if let screenshotsAlbum = smartAlbums.firstObject {
                let assets = PHAsset.fetchAssets(in: screenshotsAlbum, options: fetchOptions)
                assets.enumerateObjects { asset, _, _ in
                    let item = self.makeScreenshotItem(from: asset)
                    items.append(item)
                }
            } else {
                // Fallback: fetch images where subtype has screenshot
                let allAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                allAssets.enumerateObjects { asset, _, _ in
                    if asset.mediaSubtypes.contains(.photoScreenshot) {
                        let item = self.makeScreenshotItem(from: asset)
                        items.append(item)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.screenshots = items
                self.isScanningScreenshots = false
            }
        }
    }
    
    private nonisolated func makeScreenshotItem(from asset: PHAsset) -> ScreenshotItem {
        let width = asset.pixelWidth
        let height = asset.pixelHeight
        let date = asset.creationDate ?? Date()
        
        // Approximate screenshot uncompressed/compressed footprint ~1.8 bytes per pixel or file resource size
        let estimatedBytes: Int64
        let resources = PHAssetResource.assetResources(for: asset)
        if let fileSize = resources.first?.value(forKey: "fileSize") as? Int64, fileSize > 0 {
            estimatedBytes = fileSize
        } else {
            estimatedBytes = Int64(Double(width * height) * 0.75)
        }
        
        return ScreenshotItem(
            asset: asset,
            creationDate: date,
            pixelWidth: width,
            pixelHeight: height,
            estimatedSizeBytes: max(estimatedBytes, 500_000)
        )
    }
    
    public var totalScreenshotsSize: Int64 {
        screenshots.reduce(0) { $0 + $1.estimatedSizeBytes }
    }
    
    public var selectedScreenshotsSize: Int64 {
        screenshots.filter { selectedScreenshotIds.contains($0.id) }
            .reduce(0) { $0 + $1.estimatedSizeBytes }
    }
    
    public func selectAllScreenshots() {
        self.selectedScreenshotIds = Set(screenshots.map { $0.id })
    }
    
    public func deselectAllScreenshots() {
        self.selectedScreenshotIds.removeAll()
    }
    
    public func deleteSelectedScreenshots(completion: @escaping (Int, Error?) -> Void) {
        let toDelete = screenshots.filter { selectedScreenshotIds.contains($0.id) }.map { $0.asset }
        guard !toDelete.isEmpty else {
            completion(0, nil)
            return
        }
        
        self.isDeleting = true
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(toDelete as NSArray)
        }) { success, error in
            DispatchQueue.main.async {
                self.isDeleting = false
                if success {
                    let count = toDelete.count
                    self.screenshots.removeAll { self.selectedScreenshotIds.contains($0.id) }
                    self.selectedScreenshotIds.removeAll()
                    HapticManager.success()
                    completion(count, nil)
                } else {
                    completion(0, error)
                }
            }
        }
    }
    
    public func requestThumbnail(for asset: PHAsset, size: CGSize = CGSize(width: 200, height: 200), completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        
        imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { img, _ in
            completion(img)
        }
    }
    
    // MARK: - EXIF Metadata Extraction
    
    public nonisolated func extractExif(from data: Data, fileName: String? = nil) -> MediaExifRecord {
        var record = MediaExifRecord()
        if let fn = fileName { record.fileName = fn }
        record.fileSizeString = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return record
        }
        
        if let typeCF = CGImageSourceGetType(source) {
            record.fileType = String(typeCF as String).components(separatedBy: ".").last?.uppercased() ?? "IMAGE"
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return record
        }
        
        // Dimensions & Megapixels
        let width = (properties[kCGImagePropertyPixelWidth as String] as? Int) ?? 0
        let height = (properties[kCGImagePropertyPixelHeight as String] as? Int) ?? 0
        record.pixelWidth = width
        record.pixelHeight = height
        if width > 0 && height > 0 {
            let mp = Double(width * height) / 1_000_000.0
            record.megapixels = String(format: "%.1f MP", mp)
        }
        
        // Color Profile
        if let colorModel = properties[kCGImagePropertyColorModel as String] as? String {
            record.colorProfile = colorModel
        }
        
        // TIFF Dictionary (Make, Model, Software, Date)
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            record.cameraMake = tiff[kCGImagePropertyTIFFMake as String] as? String
            record.cameraModel = tiff[kCGImagePropertyTIFFModel as String] as? String
            record.softwareVersion = tiff[kCGImagePropertyTIFFSoftware as String] as? String
            
            if let dateStr = tiff[kCGImagePropertyTIFFDateTime as String] as? String {
                record.captureDateString = dateStr
            }
        }
        
        // EXIF Dictionary (Aperture, Shutter, ISO, Lens, Focal Length)
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let fNumber = exif[kCGImagePropertyExifFNumber as String] as? Double {
                record.aperture = String(format: "f/%.1f", fNumber)
            }
            if let expTime = exif[kCGImagePropertyExifExposureTime as String] as? Double {
                if expTime < 1.0 && expTime > 0 {
                    record.shutterSpeed = String(format: "1/%d s", Int(round(1.0 / expTime)))
                } else {
                    record.shutterSpeed = String(format: "%.1f s", expTime)
                }
            }
            if let isoArr = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int], let firstIso = isoArr.first {
                record.iso = "ISO \(firstIso)"
            }
            if let fl = exif[kCGImagePropertyExifFocalLength as String] as? Double {
                record.focalLength = String(format: "%.1f mm", fl)
            }
            if let fl35 = exif[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? Int {
                record.focalLength35mm = "\(fl35) mm (35mm equiv)"
            }
            if let ev = exif[kCGImagePropertyExifExposureBiasValue as String] as? Double {
                record.exposureBias = String(format: "%+.1f EV", ev)
            }
            if let lens = exif[kCGImagePropertyExifLensModel as String] as? String {
                record.lensModel = lens
            }
            if let flash = exif[kCGImagePropertyExifFlash as String] as? Int {
                record.flashFired = (flash & 1) != 0
            }
            if let wb = exif[kCGImagePropertyExifWhiteBalance as String] as? Int {
                record.whiteBalance = (wb == 0) ? "Auto" : "Manual"
            }
        }
        
        // GPS Dictionary
        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            if let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
               let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String {
                record.latitude = (latRef == "S") ? -lat : lat
            }
            if let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double,
               let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String {
                record.longitude = (lonRef == "W") ? -lon : lon
            }
            if let alt = gps[kCGImagePropertyGPSAltitude as String] as? Double {
                record.altitudeMeters = alt
            }
        }
        
        return record
    }
    
    /// Strips all EXIF, TIFF, and GPS metadata from an image Data for privacy-preserving export.
    public nonisolated func stripExifMetadata(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let uti = CGImageSourceGetType(source) else {
            return nil
        }
        
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData as CFMutableData, uti, 1, nil) else {
            return nil
        }
        
        // Clean metadata dictionary
        let emptyProperties: [String: Any] = [:]
        CGImageDestinationAddImageFromSource(destination, source, 0, emptyProperties as CFDictionary)
        
        if CGImageDestinationFinalize(destination) {
            return mutableData as Data
        }
        return nil
    }
}
