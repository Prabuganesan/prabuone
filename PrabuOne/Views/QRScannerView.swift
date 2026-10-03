import SwiftUI
import AVFoundation
import PhotosUI
import Vision

// MARK: - QR Content Classification Model

public enum QRContentPayload: Equatable {
    case upi(vpa: String, name: String?, amount: String?, currency: String?, note: String?, raw: String)
    case url(urlString: String)
    case wifi(ssid: String, password: String, security: String)
    case contact(name: String, phone: String?, email: String?)
    case text(content: String, format: String?)
    
    public var typeTitle: String {
        switch self {
        case .upi: return "UPI Payment"
        case .url: return "Website Link"
        case .wifi: return "Wi-Fi Network"
        case .contact: return "Contact Card"
        case .text: return "Text / Barcode"
        }
    }
    
    public var iconName: String {
        switch self {
        case .upi: return "indianrupeesign.circle.fill"
        case .url: return "safari.fill"
        case .wifi: return "wifi"
        case .contact: return "person.crop.circle.fill"
        case .text: return "barcode.viewfinder"
        }
    }
    
    public var tintColor: Color {
        switch self {
        case .upi: return .emeraldAccent
        case .url: return .blue
        case .wifi: return .purple
        case .contact: return .orange
        case .text: return .cyan
        }
    }
    
    public var primaryString: String {
        switch self {
        case .upi(let vpa, let name, let amount, _, _, _):
            if let amt = amount, !amt.isEmpty {
                return "₹\(amt) to \(name ?? vpa)"
            }
            return name ?? vpa
        case .url(let str):
            return str
        case .wifi(let ssid, _, _):
            return ssid
        case .contact(let name, _, _):
            return name
        case .text(let content, _):
            return content
        }
    }
}

// MARK: - Scan History Item

public struct QRScanHistoryRecord: Identifiable, Codable, Equatable {
    public let id: UUID
    public let date: Date
    public let rawPayload: String
    public let title: String
    public let typeName: String
    
    public init(id: UUID = UUID(), date: Date = Date(), rawPayload: String, title: String, typeName: String) {
        self.id = id
        self.date = date
        self.rawPayload = rawPayload
        self.title = title
        self.typeName = typeName
    }
}

// MARK: - Parser Helper

public struct QRScannerParser {
    public static func parse(_ raw: String, format: String? = nil) -> QRContentPayload {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. UPI Payment Link (upi://pay?...)
        if trimmed.lowercased().hasPrefix("upi://pay") {
            if let url = URL(string: trimmed),
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                var vpa = ""
                var name: String? = nil
                var amount: String? = nil
                var currency: String? = "INR"
                var note: String? = nil
                
                for item in components.queryItems ?? [] {
                    switch item.name.lowercased() {
                    case "pa": vpa = item.value ?? ""
                    case "pn": name = item.value?.replacingOccurrences(of: "+", with: " ")
                    case "am": amount = item.value
                    case "cu": currency = item.value
                    case "tn": note = item.value?.replacingOccurrences(of: "+", with: " ")
                    default: break
                    }
                }
                if !vpa.isEmpty {
                    return .upi(vpa: vpa, name: name, amount: amount, currency: currency, note: note, raw: trimmed)
                }
            }
            return .upi(vpa: trimmed, name: nil, amount: nil, currency: "INR", note: nil, raw: trimmed)
        }
        
        // 2. Wi-Fi Configuration (WIFI:T:WPA;S:MyNetwork;P:mypass;; or similar)
        if trimmed.hasPrefix("WIFI:") {
            var ssid = ""
            var password = ""
            var security = "WPA"
            
            let content = trimmed.replacingOccurrences(of: "WIFI:", with: "")
            let parts = content.components(separatedBy: ";")
            for part in parts {
                if part.hasPrefix("S:") {
                    ssid = String(part.dropFirst(2))
                } else if part.hasPrefix("P:") {
                    password = String(part.dropFirst(2))
                } else if part.hasPrefix("T:") {
                    security = String(part.dropFirst(2))
                }
            }
            return .wifi(ssid: ssid.isEmpty ? "Wi-Fi Network" : ssid, password: password, security: security)
        }
        
        // 3. vCard / Contact
        if trimmed.contains("BEGIN:VCARD") {
            var name = "Contact"
            var phone: String? = nil
            var email: String? = nil
            
            let lines = trimmed.components(separatedBy: .newlines)
            for line in lines {
                if line.hasPrefix("FN:") {
                    name = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("TEL:") || line.contains("TEL;") {
                    if let colonIndex = line.firstIndex(of: ":") {
                        phone = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    }
                } else if line.hasPrefix("EMAIL:") || line.contains("EMAIL;") {
                    if let colonIndex = line.firstIndex(of: ":") {
                        email = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
            return .contact(name: name, phone: phone, email: email)
        }
        
        // 4. Web URLs
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return .url(urlString: trimmed)
        }
        
        // 5. Plain text or standard barcode
        return .text(content: trimmed, format: format)
    }
}

// MARK: - Universal QR & Barcode Scanner View

public struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var isFlashlightOn = false
    @State private var activePayload: QRContentPayload? = nil
    @State private var rawScannedCode: String? = nil
    @State private var isScanningPaused = false
    @State private var showHistorySheet = false
    @State private var scanHistory: [QRScanHistoryRecord] = []
    
    // Photo Library Import
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var photoScanError: String? = nil
    
    // Animation line
    @State private var laserOffset: CGFloat = -110
    
    // Quick Note Save confirmation toast
    @State private var toastMessage: String? = nil
    
    private let cameraSupported = AVCaptureDevice.default(for: .video) != nil
    
    public init(store: LifeStore) {
        self.store = store
    }
    
    public var body: some View {
        NavigationStack {
            GeometryReader { screenGeo in
                let topSafeArea = screenGeo.safeAreaInsets.top
                let bottomSafeArea = screenGeo.safeAreaInsets.bottom
                let boxSize: CGFloat = min(screenGeo.size.width * 0.72, 270)
                let boxCenterOffsetY: CGFloat = -26 // optically centered slightly above center
                
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    if cameraSupported {
                        // Real Camera Preview
                        QRScannerCameraFeedRepresentable(
                            isPaused: isScanningPaused,
                            isTorchOn: isFlashlightOn,
                            onCodeScanned: { code, format in
                                handleScannedCode(code, format: format)
                            }
                        )
                        .ignoresSafeArea()
                    } else {
                        // Simulator Fallback Canvas
                        simulatorFallbackView
                    }
                    
                    // Hardware-accelerated even-odd cutout mask (zero artifacts)
                    ScannerCutoutMask(boxSize: boxSize, cornerRadius: 24, offsetY: boxCenterOffsetY)
                        .fill(Color.black.opacity(0.60), style: FillStyle(eoFill: true))
                        .ignoresSafeArea()
                    
                    // Target Box & Animated Oscillating Laser
                    reticleTargetView(boxSize: boxSize, offsetY: boxCenterOffsetY)
                    
                    // Instructions Label placed cleanly beneath the box
                    instructionsPill(boxSize: boxSize, offsetY: boxCenterOffsetY)
                    
                    // Top Controls Header & Bottom Action Bar
                    VStack(spacing: 0) {
                        topHeader(topSafeArea: topSafeArea)
                        
                        Spacer()
                        
                        // Bottom Scanned Result Card or Quick Bar
                        if let payload = activePayload {
                            scannedPayloadResultCard(payload: payload)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .padding(.bottom, max(bottomSafeArea, 16))
                        } else {
                            bottomQuickBar
                                .padding(.bottom, max(bottomSafeArea + 12, 30))
                        }
                    }
                    
                    // Toast notification
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
                            .shadow(radius: 8)
                            .padding(.bottom, activePayload != nil ? 220 : 80)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                loadHistory()
                startLaserAnimation()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                handlePhotoSelection(newItem)
            }
            .sheet(isPresented: $showHistorySheet) {
                scanHistorySheet
            }
        }
    }
    
    // MARK: - Viewfinder Reticle & Laser Sweep
    
    private func reticleTargetView(boxSize: CGFloat, offsetY: CGFloat) -> some View {
        ZStack {
            // Subtle glowing rounded border
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1.5)
            
            // Four 100% perfectly aligned corner brackets
            CornerBracketsShape(cornerRadius: 24, bracketLength: 36)
                .stroke(
                    LinearGradient(
                        colors: [Color.cyan, Color(red: 0.1, green: 0.6, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
            
            // Center subtle target dot
            Circle()
                .fill(Color.cyan.opacity(0.35))
                .frame(width: 8, height: 8)
            
            // Oscillating laser beam
            if !isScanningPaused {
                VStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0), Color.cyan.opacity(0.95), Color.cyan.opacity(0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 3)
                        .shadow(color: Color.cyan, radius: 8, x: 0, y: 0)
                        .offset(y: laserOffset)
                }
                .frame(width: boxSize - 20)
                .clipped()
            }
        }
        .frame(width: boxSize, height: boxSize)
        .offset(y: offsetY)
    }
    
    // MARK: - Instructions Pill
    
    private func instructionsPill(boxSize: CGFloat, offsetY: CGFloat) -> some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.cyan)
                Text("Align QR code, UPI, or Barcode in frame")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.92))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.65))
            .background(.ultraThinMaterial.opacity(0.4))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
        }
        .offset(y: offsetY + (boxSize / 2) + 28)
    }
    
    // MARK: - Neat Top Controls Header
    
    private func topHeader(topSafeArea: CGFloat) -> some View {
        HStack(alignment: .center) {
            // Dismiss / Close Button
            Button(action: {
                HapticManager.light()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.45))
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.20), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Clean Elegant Center Title Pill
            HStack(spacing: 7) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.cyan)
                Text("QR & Barcode")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Color.black.opacity(0.45))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            
            Spacer()
            
            // Flashlight Toggle (Torch)
            if cameraSupported {
                Button(action: {
                    HapticManager.selection()
                    isFlashlightOn.toggle()
                }) {
                    Image(systemName: isFlashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isFlashlightOn ? .yellow : .white)
                        .frame(width: 40, height: 40)
                        .background(isFlashlightOn ? Color.yellow.opacity(0.25) : Color.black.opacity(0.45))
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(isFlashlightOn ? Color.yellow.opacity(0.65) : Color.white.opacity(0.20), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, max(topSafeArea + 4, 16))
    }
    
    // MARK: - Scanned Result Action Card
    
    private func scannedPayloadResultCard(payload: QRContentPayload) -> some View {
        VStack(spacing: 14) {
            // Header with Type Badge & Dismiss
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: payload.iconName)
                        .foregroundColor(payload.tintColor)
                        .font(.system(size: 14, weight: .bold))
                    Text(payload.typeTitle.uppercased())
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(payload.tintColor)
                        .tracking(0.6)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(payload.tintColor.opacity(0.18))
                .clipShape(Capsule())
                
                Spacer()
                
                Button(action: {
                    HapticManager.selection()
                    withAnimation {
                        activePayload = nil
                        rawScannedCode = nil
                        isScanningPaused = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Scan Next")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            
            // Content Body
            switch payload {
            case .upi(let vpa, let name, let amount, _, let note, let raw):
                VStack(alignment: .leading, spacing: 6) {
                    if let amt = amount, !amt.isEmpty {
                        Text("₹\(amt)")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                    if let payee = name, !payee.isEmpty {
                        Text(payee)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("UPI ID: \(vpa)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                    
                    if let tn = note, !tn.isEmpty {
                        Text("Note: \(tn)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // UPI Action Buttons
                VStack(spacing: 8) {
                    Button(action: {
                        HapticManager.success()
                        if let url = URL(string: raw) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Open in UPI App (GPay / PhonePe / Paytm)")
                                .fontWeight(.bold)
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.emeraldAccent)
                        .cornerRadius(12)
                    }
                    
                    HStack(spacing: 10) {
                        Button(action: {
                            copyText(vpa, label: "UPI ID")
                        }) {
                            Label("Copy UPI ID", systemImage: "doc.on.doc")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.16))
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            saveToQuickNotes(title: "UPI: \(name ?? vpa)", body: "UPI ID: \(vpa)\nAmount: \(amount ?? "N/A")\nRaw: \(raw)")
                        }) {
                            Label("Save Note", systemImage: "square.and.pencil")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.16))
                                .cornerRadius(10)
                        }
                    }
                }
                
            case .url(let urlString):
                VStack(alignment: .leading, spacing: 4) {
                    Text(urlString)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 8) {
                    Button(action: {
                        HapticManager.success()
                        if let url = URL(string: urlString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "safari")
                            Text("Open Link in Safari")
                                .fontWeight(.bold)
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    HStack(spacing: 10) {
                        Button(action: {
                            copyText(urlString, label: "Web Link")
                        }) {
                            Label("Copy URL", systemImage: "doc.on.doc")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.16))
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            saveToQuickNotes(title: "Link: \(URL(string: urlString)?.host ?? "Web")", body: urlString)
                        }) {
                            Label("Save Note", systemImage: "square.and.pencil")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.16))
                                .cornerRadius(10)
                        }
                    }
                }
                
            case .wifi(let ssid, let password, let security):
                VStack(alignment: .leading, spacing: 4) {
                    Text(ssid)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Text("Security: \(security)")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    if !password.isEmpty {
                        Text("Password: \(password)")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.purple)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 10) {
                    if !password.isEmpty {
                        Button(action: {
                            copyText(password, label: "Wi-Fi Password")
                        }) {
                            Label("Copy Password", systemImage: "key.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Color.purple)
                                .cornerRadius(10)
                        }
                    }
                    
                    Button(action: {
                        saveToQuickNotes(title: "Wi-Fi: \(ssid)", body: "SSID: \(ssid)\nPassword: \(password)\nSecurity: \(security)")
                    }) {
                        Label("Save Note", systemImage: "square.and.pencil")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.white.opacity(0.16))
                            .cornerRadius(10)
                    }
                }
                
            case .contact(let name, let phone, let email):
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    if let p = phone {
                        Text("Phone: \(p)")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    if let e = email {
                        Text("Email: \(e)")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 10) {
                    if let p = phone, let url = URL(string: "tel://\(p.replacingOccurrences(of: " ", with: ""))") {
                        Button(action: {
                            UIApplication.shared.open(url)
                        }) {
                            Label("Call", systemImage: "phone.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                    }
                    
                    Button(action: {
                        copyText(phone ?? email ?? name, label: "Contact")
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.white.opacity(0.16))
                            .cornerRadius(10)
                    }
                }
                
            case .text(let content, let format):
                VStack(alignment: .leading, spacing: 4) {
                    if let fmt = format {
                        Text("Format: \(fmt)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                    Text(content)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 10) {
                    Button(action: {
                        copyText(content, label: "Scanned Content")
                    }) {
                        Label("Copy Text", systemImage: "doc.on.doc")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.cyan)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        saveToQuickNotes(title: "Scanned Code", body: content)
                    }) {
                        Label("Save Note", systemImage: "square.and.pencil")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.white.opacity(0.16))
                            .cornerRadius(10)
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.1, green: 0.12, blue: 0.18))
                .shadow(color: Color.black.opacity(0.6), radius: 16, y: -4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Bottom Quick Bar
    
    private var bottomQuickBar: some View {
        HStack(spacing: 14) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 7) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Scan Photo")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(Color.black.opacity(0.55))
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            Button(action: {
                HapticManager.light()
                showHistorySheet = true
            }) {
                HStack(spacing: 7) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.cyan)
                    Text("History (\(scanHistory.count))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(Color.black.opacity(0.55))
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Simulator Fallback View
    
    private var simulatorFallbackView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 64))
                .foregroundColor(.cyan)
            
            Text("QR & Barcode Scanner Engine")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text("Camera hardware not available in Simulator. Use interactive test buttons or import from your photo library:")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            VStack(spacing: 10) {
                Button(action: {
                    handleScannedCode("upi://pay?pa=merchant.food@okaxis&pn=Swiggy%20Order&am=480.00&cu=INR&tn=Dinner%20Payment")
                }) {
                    Label("Test UPI QR (₹480 to Swiggy)", systemImage: "indianrupeesign.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.emeraldAccent)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    handleScannedCode("https://apple.com")
                }) {
                    Label("Test Website QR (apple.com)", systemImage: "safari.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    handleScannedCode("WIFI:T:WPA;S:Home_Fiber_5G;P:UltraSpeed@2026;;")
                }) {
                    Label("Test Wi-Fi QR (Home_Fiber_5G)", systemImage: "wifi")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.purple)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    handleScannedCode("8901030912345", format: "EAN-13")
                }) {
                    Label("Test Barcode (8901030912345)", systemImage: "barcode")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.cyan)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 36)
            
            Spacer()
        }
    }
    
    // MARK: - Scan History Sheet
    
    private var scanHistorySheet: some View {
        NavigationStack {
            List {
                if scanHistory.isEmpty {
                    Text("No scans yet. Point camera at any QR or barcode to begin.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 20)
                } else {
                    ForEach(scanHistory) { item in
                        Button(action: {
                            handleScannedCode(item.rawPayload)
                            showHistorySheet = false
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: iconForType(item.typeName))
                                    .foregroundColor(.cyan)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    HStack {
                                        Text(item.typeName)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.cyan)
                                        Text("•")
                                            .foregroundColor(.secondary)
                                        Text(item.date, style: .time)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary.opacity(0.4))
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteHistoryItems)
                }
            }
            .navigationTitle("Scan History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showHistorySheet = false }
                }
                
                if !scanHistory.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Clear All") {
                            withAnimation {
                                scanHistory.removeAll()
                                saveHistory()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Actions & Logic
    
    private func handleScannedCode(_ code: String, format: String? = nil) {
        guard rawScannedCode != code else { return }
        
        HapticManager.success()
        let parsed = QRScannerParser.parse(code, format: format)
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.rawScannedCode = code
            self.activePayload = parsed
            self.isScanningPaused = true
        }
        
        // Record to history
        let record = QRScanHistoryRecord(
            rawPayload: code,
            title: parsed.primaryString,
            typeName: parsed.typeTitle
        )
        scanHistory.removeAll(where: { $0.rawPayload == code })
        scanHistory.insert(record, at: 0)
        if scanHistory.count > 30 {
            scanHistory.removeLast()
        }
        saveHistory()
    }
    
    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data),
               let ciImage = CIImage(image: uiImage) {
                
                let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
                let features = detector?.features(in: ciImage) as? [CIQRCodeFeature]
                
                await MainActor.run {
                    if let first = features?.first, let message = first.messageString, !message.isEmpty {
                        handleScannedCode(message)
                    } else {
                        // Try Vision barcode detector
                        detectBarcodesWithVision(uiImage)
                    }
                }
            }
        }
    }
    
    private func detectBarcodesWithVision(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            showToast("No QR or Barcode detected in image")
            return
        }
        
        let request = VNDetectBarcodesRequest { request, error in
            guard let results = request.results as? [VNBarcodeObservation], let first = results.first, let payload = first.payloadStringValue else {
                DispatchQueue.main.async {
                    showToast("No QR or Barcode detected in image")
                }
                return
            }
            DispatchQueue.main.async {
                handleScannedCode(payload, format: first.symbology.rawValue)
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
    
    private func copyText(_ text: String, label: String) {
        UIPasteboard.general.string = text
        HapticManager.success()
        showToast("Copied \(label)")
    }
    
    private func saveToQuickNotes(title: String, body: String) {
        store.addQuickNote(title: title, content: body)
        HapticManager.success()
        showToast("Saved to Quick Notes")
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
    
    private func startLaserAnimation() {
        laserOffset = -105
        withAnimation(Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            laserOffset = 105
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "prabuone_qr_scan_history"),
           let decoded = try? JSONDecoder().decode([QRScanHistoryRecord].self, from: data) {
            self.scanHistory = decoded
        }
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(scanHistory) {
            UserDefaults.standard.set(data, forKey: "prabuone_qr_scan_history")
        }
    }
    
    private func deleteHistoryItems(at offsets: IndexSet) {
        scanHistory.remove(atOffsets: offsets)
        saveHistory()
    }
    
    private func iconForType(_ typeName: String) -> String {
        switch typeName {
        case "UPI Payment": return "indianrupeesign.circle.fill"
        case "Website Link": return "safari.fill"
        case "Wi-Fi Network": return "wifi"
        case "Contact Card": return "person.crop.circle.fill"
        default: return "barcode.viewfinder"
        }
    }
}

// MARK: - Hardware Cutout Mask (Even-Odd)

fileprivate struct ScannerCutoutMask: Shape {
    let boxSize: CGFloat
    let cornerRadius: CGFloat
    let offsetY: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        let holeRect = CGRect(
            x: (rect.width - boxSize) / 2,
            y: (rect.height - boxSize) / 2 + offsetY,
            width: boxSize,
            height: boxSize
        )
        path.addRoundedRect(in: holeRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius), style: .continuous)
        return path
    }
}

// MARK: - Precise Corner Brackets Shape

fileprivate struct CornerBracketsShape: Shape {
    var cornerRadius: CGFloat = 24
    var bracketLength: CGFloat = 36
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = cornerRadius
        let l = bracketLength
        
        // Top Left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        
        // Top Right
        path.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        
        // Bottom Right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        
        // Bottom Left
        path.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        
        return path
    }
}

// MARK: - AVCapture Camera Feed Representable

struct QRScannerCameraFeedRepresentable: UIViewControllerRepresentable {
    let isPaused: Bool
    let isTorchOn: Bool
    let onCodeScanned: (String, String?) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onCodeScanned = onCodeScanned
        return vc
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        uiViewController.setPaused(isPaused)
        uiViewController.setTorch(isTorchOn)
    }
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String, String?) -> Void)?
    
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isPaused = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCaptureSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.stopRunning()
            }
        }
    }
    
    func setPaused(_ paused: Bool) {
        self.isPaused = paused
    }
    
    func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
    
    private func setupCaptureSession() {
        guard let videoDevice = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
            
            let metadataOutput = AVCaptureMetadataOutput()
            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                
                // Support QR, Barcodes, Aztec, DataMatrix
                let supportedTypes: [AVMetadataObject.ObjectType] = [
                    .qr, .ean13, .ean8, .code128, .code39, .code93, .upce, .dataMatrix, .pdf417, .aztec
                ]
                metadataOutput.metadataObjectTypes = metadataOutput.availableMetadataObjectTypes.filter { supportedTypes.contains($0) }
            }
            
            let layer = AVCaptureVideoPreviewLayer(session: captureSession)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.layer.bounds
            view.layer.addSublayer(layer)
            self.previewLayer = layer
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        } catch {
            print("Failed to initialize camera session: \(error)")
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !isPaused else { return }
        guard let first = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = first.stringValue, !stringValue.isEmpty else { return }
        
        onCodeScanned?(stringValue, first.type.rawValue)
    }
}
