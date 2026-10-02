import SwiftUI
import AVFoundation
import Combine

/// Dedicated screen for the Car Mirror & In-Car Cockpit Display utility.
/// Supports AirPlay Screen Mirroring, CarPlay Scene integration, External Display detection, and Full-Screen Cockpit HUD.
public struct CarMirrorView: View {
    @ObservedObject var captureManager: ScreenCaptureManager
    @ObservedObject private var store = LifeStore.shared
    
    @State private var isCockpitPresented = false
    @State private var hasExternalScreen = false
    @State private var externalScreenResolution = ""
    @State private var showAirPlayGuide = false
    @State private var showCarPlayInfo = false
    
    public init(captureManager: ScreenCaptureManager) {
        self.captureManager = captureManager
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Banner
                headerBanner
                
                // Live Screen Connection Radar
                connectionStatusCard
                
                // Primary Action: Launch Fullscreen Cockpit HUD
                launchCockpitButton
                
                // Why CarTV Shows vs Our App (Insight & Solution Card)
                carPlayVsMirroringExplainerCard
                
                // 1-2-3 Mirroring Guide for Car Display
                mirroringGuideCard
                
                // Vehicle Quick Telemetry Snapshot (What Mirrors to the Car)
                vehicleTelemetryPreviewCard
                
                // Emergency Roadside Assistance
                emergencyAssistanceCard
                
                // Advanced Stream Telemetry (Collapsible)
                advancedTelemetryCard
            }
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Car Mirror & Display")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkExternalScreens()
            setupScreenObservers()
        }
        .fullScreenCover(isPresented: $isCockpitPresented) {
            InCarCockpitHUDView(isPresented: $isCockpitPresented, store: store)
        }
    }
    
    // MARK: - Header Banner
    private var headerBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "car.side.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.blue)
                Text("IN-CAR MIRRORING")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .kerning(1.2)
                    .foregroundColor(.blue)
                Spacer()
                Text("KIA SONET")
                    .font(.system(size: 10, weight: .heavy))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
            }
            
            Text("Stream Your Cockpit to Car Display")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            
            Text("Mirror vehicle telemetry, service dues, FASTag balance, driver notes & emergency contacts onto your vehicle's touchscreen.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Connection Status Card
    private var connectionStatusCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(hasExternalScreen ? Color.green.opacity(0.2) : Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: hasExternalScreen ? "airplayvideo.badge.checkmark" : "airplayvideo")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(hasExternalScreen ? .green : .orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(hasExternalScreen ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(hasExternalScreen ? "Car Screen Connected" : "Ready to Mirror")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    Text(hasExternalScreen ? "External Resolution: \(externalScreenResolution)" : "Connect via Control Center Screen Mirroring")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    HapticManager.selection()
                    checkExternalScreens()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Launch Cockpit Button
    private var launchCockpitButton: some View {
        Button(action: {
            HapticManager.success()
            isCockpitPresented = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "gauge.with.needle.fill")
                    .font(.system(size: 20, weight: .bold))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch In-Car Cockpit HUD")
                        .font(.system(size: 16, weight: .bold))
                    Text("Full-screen landscape dashboard optimized for car touchscreen")
                        .font(.system(size: 11))
                        .opacity(0.85)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(LinearGradient(
                colors: [Color.blue, Color(red: 0.1, green: 0.35, blue: 0.85)],
                startPoint: .leading,
                endPoint: .trailing
            ))
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
    
    // MARK: - Why CarTV Shows vs Our App
    private var carPlayVsMirroringExplainerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showCarPlayInfo.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.blue)
                    Text("Why CarTV appears in car display, but not our app?")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: showCarPlayInfo ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if showCarPlayInfo {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("1.")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                        Text("Apple's Closed CarPlay Ecosystem: Apple strictly restricts which apps appear on the physical CarPlay screen. Only commercial apps approved by Apple with a special CarPlay Entitlement (like CarTV, audio, navigation) can show an icon on the car display.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("2.")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                        Text("How CarTV actually works: CarTV is registered as an approved media player. Inside CarTV, it triggers an iOS ReplayKit Screen Broadcast to stream frames to its player.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("3.")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                        Text("How our app displays on your car: You can mirror your entire screen to your car using iOS Screen Mirroring (AirPlay) or open our full-screen Cockpit Mode. We have also added the official CarPlay Scene Delegate so our app icon appears on Xcode's CarPlay Simulator!")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
        .padding(.horizontal)
    }
    
    // MARK: - 1-2-3 Mirroring Guide
    private var mirroringGuideCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.number")
                    .foregroundColor(.blue)
                Text("How to Mirror Screen to Car Display")
                    .font(.system(size: 14, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 10) {
                stepRow(number: "1", title: "Open Control Center on iPhone", desc: "Swipe down from the top-right corner of your screen (or swipe up from the bottom on Home button iPhones).")
                stepRow(number: "2", title: "Tap Screen Mirroring", desc: "Tap the Screen Mirroring icon (two overlapping rectangles).")
                stepRow(number: "3", title: "Select Your Car / Adapter", desc: "Select your car display, wireless CarPlay dongle, CarTV, or AirPlay receiver.")
                stepRow(number: "4", title: "Launch Cockpit Mode", desc: "Rotate phone to landscape and tap 'Launch In-Car Cockpit HUD' for an edge-to-edge car dashboard!")
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private func stepRow(number: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 22, height: 22)
                Text(number)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(desc)
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Vehicle Telemetry Snapshot
    private var vehicleTelemetryPreviewCard: some View {
        let vehicle = store.vehicleProfile
        let remaining = max(0, Int(vehicle.nextServiceDueKm - vehicle.currentOdometerKm))
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(.blue)
                Text("Cockpit Telemetry Snapshot")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text(vehicle.registrationNumber)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                telemetryItem(label: "ODOMETER", value: "\(Int(vehicle.currentOdometerKm)) km", icon: "gauge.medium", color: .blue)
                telemetryItem(label: "NEXT SERVICE", value: "\(remaining) km", icon: "wrench.fill", color: remaining < 1000 ? .orange : .green)
                telemetryItem(label: "FASTAG", value: "₹\(Int(vehicle.fastagBalance))", icon: "tag.fill", color: vehicle.fastagBalance < 300 ? .red : .teal)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private func telemetryItem(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(10)
    }
    
    // MARK: - Emergency Assistance Card
    private var emergencyAssistanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cross.case.fill")
                    .foregroundColor(.red)
                Text("Emergency Roadside Assistance")
                    .font(.system(size: 14, weight: .bold))
            }
            
            HStack(spacing: 8) {
                emergencyCallButton(title: "Highway RSA", number: "1033", icon: "phone.fill")
                emergencyCallButton(title: "Emergency", number: "112", icon: "shield.fill")
                emergencyCallButton(title: "Ambulance", number: "108", icon: "cross.fill")
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private func emergencyCallButton(title: String, number: String, icon: String) -> some View {
        Button(action: {
            HapticManager.warning()
            if let url = URL(string: "tel://\(number)") {
                UIApplication.shared.open(url)
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.red)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
                Text(number)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.08))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Advanced Stream Telemetry
    private var advancedTelemetryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.secondary)
                Text("Stream Telemetry & Diagnostics")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(captureManager.stats.statusDescription)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FPS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", captureManager.stats.fps))
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("DROPPED")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("\(captureManager.stats.framesDropped)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("RESOLUTION")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(captureManager.stats.width > 0 ? "\(captureManager.stats.width)x\(captureManager.stats.height)" : "--")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
        .padding(.horizontal)
    }
    
    // MARK: - Screen Observer Helpers
    private func checkExternalScreens() {
        let screens = UIScreen.screens
        if screens.count > 1 {
            hasExternalScreen = true
            let external = screens[1]
            let bounds = external.bounds
            let scale = external.scale
            let width = Int(bounds.width * scale)
            let height = Int(bounds.height * scale)
            externalScreenResolution = "\(width) x \(height)"
        } else {
            hasExternalScreen = false
            externalScreenResolution = ""
        }
    }
    
    private func setupScreenObservers() {
        NotificationCenter.default.addObserver(
            forName: UIScreen.didConnectNotification,
            object: nil,
            queue: .main
        ) { _ in
            checkExternalScreens()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification,
            object: nil,
            queue: .main
        ) { _ in
            checkExternalScreens()
        }
    }
}

// MARK: - In-Car Full-Screen Cockpit HUD View
struct InCarCockpitHUDView: View {
    @Binding var isPresented: Bool
    @ObservedObject var store: LifeStore
    
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // High-Contrast Deep Black AMOLED for In-Car Displays
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Header Bar
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "car.side.fill")
                            .foregroundColor(.blue)
                        Text(store.vehicleProfile.makeModel.uppercased())
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .kerning(1.2)
                        
                        Text(store.vehicleProfile.registrationNumber)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    // Live Digital Clock
                    Text(currentTime, style: .time)
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Exit Button
                    Button(action: {
                        HapticManager.selection()
                        isPresented = false
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Exit Cockpit")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.18))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)
                
                Divider()
                    .background(Color.white.opacity(0.15))
                
                // Main Cockpit Grid (Designed for 16:9 / 21:9 Car Screens)
                GeometryReader { geo in
                    let isLandscape = geo.size.width > geo.size.height
                    
                    if isLandscape {
                        landscapeCockpitGrid
                    } else {
                        portraitCockpitGrid
                    }
                }
                .padding(16)
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onReceive(timer) { input in
            currentTime = input
        }
    }
    
    // MARK: - Landscape Cockpit Grid (Car Display Optimal)
    private var landscapeCockpitGrid: some View {
        HStack(spacing: 14) {
            // Column 1: Live Vehicle Health & Service Due
            let vehicle = store.vehicleProfile
            let remaining = max(0, Int(vehicle.nextServiceDueKm - vehicle.currentOdometerKm))
            
            VStack(spacing: 12) {
                cockpitCard(title: "LIVE ODOMETER", icon: "speedometer", color: .cyan) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(vehicle.currentOdometerKm))")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("KILOMETERS DRIVEN")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
                
                cockpitCard(title: "NEXT SERVICE DUE", icon: "wrench.and.screwdriver.fill", color: remaining < 1000 ? .orange : .green) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(remaining) km")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(remaining < 1000 ? .orange : .green)
                        Text("Target: \(Int(vehicle.nextServiceDueKm)) km")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            // Column 2: FASTag Balance & Attention Alerts
            VStack(spacing: 12) {
                cockpitCard(title: "FASTAG BALANCE", icon: "tag.fill", color: vehicle.fastagBalance < 300 ? .red : .teal) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("₹\(Int(vehicle.fastagBalance))")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundColor(vehicle.fastagBalance < 300 ? .red : .teal)
                        Text(vehicle.fastagBalance < 300 ? "⚠️ REFILL RECOMMENDED" : "NORMAL TOLL BALANCE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(vehicle.fastagBalance < 300 ? .red : .gray)
                    }
                }
                
                let pucDays = max(0, Calendar.current.dateComponents([.day], from: Date(), to: vehicle.pucExpiryDate).day ?? 0)
                cockpitCard(title: "PUC POLLUTION STATUS", icon: "leaf.fill", color: pucDays < 30 ? .orange : .green) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(pucDays) Days")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(pucDays < 30 ? .orange : .green)
                        Text("Cert Valid Thru \(formatDate(vehicle.pucExpiryDate))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            // Column 3: Quick Driver Notes & Emergency RSA
            VStack(spacing: 12) {
                cockpitCard(title: "DRIVER QUICK NOTES", icon: "note.text", color: .yellow) {
                    if let firstNote = store.quickNotes.first {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(firstNote.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(firstNote.content)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        }
                    } else {
                        Text("No active notes. Notes added on phone appear here.")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
                
                cockpitCard(title: "EMERGENCY HOTLINE", icon: "phone.fill", color: .red) {
                    HStack(spacing: 8) {
                        emergencyPill(label: "RSA 1033", number: "1033")
                        emergencyPill(label: "POLICE 112", number: "112")
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Portrait Cockpit Grid
    private var portraitCockpitGrid: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                let vehicle = store.vehicleProfile
                let remaining = max(0, Int(vehicle.nextServiceDueKm - vehicle.currentOdometerKm))
                
                cockpitCard(title: "LIVE ODOMETER & SERVICE", icon: "speedometer", color: .cyan) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(vehicle.currentOdometerKm)) km")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            Text("Current Odometer")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(remaining) km")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundColor(remaining < 1000 ? .orange : .green)
                            Text("Service Due in")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                cockpitCard(title: "FASTAG & POLLUTION (PUC)", icon: "tag.fill", color: .teal) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("₹\(Int(vehicle.fastagBalance))")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundColor(vehicle.fastagBalance < 300 ? .red : .teal)
                            Text("FASTag Balance")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        let pucDays = max(0, Calendar.current.dateComponents([.day], from: Date(), to: vehicle.pucExpiryDate).day ?? 0)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(pucDays) Days")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundColor(pucDays < 30 ? .orange : .green)
                            Text("PUC Expiry")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                cockpitCard(title: "DRIVER QUICK NOTES", icon: "note.text", color: .yellow) {
                    if let firstNote = store.quickNotes.first {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(firstNote.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text(firstNote.content)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .lineLimit(3)
                        }
                    } else {
                        Text("No active driver notes.")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
                
                cockpitCard(title: "EMERGENCY HOTLINE", icon: "phone.fill", color: .red) {
                    HStack(spacing: 8) {
                        emergencyPill(label: "RSA: 1033", number: "1033")
                        emergencyPill(label: "Police: 112", number: "112")
                        emergencyPill(label: "Ambulance: 108", number: "108")
                    }
                }
            }
        }
    }
    
    // MARK: - Cockpit Card Component
    private func cockpitCard<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .kerning(0.8)
                    .foregroundColor(color)
                Spacer()
            }
            
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.08, green: 0.09, blue: 0.11))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func emergencyPill(label: String, number: String) -> some View {
        Button(action: {
            HapticManager.warning()
            if let url = URL(string: "tel://\(number)") {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 11, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.2))
            .foregroundColor(.red)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yy"
        return formatter.string(from: date)
    }
}
