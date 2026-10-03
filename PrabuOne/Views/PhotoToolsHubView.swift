import SwiftUI
import PhotosUI
import MapKit

public enum PhotoToolTab: String, CaseIterable, Identifiable {
    case screenshotCleaner = "Screenshots"
    case exifViewer = "EXIF Inspector"
    case collageStudio = "Collage Studio"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .screenshotCleaner: return "trash.circle.fill"
        case .exifViewer: return "info.circle.fill"
        case .collageStudio: return "square.grid.2x2.fill"
        }
    }
}

/// Unified Media Studio: Screenshot Cleaner, Deep EXIF Metadata Inspector, and Photo Collage Studio.
public struct PhotoToolsHubView: View {
    @StateObject private var manager = PhotoToolsManager.shared
    @State private var selectedTab: PhotoToolTab = .screenshotCleaner
    
    public init(initialTab: PhotoToolTab = .screenshotCleaner) {
        _selectedTab = State(initialValue: initialTab)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Elegant Segmented Switcher
            Picker("Media Studio Mode", selection: $selectedTab) {
                ForEach(PhotoToolTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.iconName).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            TabView(selection: $selectedTab) {
                ScreenshotCleanerSection(manager: manager)
                    .tag(PhotoToolTab.screenshotCleaner)
                
                ExifInspectorSection(manager: manager)
                    .tag(PhotoToolTab.exifViewer)
                
                PhotoCollageStudioSection()
                    .tag(PhotoToolTab.collageStudio)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("Media Studio")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 1. Screenshot Cleaner Section
struct ScreenshotCleanerSection: View {
    @ObservedObject var manager: PhotoToolsManager
    @State private var showingDeleteConfirmation = false
    @State private var previewAsset: ScreenshotItem? = nil
    @State private var toastMessage: String? = nil
    
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Hero Reclaim Storage Card
                    VStack(spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 7, height: 7)
                                    Text("SCREENSHOT STORAGE USAGE")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white.opacity(0.75))
                                }
                                
                                Text(ByteCountFormatter.string(fromByteCount: manager.totalScreenshotsSize, countStyle: .file))
                                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                HapticManager.light()
                                manager.scanScreenshots()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("Scan")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.18))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.2))
                        
                        HStack {
                            Text("\(manager.screenshots.count) Screenshots Found")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            if !manager.selectedScreenshotIds.isEmpty {
                                Text("\(manager.selectedScreenshotIds.count) selected (\(ByteCountFormatter.string(fromByteCount: manager.selectedScreenshotsSize, countStyle: .file)))")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.16, green: 0.10, blue: 0.08), Color(red: 0.08, green: 0.05, blue: 0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
                    
                    // Selection Actions Row
                    if !manager.screenshots.isEmpty {
                        HStack(spacing: 10) {
                            Button(action: {
                                HapticManager.selection()
                                if manager.selectedScreenshotIds.count == manager.screenshots.count {
                                    manager.deselectAllScreenshots()
                                } else {
                                    manager.selectAllScreenshots()
                                }
                            }) {
                                Text(manager.selectedScreenshotIds.count == manager.screenshots.count ? "Deselect All" : "Select All (\(manager.screenshots.count))")
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .foregroundColor(.primary)
                                    .cornerRadius(10)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showingDeleteConfirmation = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash.fill")
                                    Text("Delete (\(manager.selectedScreenshotIds.count))")
                                }
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(manager.selectedScreenshotIds.isEmpty ? Color.gray.opacity(0.3) : Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(manager.selectedScreenshotIds.isEmpty)
                        }
                    }
                    
                    // Screenshot Grid
                    if manager.isScanningScreenshots {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Scanning photo library for screenshots...")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else if manager.screenshots.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 42))
                                .foregroundColor(.green)
                            Text("No Screenshots Found")
                                .font(.system(size: 16, weight: .bold))
                            Text("Your camera roll is clean of clutter screenshots.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            Button(action: { manager.scanScreenshots() }) {
                                Text("Scan Photo Library")
                                    .font(.system(size: 13, weight: .bold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(manager.screenshots) { item in
                                let isSelected = manager.selectedScreenshotIds.contains(item.id)
                                ScreenshotThumbnailCell(item: item, isSelected: isSelected, onToggleSelect: {
                                    HapticManager.selection()
                                    if isSelected {
                                        manager.selectedScreenshotIds.remove(item.id)
                                    } else {
                                        manager.selectedScreenshotIds.insert(item.id)
                                    }
                                }, onPreview: {
                                    previewAsset = item
                                })
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            
            // Toast overlay
            if let toast = toastMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(toast)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.85))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(radius: 6)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            if manager.screenshots.isEmpty {
                manager.scanScreenshots()
            }
        }
        .alert("Confirm Deletion", isPresented: $showingDeleteConfirmation) {
            Button("Delete \(manager.selectedScreenshotIds.count) Screenshots", role: .destructive) {
                manager.deleteSelectedScreenshots { count, error in
                    if let err = error {
                        showToast("Failed to delete: \(err.localizedDescription)")
                    } else {
                        showToast("Successfully deleted \(count) screenshots!")
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will move \(manager.selectedScreenshotIds.count) screenshots (\(ByteCountFormatter.string(fromByteCount: manager.selectedScreenshotsSize, countStyle: .file))) to your Recently Deleted album.")
        }
        .sheet(item: $previewAsset) { item in
            ScreenshotPreviewModal(item: item)
        }
    }
    
    private func showToast(_ msg: String) {
        withAnimation { toastMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { toastMessage = nil }
        }
    }
}

struct ScreenshotThumbnailCell: View {
    let item: ScreenshotItem
    let isSelected: Bool
    let onToggleSelect: () -> Void
    let onPreview: () -> Void
    
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onPreview) {
                ZStack(alignment: .bottomLeading) {
                    if let img = thumbnail {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 120, maxHeight: 120)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(UIColor.secondarySystemBackground))
                            .frame(height: 120)
                            .overlay(ProgressView())
                    }
                    
                    // Size Badge
                    Text(item.formattedSize)
                        .font(.system(size: 9.5, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.75))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .padding(5)
                }
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.15), lineWidth: isSelected ? 3 : 1)
                )
            }
            .buttonStyle(.plain)
            
            // Checkmark button
            Button(action: onToggleSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .blue : .white)
                    .background(Circle().fill(Color.black.opacity(0.4)).frame(width: 18, height: 18))
                    .padding(6)
            }
        }
        .onAppear {
            PhotoToolsManager.shared.requestThumbnail(for: item.asset) { img in
                self.thumbnail = img
            }
        }
    }
}

struct ScreenshotPreviewModal: View {
    @Environment(\.dismiss) private var dismiss
    let item: ScreenshotItem
    @State private var fullImage: UIImage? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                if let img = fullImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                HStack(spacing: 16) {
                    Label(item.resolutionString, systemImage: "aspectratio")
                    Label(item.formattedSize, systemImage: "internaldrive")
                    Label(item.relativeDateString, systemImage: "calendar")
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.secondary)
                .padding()
            }
            .navigationTitle("Screenshot Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                PhotoToolsManager.shared.requestThumbnail(for: item.asset, size: CGSize(width: 1200, height: 1200)) { img in
                    self.fullImage = img
                }
            }
        }
    }
}

// MARK: - 2. EXIF Inspector Section
struct ExifInspectorSection: View {
    @ObservedObject var manager: PhotoToolsManager
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var exifRecord: MediaExifRecord? = nil
    @State private var rawImageData: Data? = nil
    @State private var previewImage: UIImage? = nil
    @State private var isAnalyzing: Bool = false
    @State private var showingShareCleanSheet: Bool = false
    @State private var cleanImageURL: URL? = nil
    @State private var toastMessage: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Media Picker Hero Button
                PhotosPicker(selection: $selectedPhotoItem, matching: .any(of: [.images, .videos])) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.18))
                                .frame(width: 44, height: 44)
                            Image(systemName: "photo.badge.magnifyingglass")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(exifRecord == nil ? "Select Photo or Video to Inspect" : "Choose Another Media File")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Extracts camera model, aperture, shutter, lens, ISO, and GPS location")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onChange(of: selectedPhotoItem) { newItem in
                    guard let item = newItem else { return }
                    analyzeMediaItem(item)
                }
                
                if isAnalyzing {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Reading full EXIF & metadata tags...")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 30)
                } else if let record = exifRecord {
                    // Preview Thumbnail & Stripped Export Button
                    if let img = previewImage {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.fileName)
                                        .font(.system(size: 15, weight: .bold))
                                        .lineLimit(1)
                                    
                                    HStack(spacing: 6) {
                                        Text(record.fileType)
                                            .font(.system(size: 9.5, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundColor(.blue)
                                            .cornerRadius(4)
                                        
                                        Text(record.megapixels)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.secondary)
                                        
                                        Text("•")
                                            .foregroundColor(.secondary)
                                        
                                        Text(record.fileSizeString)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if let dateStr = record.captureDateString {
                                        Text(dateStr)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            
                            // Privacy Tool: Strip Metadata
                            Button(action: {
                                stripAndShareMetadata()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "shield.slash.fill")
                                        .font(.system(size: 12))
                                    Text("Strip EXIF & Location for Private Sharing")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(Color.green.opacity(0.14))
                                .foregroundColor(.green)
                                .cornerRadius(10)
                            }
                        }
                        .padding(14)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(16)
                    }
                    
                    // 1. Camera & Optics Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.blue)
                            Text("Camera & Optics")
                                .font(.system(size: 14, weight: .bold))
                        }
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            exifTile(title: "Camera Make", value: record.cameraMake ?? "Unknown")
                            exifTile(title: "Camera Model", value: record.cameraModel ?? "Generic / Screenshot")
                            exifTile(title: "Lens Model", value: record.lensModel ?? "Standard Optics")
                            exifTile(title: "Software", value: record.softwareVersion ?? "iOS System")
                        }
                    }
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // 2. Exposure & Sensor Settings Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "camera.aperture")
                                .foregroundColor(.orange)
                            Text("Exposure & Sensor Settings")
                                .font(.system(size: 14, weight: .bold))
                        }
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            exifTile(title: "Aperture", value: record.aperture ?? "N/A", highlight: record.aperture != nil)
                            exifTile(title: "Shutter", value: record.shutterSpeed ?? "N/A", highlight: record.shutterSpeed != nil)
                            exifTile(title: "ISO", value: record.iso ?? "N/A", highlight: record.iso != nil)
                            exifTile(title: "Focal Length", value: record.focalLength ?? "N/A")
                            exifTile(title: "35mm Equivalent", value: record.focalLength35mm ?? "N/A")
                            exifTile(title: "Exposure Bias", value: record.exposureBias ?? "0 EV")
                            exifTile(title: "White Balance", value: record.whiteBalance ?? "Auto")
                            exifTile(title: "Flash", value: record.flashFired == true ? "Fired" : "Off")
                            exifTile(title: "Color Space", value: record.colorProfile)
                        }
                    }
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // 3. Dimensions & Resolution
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "aspectratio.fill")
                                .foregroundColor(.purple)
                            Text("File Resolution & Color")
                                .font(.system(size: 14, weight: .bold))
                        }
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            exifTile(title: "Dimensions", value: "\(record.pixelWidth) × \(record.pixelHeight) px")
                            exifTile(title: "Megapixels", value: record.megapixels.isEmpty ? "N/A" : record.megapixels)
                            exifTile(title: "File Format", value: record.fileType)
                            exifTile(title: "File Size", value: record.fileSizeString)
                        }
                    }
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // 4. GPS & Location Map Pin
                    if let coords = record.coordinatesString, let lat = record.latitude, let lon = record.longitude {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.red)
                                Text("GPS Geotag Location")
                                    .font(.system(size: 14, weight: .bold))
                                Spacer()
                                Text(coords)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            
                            // Map Preview
                            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                            Map(coordinateRegion: .constant(MKCoordinateRegion(
                                center: coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )), annotationItems: [MapLocationItem(coordinate: coordinate)]) { item in
                                MapMarker(coordinate: item.coordinate, tint: .red)
                            }
                            .frame(height: 180)
                            .cornerRadius(12)
                            
                            if let alt = record.altitudeMeters {
                                Text("Altitude: \(Int(alt)) meters above sea level")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(14)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(16)
                    }
                } else {
                    // Empty Placeholder with Feature Highlights
                    VStack(spacing: 16) {
                        Image(systemName: "camera.metering.spot")
                            .font(.system(size: 48))
                            .foregroundColor(.blue.opacity(0.6))
                            .padding(.top, 20)
                        
                        Text("No Photo Loaded")
                            .font(.system(size: 16, weight: .bold))
                        
                        Text("Tap 'Select Photo or Video' above to inspect full shutter speed, aperture, camera sensor, lens optics, and GPS coordinates.")
                            .font(.system(size: 12.5))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $showingShareCleanSheet) {
            if let url = cleanImageURL {
                ShareSheetView(activityItems: [url])
            }
        }
    }
    
    private func exifTile(title: String, value: String, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12.5, weight: highlight ? .bold : .semibold, design: highlight ? .rounded : .default))
                .foregroundColor(highlight ? .blue : .primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func analyzeMediaItem(_ item: PhotosPickerItem) {
        isAnalyzing = true
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                self.isAnalyzing = false
                switch result {
                case .success(let data):
                    guard let data = data else { return }
                    self.rawImageData = data
                    self.previewImage = UIImage(data: data)
                    self.exifRecord = PhotoToolsManager.shared.extractExif(from: data, fileName: "Selected Media")
                    HapticManager.success()
                case .failure(let error):
                    showToast("Failed to read image: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func stripAndShareMetadata() {
        guard let data = rawImageData else { return }
        HapticManager.light()
        if let cleanData = PhotoToolsManager.shared.stripExifMetadata(from: data) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Clean_\(UUID().uuidString).jpg")
            try? cleanData.write(to: tempURL)
            self.cleanImageURL = tempURL
            self.showingShareCleanSheet = true
        }
    }
    
    private func showToast(_ msg: String) {
        withAnimation { toastMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { toastMessage = nil }
        }
    }
}

struct MapLocationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - 3. Photo Collage Studio Section
public struct PhotoCollageStudioSection: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []
    @State private var selectedAspectRatio: CollageAspectRatio = .square
    @State private var cornerRadius: Double = 8
    @State private var spacing: Double = 6
    @State private var backgroundColor: Color = .black
    @State private var isRendering: Bool = false
    @State private var renderedCollageImage: UIImage? = nil
    @State private var showingExportShare: Bool = false
    @State private var toastMessage: String? = nil
    
    public enum CollageAspectRatio: String, CaseIterable, Identifiable {
        case square = "1:1 Square"
        case portrait = "4:5 Portrait"
        case story = "9:16 Story"
        case landscape = "16:9 Landscape"
        
        public var id: String { rawValue }
        
        public var ratio: CGFloat {
            switch self {
            case .square: return 1.0
            case .portrait: return 4.0 / 5.0
            case .story: return 9.0 / 16.0
            case .landscape: return 16.0 / 9.0
            }
        }
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Multi-photo Picker Trigger
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 9, matching: .images) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.square.fill.on.square.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loadedImages.isEmpty ? "Select 2 to 9 Photos for Collage" : "Change Photos (\(loadedImages.count) Selected)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Automatic intelligent grid layouts from 2 to 9 photos")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.purple.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onChange(of: selectedItems) { newItems in
                    loadSelectedImages(newItems)
                }
                
                if !loadedImages.isEmpty {
                    // Collage Preview Canvas
                    VStack(spacing: 10) {
                        CollageCanvasView(
                            images: loadedImages,
                            aspectRatio: selectedAspectRatio.ratio,
                            spacing: spacing,
                            cornerRadius: cornerRadius,
                            bgColor: backgroundColor
                        )
                        .frame(maxWidth: 340)
                        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                        .padding(.vertical, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    
                    // Customization Controls
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Collage Styling")
                            .font(.system(size: 14, weight: .bold))
                        
                        // Aspect Ratio Picker
                        Picker("Aspect Ratio", selection: $selectedAspectRatio) {
                            ForEach(CollageAspectRatio.allCases) { ar in
                                Text(ar.rawValue).tag(ar)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        // Spacing Slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Border & Gap Spacing")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text("\(Int(spacing)) pt")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            Slider(value: $spacing, in: 0...20, step: 1)
                        }
                        
                        // Corner Radius Slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Corner Rounding")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text("\(Int(cornerRadius)) pt")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            Slider(value: $cornerRadius, in: 0...24, step: 1)
                        }
                        
                        // Background Colors
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Background Canvas Theme")
                                .font(.system(size: 12, weight: .semibold))
                            
                            HStack(spacing: 12) {
                                bgThemeCircle(color: .black)
                                bgThemeCircle(color: .white)
                                bgThemeCircle(color: Color(red: 0.1, green: 0.12, blue: 0.2))
                                bgThemeCircle(color: Color(red: 0.15, green: 0.05, blue: 0.15))
                                bgThemeCircle(color: Color(red: 0.05, green: 0.15, blue: 0.1))
                                bgThemeCircle(color: Color(red: 0.18, green: 0.14, blue: 0.1))
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // Export & Save Button
                    Button(action: {
                        renderAndExportCollage()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up.fill")
                            Text("Save / Export Collage Image")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(color: Color.purple.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                } else {
                    // Empty state guide
                    VStack(spacing: 14) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 46))
                            .foregroundColor(.purple.opacity(0.6))
                            .padding(.top, 24)
                        
                        Text("Create Seamless Photo Collages")
                            .font(.system(size: 16, weight: .bold))
                        
                        Text("Select 2 to 9 photos from your library to generate custom side-by-side splits, 2×2 grids, and multi-photo stories.")
                            .font(.system(size: 12.5))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $showingExportShare) {
            if let img = renderedCollageImage {
                ShareSheetView(activityItems: [img])
            }
        }
    }
    
    private func bgThemeCircle(color: Color) -> some View {
        Button(action: {
            HapticManager.selection()
            self.backgroundColor = color
        }) {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(backgroundColor == color ? Color.blue : Color.secondary.opacity(0.3), lineWidth: backgroundColor == color ? 3 : 1)
                )
        }
    }
    
    private func loadSelectedImages(_ items: [PhotosPickerItem]) {
        self.loadedImages.removeAll()
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result, let data = data, let uiImg = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.loadedImages.append(uiImg)
                    }
                }
            }
        }
    }
    
    private func renderAndExportCollage() {
        guard !loadedImages.isEmpty else { return }
        HapticManager.light()
        
        let renderer = ImageRenderer(content:
            CollageCanvasView(
                images: loadedImages,
                aspectRatio: selectedAspectRatio.ratio,
                spacing: spacing,
                cornerRadius: cornerRadius,
                bgColor: backgroundColor
            )
            .frame(width: 1080, height: 1080 / selectedAspectRatio.ratio)
        )
        renderer.scale = 2.0
        
        if let uiImg = renderer.uiImage {
            self.renderedCollageImage = uiImg
            UIImageWriteToSavedPhotosAlbum(uiImg, nil, nil, nil)
            self.showingExportShare = true
            HapticManager.success()
        }
    }
}

// MARK: - Dynamic Collage Layout Canvas
struct CollageCanvasView: View {
    let images: [UIImage]
    let aspectRatio: CGFloat
    let spacing: CGFloat
    let cornerRadius: CGFloat
    let bgColor: Color
    
    var body: some View {
        ZStack {
            bgColor
            
            layoutForImageCount
                .padding(spacing)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .cornerRadius(cornerRadius)
    }
    
    @ViewBuilder
    private var layoutForImageCount: some View {
        switch images.count {
        case 1:
            collageTile(images[0])
        case 2:
            HStack(spacing: spacing) {
                collageTile(images[0])
                collageTile(images[1])
            }
        case 3:
            HStack(spacing: spacing) {
                collageTile(images[0])
                VStack(spacing: spacing) {
                    collageTile(images[1])
                    collageTile(images[2])
                }
            }
        case 4:
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    collageTile(images[0])
                    collageTile(images[1])
                }
                HStack(spacing: spacing) {
                    collageTile(images[2])
                    collageTile(images[3])
                }
            }
        case 5:
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    collageTile(images[0])
                    collageTile(images[1])
                }
                HStack(spacing: spacing) {
                    collageTile(images[2])
                    collageTile(images[3])
                    collageTile(images[4])
                }
            }
        case 6:
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    collageTile(images[0])
                    collageTile(images[1])
                    collageTile(images[2])
                }
                HStack(spacing: spacing) {
                    collageTile(images[3])
                    collageTile(images[4])
                    collageTile(images[5])
                }
            }
        default:
            // 7 to 9 images: 3x3 Grid
            let slice = Array(images.prefix(9))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: spacing), GridItem(.flexible(), spacing: spacing), GridItem(.flexible(), spacing: spacing)], spacing: spacing) {
                ForEach(0..<slice.count, id: \.self) { idx in
                    collageTile(slice[idx])
                }
            }
        }
    }
    
    private func collageTile(_ img: UIImage) -> some View {
        Image(uiImage: img)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()
            .cornerRadius(max(0, cornerRadius - spacing / 2))
    }
}
