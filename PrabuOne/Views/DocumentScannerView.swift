import SwiftUI
import VisionKit
import PhotosUI
import PDFKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Document Filter Enum

public enum DocumentEnhanceFilter: String, CaseIterable, Identifiable {
    case original = "Original"
    case documentBW = "B&W Document"
    case grayscale = "Grayscale"
    case colorEnhanced = "Color Enhanced"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .original: return "photo"
        case .documentBW: return "doc.text.fill"
        case .grayscale: return "circle.lefthalf.filled"
        case .colorEnhanced: return "sparkles"
        }
    }
    
    public var tintColor: Color {
        switch self {
        case .original: return .secondary
        case .documentBW: return .cyan
        case .grayscale: return .purple
        case .colorEnhanced: return .emeraldAccent
        }
    }
}

// MARK: - Scanned Page Model

public struct ScannedPageItem: Identifiable {
    public let id: UUID
    public var originalImage: UIImage
    public var rotationDegrees: CGFloat
    public var filter: DocumentEnhanceFilter
    
    // Cached rendered image
    public var renderedImage: UIImage?
    
    public init(id: UUID = UUID(), image: UIImage, rotationDegrees: CGFloat = 0, filter: DocumentEnhanceFilter = .documentBW) {
        self.id = id
        self.originalImage = image
        self.rotationDegrees = rotationDegrees
        self.filter = filter
        self.renderedImage = DocumentImageProcessor.process(image: image, rotation: rotationDegrees, filter: filter)
    }
    
    public mutating func update(filter: DocumentEnhanceFilter? = nil, rotationDelta: CGFloat? = nil) {
        if let newFilter = filter {
            self.filter = newFilter
        }
        if let delta = rotationDelta {
            self.rotationDegrees = CGFloat(Int(self.rotationDegrees + delta) % 360)
        }
        self.renderedImage = DocumentImageProcessor.process(image: originalImage, rotation: rotationDegrees, filter: self.filter)
    }
}

// MARK: - Document Image Enhancer Engine

public struct DocumentImageProcessor {
    private static let ciContext = CIContext(options: nil)
    
    public static func process(image: UIImage, rotation: CGFloat, filter: DocumentEnhanceFilter) -> UIImage {
        var working = image
        
        // 1. Rotate if needed
        if rotation != 0 {
            working = rotate(image: working, degrees: rotation)
        }
        
        // 2. Apply enhancement filter
        return applyFilter(filter, to: working)
    }
    
    public static func rotate(image: UIImage, degrees: CGFloat) -> UIImage {
        let radians = degrees * .pi / 180.0
        var newSize = CGRect(origin: .zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: radians)).integral.size
        newSize.width = floor(abs(newSize.width))
        newSize.height = floor(abs(newSize.height))
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: radians)
        image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width, height: image.size.height))
        
        let rotated = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return rotated ?? image
    }
    
    public static func applyFilter(_ filter: DocumentEnhanceFilter, to image: UIImage) -> UIImage {
        guard filter != .original else { return image }
        guard let ciImage = CIImage(image: image) else { return image }
        
        var outputCIImage = ciImage
        
        switch filter {
        case .original:
            return image
            
        case .documentBW:
            // High contrast black and white paper photocopy filter
            if let mono = CIFilter(name: "CIColorMonochrome") {
                mono.setValue(outputCIImage, forKey: kCIInputImageKey)
                mono.setValue(CIColor(red: 0, green: 0, blue: 0), forKey: kCIInputColorKey)
                mono.setValue(1.0, forKey: kCIInputIntensityKey)
                if let monoOut = mono.outputImage {
                    if let controls = CIFilter(name: "CIColorControls") {
                        controls.setValue(monoOut, forKey: kCIInputImageKey)
                        controls.setValue(1.45, forKey: kCIInputContrastKey)
                        controls.setValue(0.12, forKey: kCIInputBrightnessKey)
                        if let ctrlOut = controls.outputImage {
                            outputCIImage = ctrlOut
                        }
                    }
                }
            }
            
        case .grayscale:
            if let gray = CIFilter(name: "CIPhotoEffectMono") {
                gray.setValue(outputCIImage, forKey: kCIInputImageKey)
                if let res = gray.outputImage {
                    outputCIImage = res
                }
            }
            
        case .colorEnhanced:
            // Boost saturation and edge sharpness for identity cards / official stamps
            if let controls = CIFilter(name: "CIColorControls") {
                controls.setValue(outputCIImage, forKey: kCIInputImageKey)
                controls.setValue(1.35, forKey: kCIInputSaturationKey)
                controls.setValue(1.2, forKey: kCIInputContrastKey)
                controls.setValue(0.04, forKey: kCIInputBrightnessKey)
                if let res = controls.outputImage {
                    outputCIImage = res
                }
            }
        }
        
        if let cgImage = ciContext.createCGImage(outputCIImage, from: outputCIImage.extent) {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }
        return image
    }
    
    /// Compiles all scanned pages into a standard A4 multi-page PDF Data
    public static func generateMultiPagePDF(from pages: [ScannedPageItem]) -> Data {
        let a4Bounds = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // Standard 72 DPI A4 points
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: a4Bounds)
        
        return pdfRenderer.pdfData { context in
            for page in pages {
                let imgToDraw = page.renderedImage ?? page.originalImage
                context.beginPage()
                
                let margin: CGFloat = 20.0
                let printableWidth = a4Bounds.width - (margin * 2)
                let printableHeight = a4Bounds.height - (margin * 2)
                
                let imgWidth = imgToDraw.size.width
                let imgHeight = imgToDraw.size.height
                guard imgWidth > 0, imgHeight > 0 else { continue }
                
                let imgRatio = imgWidth / imgHeight
                let pageRatio = printableWidth / printableHeight
                
                var drawRect = CGRect.zero
                if imgRatio > pageRatio {
                    drawRect.size.width = printableWidth
                    drawRect.size.height = printableWidth / imgRatio
                    drawRect.origin.x = margin
                    drawRect.origin.y = margin + (printableHeight - drawRect.size.height) / 2
                } else {
                    drawRect.size.height = printableHeight
                    drawRect.size.width = printableHeight * imgRatio
                    drawRect.origin.x = margin + (printableWidth - drawRect.size.width) / 2
                    drawRect.origin.y = margin
                }
                
                imgToDraw.draw(in: drawRect)
            }
        }
    }
}

// MARK: - Multi-Page Document Scanner & PDF Converter View

public struct DocumentScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    // Scanned Pages State
    @State private var pages: [ScannedPageItem] = []
    @State private var selectedPageIndex: Int = 0
    
    // Scanner Modal
    @State private var showingCameraScanner = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    
    // Save to Vault Sheet
    @State private var showingSaveSheet = false
    @State private var showingShareSheet = false
    @State private var generatedPDFData: Data? = nil
    
    // Toast Feedback
    @State private var toastMessage: String? = nil
    
    private let isScannerHardwareSupported = VNDocumentCameraViewController.isSupported
    
    public init(store: LifeStore) {
        self.store = store
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if pages.isEmpty {
                    emptyScannerPromptView
                } else {
                    activeEditorView
                }
                
                // Toast
                if let toast = toastMessage {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(toast)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                        .shadow(radius: 6)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("Document Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                
                if !pages.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            HapticManager.light()
                            prepareAndShowSaveModal()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.down.fill")
                                Text("Save PDF")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.teal)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCameraScanner) {
                DocumentCameraCaptureRepresentable { scannedImages in
                    addScannedImages(scannedImages)
                }
                .ignoresSafeArea()
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                importFromPhotos(newItems)
            }
            .sheet(isPresented: $showingSaveSheet) {
                if let pdfData = generatedPDFData {
                    SaveScannedDocumentToVaultSheet(
                        store: store,
                        pdfData: pdfData,
                        pageCount: pages.count,
                        onSaved: {
                            dismiss()
                        }
                    )
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let pdfData = generatedPDFData {
                    PDFShareActivitySheet(pdfData: pdfData, fileName: "Scanned_Document_\(pages.count)_Pages.pdf")
                }
            }
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyScannerPromptView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.teal.opacity(0.25), Color.teal.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "doc.viewfinder.fill")
                    .font(.system(size: 54))
                    .foregroundColor(.teal)
            }
            
            VStack(spacing: 8) {
                Text("Multi-Page Document Scanner")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Scan contracts, vehicle RC, IDs, and multi-page receipts with automatic edge detection, document enhancers, and instant PDF conversion.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 12) {
                if isScannerHardwareSupported {
                    Button(action: {
                        HapticManager.light()
                        showingCameraScanner = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                            Text("Start Camera Scan")
                                .fontWeight(.bold)
                        }
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.teal)
                        .cornerRadius(14)
                        .shadow(color: Color.teal.opacity(0.35), radius: 8, y: 4)
                    }
                }
                
                // Photo Library Import Button
                PhotosPicker(selection: $selectedPhotoItems, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Import Pages from Photos")
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 15))
                    .foregroundColor(.teal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.teal.opacity(0.12))
                    .cornerRadius(14)
                }
                
                // Test Sample for Simulator / Demonstration
                Button(action: {
                    loadSimulatorDemoDocuments()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("Load 2-Page Sample Contract & Receipt")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 36)
            
            Spacer()
        }
    }
    
    // MARK: - Active Editor & Enhancer Studio
    
    private var activeEditorView: some View {
        VStack(spacing: 0) {
            // Top Preview Card of Current Page
            if selectedPageIndex < pages.count {
                let currentPage = pages[selectedPageIndex]
                
                VStack(spacing: 8) {
                    // Header Status (Page X of Y)
                    HStack {
                        Text("PAGE \(selectedPageIndex + 1) OF \(pages.count)")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                        
                        Spacer()
                        
                        // Delete Page
                        Button(role: .destructive) {
                            deleteCurrentPage()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Large Page Canvas
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
                        
                        if let rendered = currentPage.renderedImage {
                            Image(uiImage: rendered)
                                .resizable()
                                .scaledToFit()
                                .padding(6)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            Image(uiImage: currentPage.originalImage)
                                .resizable()
                                .scaledToFit()
                                .padding(6)
                        }
                    }
                    .frame(maxHeight: 330)
                    .padding(.horizontal, 20)
                    
                    // Page Rotation & Adjust Bar
                    HStack(spacing: 16) {
                        Button(action: {
                            rotateCurrentPage(by: 90)
                        }) {
                            Label("Rotate 90°", systemImage: "rotate.right.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color(UIColor.tertiarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            applyFilterToAllPages(currentPage.filter)
                        }) {
                            Label("Apply Filter to All", systemImage: "square.3.layers.3d.down.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.teal)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.teal.opacity(0.12))
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 2)
                }
            }
            
            Divider().padding(.vertical, 10)
            
            // Filter Presets Bar
            VStack(alignment: .leading, spacing: 6) {
                Text("DOCUMENT ENHANCER FILTERS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(DocumentEnhanceFilter.allCases) { filter in
                            let isSelected = selectedPageIndex < pages.count && pages[selectedPageIndex].filter == filter
                            
                            Button(action: {
                                HapticManager.selection()
                                setFilterForCurrentPage(filter)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: filter.iconName)
                                    Text(filter.rawValue)
                                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                }
                                .foregroundColor(isSelected ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color.teal : Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isSelected ? Color.teal : Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            Divider().padding(.vertical, 10)
            
            // Bottom Multi-Page Thumbnails Strip & Add Page Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("PAGES (\(pages.count))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Share / Export PDF icon
                    Button(action: {
                        prepareAndShowShareModal()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export PDF")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.teal)
                    }
                }
                .padding(.horizontal, 20)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Page Thumbnails
                        ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                            Button(action: {
                                HapticManager.selection()
                                selectedPageIndex = index
                            }) {
                                ZStack(alignment: .bottomTrailing) {
                                    if let rendered = page.renderedImage {
                                        Image(uiImage: rendered)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 58, height: 76)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    
                                    Text("\(index + 1)")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.black.opacity(0.75))
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                        .padding(3)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedPageIndex == index ? Color.teal : Color.clear, lineWidth: 2.5)
                                )
                            }
                        }
                        
                        // Add Page Button (Camera or Gallery)
                        Menu {
                            if isScannerHardwareSupported {
                                Button {
                                    showingCameraScanner = true
                                } label: {
                                    Label("Scan More with Camera", systemImage: "camera")
                                }
                            }
                            
                            Button {
                                // Handled via PhotosPicker
                            } label: {
                                PhotosPicker(selection: $selectedPhotoItems, matching: .images) {
                                    Label("Import from Photos", systemImage: "photo")
                                }
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                Text("Add")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.teal)
                            .frame(width: 58, height: 76)
                            .background(Color.teal.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                    .foregroundColor(.teal.opacity(0.5))
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Logic & Actions
    
    private func addScannedImages(_ images: [UIImage]) {
        for img in images {
            pages.append(ScannedPageItem(image: img, filter: .documentBW))
        }
        selectedPageIndex = max(0, pages.count - 1)
        HapticManager.success()
        showToast("Added \(images.count) Scanned Page\(images.count > 1 ? "s" : "")")
    }
    
    private func importFromPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var loaded: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    loaded.append(uiImage)
                }
            }
            await MainActor.run {
                self.addScannedImages(loaded)
                self.selectedPhotoItems.removeAll()
            }
        }
    }
    
    private func setFilterForCurrentPage(_ filter: DocumentEnhanceFilter) {
        guard selectedPageIndex < pages.count else { return }
        pages[selectedPageIndex].update(filter: filter)
    }
    
    private func applyFilterToAllPages(_ filter: DocumentEnhanceFilter) {
        for i in 0..<pages.count {
            pages[i].update(filter: filter)
        }
        HapticManager.success()
        showToast("Applied \(filter.rawValue) to all \(pages.count) pages")
    }
    
    private func rotateCurrentPage(by degrees: CGFloat) {
        guard selectedPageIndex < pages.count else { return }
        HapticManager.selection()
        pages[selectedPageIndex].update(rotationDelta: degrees)
    }
    
    private func deleteCurrentPage() {
        guard selectedPageIndex < pages.count else { return }
        HapticManager.light()
        pages.remove(at: selectedPageIndex)
        if selectedPageIndex >= pages.count {
            selectedPageIndex = max(0, pages.count - 1)
        }
        showToast("Page deleted")
    }
    
    private func prepareAndShowSaveModal() {
        let pdfData = DocumentImageProcessor.generateMultiPagePDF(from: pages)
        self.generatedPDFData = pdfData
        self.showingSaveSheet = true
    }
    
    private func prepareAndShowShareModal() {
        let pdfData = DocumentImageProcessor.generateMultiPagePDF(from: pages)
        self.generatedPDFData = pdfData
        self.showingShareSheet = true
    }
    
    private func showToast(_ msg: String) {
        withAnimation {
            toastMessage = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                if toastMessage == msg {
                    toastMessage = nil
                }
            }
        }
    }
    
    // MARK: - Simulator Sample Demo Documents
    
    private func loadSimulatorDemoDocuments() {
        // Generate 2 realistic sample document cards (e.g. Vehicle Insurance & Receipt)
        let page1 = generateSampleDocumentImage(title: "VEHICLE RC & CERTIFICATE", subtitle: "Transport Department • Registration #DL-01-AB-1234", isDarkText: true)
        let page2 = generateSampleDocumentImage(title: "ANNUAL VEHICLE INSURANCE POLICY", subtitle: "Policy #HDFC-ERGO-992819 • Comprehensive Cover", isDarkText: false)
        
        pages = [
            ScannedPageItem(image: page1, filter: .documentBW),
            ScannedPageItem(image: page2, filter: .documentBW)
        ]
        selectedPageIndex = 0
        HapticManager.success()
        showToast("Loaded 2-Page Sample Document")
    }
    
    private func generateSampleDocumentImage(title: String, subtitle: String, isDarkText: Bool) -> UIImage {
        let size = CGSize(width: 800, height: 1100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { ctx in
            // White document paper with subtle off-white texture
            UIColor(white: 0.96, alpha: 1.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            // Header box
            UIColor(red: 0.1, green: 0.3, blue: 0.5, alpha: 0.15).setFill()
            ctx.fill(CGRect(x: 40, y: 50, width: 720, height: 100))
            
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26, weight: .heavy),
                .foregroundColor: UIColor.black
            ]
            title.draw(at: CGPoint(x: 60, y: 70), withAttributes: titleAttrs)
            
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            subtitle.draw(at: CGPoint(x: 60, y: 110), withAttributes: subAttrs)
            
            // Mock document text rows
            UIColor.lightGray.withAlphaComponent(0.4).setStroke()
            for i in 0..<14 {
                let y = CGFloat(200 + (i * 55))
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 50, y: y))
                path.addLine(to: CGPoint(x: 750, y: y))
                path.lineWidth = 1.0
                path.stroke()
                
                let rowAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: UIColor.gray
                ]
                "Document Section #\(i + 1) — Certified and Verified Record of Prabu One Personal Vault.".draw(at: CGPoint(x: 50, y: y - 22), withAttributes: rowAttrs)
            }
            
            // Official Stamp
            let stampRect = CGRect(x: 520, y: 920, width: 220, height: 90)
            UIColor(red: 0.1, green: 0.6, blue: 0.4, alpha: 0.2).setFill()
            ctx.fill(stampRect)
            
            let stampAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15, weight: .bold),
                .foregroundColor: UIColor(red: 0.1, green: 0.5, blue: 0.3, alpha: 1.0)
            ]
            "VERIFIED ORIGINAL\nPRABU ONE VAULT".draw(in: CGRect(x: 535, y: 940, width: 190, height: 50), withAttributes: stampAttrs)
        }
    }
}

// MARK: - Save Scanned Document to Vault Sheet

public struct SaveScannedDocumentToVaultSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    let pdfData: Data
    let pageCount: Int
    var onSaved: () -> Void
    
    @State private var title: String = "Scanned Document"
    @State private var documentType: String = "RC Book"
    @State private var documentNumber: String = ""
    @State private var hasExpiry: Bool = false
    @State private var expiryDate: Date = Date().addingTimeInterval(86400 * 365)
    
    let docTypes = ["RC Book", "Driving License", "Passport", "Aadhaar Card", "PAN Card", "Insurance Policy", "PUC Certificate", "Agreement", "Others"]
    
    let suggestionPresets = ["RC Book", "Driving License", "Passport", "Aadhaar Card", "PAN Card", "Insurance Policy", "PUC Certificate", "Medical Record", "Salary Slip"]
    
    public var body: some View {
        NavigationStack {
            Form {
                // PDF Details Header
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.teal.opacity(0.16))
                                .frame(width: 52, height: 52)
                            
                            Image(systemName: "doc.richtext.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.teal)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Multi-Page PDF Ready")
                                .font(.system(size: 15, weight: .bold))
                            HStack(spacing: 6) {
                                Text("\(pageCount) Page\(pageCount > 1 ? "s" : "")")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.teal)
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(formatBytes(pdfData.count))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Text("Will be saved to Document Vault & Google Drive backup")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Document Info
                Section("Document Information") {
                    TextField("Document Title (e.g. Vehicle RC, Passport)", text: $title)
                    
                    // Quick Suggestions Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestionPresets, id: \.self) { preset in
                                Button(action: {
                                    HapticManager.selection()
                                    title = preset
                                    if docTypes.contains(preset) {
                                        documentType = preset
                                    }
                                }) {
                                    Text(preset)
                                        .font(.system(size: 11.5, weight: .medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color(UIColor.tertiarySystemBackground))
                                        .foregroundColor(.primary)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Picker("Document Type", selection: $documentType) {
                        ForEach(docTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    
                    TextField("Document Number / ID", text: $documentNumber)
                }
                
                Section("Validity & Expiry") {
                    Toggle("Has Expiry Date", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: [.date])
                    }
                }
            }
            .navigationTitle("Save to Digital Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save to Vault") {
                        saveDocumentToVault()
                    }
                    .fontWeight(.bold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveDocumentToVault() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        let cleanNumber = documentNumber.trimmingCharacters(in: .whitespaces)
        
        // Save PDF file to vault attachments directory
        let originalName = "\(cleanTitle.replacingOccurrences(of: " ", with: "_")).pdf"
        guard let savedFile = store.saveAttachmentData(pdfData, fileExtension: "pdf", originalName: originalName) else {
            return
        }
        
        let newRecord = DocumentRecord(
            title: cleanTitle,
            documentType: documentType,
            documentNumber: cleanNumber.isEmpty ? "SCAN-\(Int(Date().timeIntervalSince1970))" : cleanNumber,
            expiryDate: hasExpiry ? expiryDate : nil,
            attachmentFileName: savedFile.fileName,
            attachmentFileType: "pdf",
            attachmentOriginalName: originalName
        )
        
        store.addDocument(newRecord)
        HapticManager.success()
        dismiss()
        onSaved()
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let b = Int64(bytes)
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: b)
    }
}

// MARK: - Native Document Camera Capture Representable (VisionKit)

struct DocumentCameraCaptureRepresentable: UIViewControllerRepresentable {
    let onImagesScanned: ([UIImage]) -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImagesScanned: onImagesScanned)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onImagesScanned: ([UIImage]) -> Void
        
        init(onImagesScanned: @escaping ([UIImage]) -> Void) {
            self.onImagesScanned = onImagesScanned
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var scannedImages: [UIImage] = []
            for i in 0..<scan.pageCount {
                let img = scan.imageOfPage(at: i)
                scannedImages.append(img)
            }
            controller.dismiss(animated: true) {
                self.onImagesScanned(scannedImages)
            }
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document camera error: \(error)")
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - PDF Share Activity Sheet

struct PDFShareActivitySheet: UIViewControllerRepresentable {
    let pdfData: Data
    let fileName: String
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? pdfData.write(to: tempURL)
        let vc = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
