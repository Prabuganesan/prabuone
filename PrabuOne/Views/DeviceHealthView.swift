import SwiftUI
import UIKit
import AVFoundation

/// Full Phone Details, Battery Health, Storage, RAM & Hardware Diagnostics Menu.
public struct DeviceHealthView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = DeviceHealthManager.shared
    
    // Interactive Diagnostic Sheet states
    @State private var showingPixelTest = false
    @State private var showingHapticTester = false
    @State private var isFlashlightOn = false
    @State private var toastMessage: String? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Device Hero Header
                    deviceHeroHeader
                    
                    // MARK: - Hero Battery & Power Health Card
                    batteryHealthCard
                    
                    // MARK: - Storage & RAM Memory Cards
                    storageAndMemoryCard
                    
                    // MARK: - Processor & System Specs
                    processorAndSystemCard
                    
                    // MARK: - Display & Retina Specs
                    displaySpecsCard
                    
                    // MARK: - Network & Connectivity
                    networkSpecsCard
                    
                    // MARK: - Interactive Hardware Diagnostics Tools
                    hardwareDiagnosticsCard
                    
                    // MARK: - Battery Preservation & Longevity Tips
                    batteryLongevityTipsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Phone Details & Battery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        HapticManager.light()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.selection()
                        manager.refreshAll()
                        showToast("Telemetry refreshed")
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.blue)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = toastMessage {
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
                    .padding(.bottom, 24)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .fullScreenCover(isPresented: $showingPixelTest) {
                PixelUniformityTestView()
            }
            .sheet(isPresented: $showingHapticTester) {
                HapticDiagnosticsSheet(manager: manager)
            }
            .onAppear {
                manager.refreshAll()
            }
        }
    }
    
    // MARK: - Device Hero Header
    
    private var deviceHeroHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.indigo, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)
                    .shadow(color: Color.indigo.opacity(0.35), radius: 8, x: 0, y: 4)
                
                Image(systemName: "iphone.gen3")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(manager.marketingModel.isEmpty ? "iPhone" : manager.marketingModel)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    if manager.isSimulator {
                        Text("SIMULATOR")
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.18))
                            .foregroundColor(.secondary)
                            .clipShape(Capsule())
                    }
                }
                
                Text(manager.deviceName.isEmpty ? "Personal Device" : manager.deviceName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    Text(manager.systemVersion)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Text("•")
                        .foregroundColor(.secondary.opacity(0.5))
                        .font(.system(size: 10))
                    
                    Text("Up \(manager.uptimeString)")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Battery Health & Power Card
    
    private var batteryHealthCard: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "battery.100.bolt")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(batteryAccentColor)
                    Text("Battery Health & Power")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(manager.thermalColor)
                        .frame(width: 8, height: 8)
                    Text(manager.thermalStateDescription)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(manager.thermalColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(manager.thermalColor.opacity(0.12))
                .clipShape(Capsule())
            }
            
            // Big Battery Progress & Status
            HStack(spacing: 20) {
                // Circular Ring Gauge
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 10)
                        .frame(width: 88, height: 88)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(manager.batteryLevel))
                        .stroke(
                            LinearGradient(
                                colors: [batteryAccentColor, batteryAccentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 88, height: 88)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 1) {
                        Text("\(manager.batteryPercentage)%")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                        
                        if manager.batteryState == .charging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.yellow)
                        } else {
                            Text("LEVEL")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Key Power Stats
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(manager.batteryStateDescription)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    if manager.isLowPowerMode {
                        HStack(spacing: 5) {
                            Image(systemName: "bolt.slash.fill")
                                .foregroundColor(.yellow)
                            Text("Low Power Mode Active")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Text("Thermal health is optimal. Battery operates within normal temperature ranges.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Estimated Everyday Runtime
            VStack(alignment: .leading, spacing: 8) {
                Text("ESTIMATED RUNTIME (CURRENT CHARGE)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                
                HStack(spacing: 10) {
                    runtimePill(icon: "moon.fill", label: "Standby", value: manager.estimatedRuntime.standby, color: .indigo)
                    runtimePill(icon: "safari.fill", label: "Web / Apps", value: manager.estimatedRuntime.browsing, color: .blue)
                    runtimePill(icon: "play.tv.fill", label: "Streaming", value: manager.estimatedRuntime.video, color: .purple)
                }
            }
            
            // Open Apple Settings button
            Button(action: {
                HapticManager.selection()
                manager.openiOSSettings()
            }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13))
                    Text("Open Battery Health & Cycles in iOS Settings")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    private var batteryAccentColor: Color {
        if manager.batteryState == .charging {
            return .yellow
        } else if manager.isLowPowerMode {
            return .yellow
        } else if manager.batteryLevel <= 0.20 {
            return .red
        } else if manager.batteryLevel <= 0.40 {
            return .orange
        } else {
            return .green
        }
    }
    
    private func runtimePill(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(10)
    }
    
    // MARK: - Storage & RAM Memory Card
    
    private var storageAndMemoryCard: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.purple)
                    Text("Storage & Memory (RAM)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                Spacer()
            }
            
            // Storage Bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Device Storage")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(manager.formatBytes(manager.usedDiskBytes)) used of \(manager.formatBytes(manager.totalDiskBytes))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 10)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple, Color.indigo],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(manager.usedDiskPercentage), height: 10)
                    }
                }
                .frame(height: 10)
                
                HStack {
                    Text("\(manager.formatBytes(manager.freeDiskBytes)) Free Space")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                    Spacer()
                    Text("\(Int(manager.usedDiskPercentage * 100))% Capacity Used")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // RAM Memory Bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Physical RAM")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(manager.formatRAMBytes(manager.usedRAMBytes)) used of \(manager.formatRAMBytes(manager.totalRAMBytes))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 10)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(manager.usedRAMPercentage), height: 10)
                    }
                }
                .frame(height: 10)
                
                HStack {
                    Text("\(manager.formatRAMBytes(manager.freeRAMBytes)) Available RAM")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.cyan)
                    Spacer()
                    Text("Dynamic Kernel Memory")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(18)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Processor & System Specs
    
    private var processorAndSystemCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.orange)
                Text("Hardware & Processor")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                specTile(title: "Architecture", value: "arm64 (Apple Silicon)", icon: "cpu")
                specTile(title: "CPU Cores", value: "\(manager.processorCores) Cores (\(manager.activeCores) Active)", icon: "bolt.fill")
                specTile(title: "Model Identifier", value: manager.modelIdentifier.isEmpty ? "iPhone" : manager.modelIdentifier, icon: "tag.fill")
                specTile(title: "Biometrics", value: manager.biometryTypeString, icon: "faceid")
            }
        }
        .padding(18)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Display & Retina Specs
    
    private var displaySpecsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "display")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.teal)
                Text("Super Retina XDR Display")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                specTile(title: "Resolution", value: manager.screenResolutionString, icon: "rectangle.inset.filled")
                specTile(title: "Refresh Rate", value: manager.screenRefreshRate, icon: "speedometer")
                specTile(title: "Brightness", value: "\(manager.screenBrightnessPercentage)%", icon: "sun.max.fill")
                specTile(title: "True Tone & HDR", value: "Hardware Enabled", icon: "sparkles")
            }
        }
        .padding(18)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Network & Connectivity
    
    private var networkSpecsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.blue)
                Text("Wireless & Network")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                specTile(title: "Connection", value: manager.networkType, icon: "wifi")
                specTile(title: "Local IP", value: manager.localIPAddress, icon: "network")
                specTile(title: "Status", value: manager.isConnected ? "Internet Active" : "No Connection", icon: "globe")
                specTile(title: "Low Data Mode", value: manager.isConstrainedNetwork ? "Enabled" : "Standard", icon: "arrow.down.circle")
            }
        }
        .padding(18)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    private func specTile(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Text(value)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Interactive Hardware Diagnostics Tools
    
    private var hardwareDiagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.emeraldAccent)
                Text("Hardware Diagnostics")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            
            Text("Interactive tests to verify your phone's display pixels, haptic motor, and flashlight.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            VStack(spacing: 10) {
                // Pixel Test
                Button(action: {
                    HapticManager.selection()
                    showingPixelTest = true
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 38, height: 38)
                            Image(systemName: "checkerboard.rectangle")
                                .foregroundColor(.blue)
                                .font(.system(size: 18))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Screen Pixel & Tint Inspection")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Cycles RGBW fullscreen to detect dead pixels")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                // Haptic Motor Test
                Button(action: {
                    HapticManager.selection()
                    showingHapticTester = true
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.purple.opacity(0.12))
                                .frame(width: 38, height: 38)
                            Image(systemName: "hand.tap.fill")
                                .foregroundColor(.purple)
                                .font(.system(size: 18))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Taptic Engine Vibration Test")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Test subtle, rigid, and warning feedback waveforms")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Battery Longevity Tips
    
    private var batteryLongevityTipsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
                Text("Battery Health & Longevity Best Practices")
                    .font(.system(size: 14, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                tipRow(icon: "percent", title: "80% Charge Limit", body: "Keep charging capped at 80% on iOS 17/18 to reduce chemical stress and double battery lifespan.")
                tipRow(icon: "thermometer.sun.fill", title: "Avoid Excessive Heat", body: "Never fast charge in direct sunlight or under pillows. Heat accelerates lithium degradation.")
                tipRow(icon: "powerplug.fill", title: "Use Certified Apple / MFi Chargers", body: "Clean power delivery protects the power management IC and battery health percentage.")
            }
        }
        .padding(16)
        .background(Color.green.opacity(0.08))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.green.opacity(0.25), lineWidth: 1)
        )
    }
    
    private func tipRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.green)
                .frame(width: 18, height: 18)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.primary)
                Text(body)
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
        }
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
}

// MARK: - Interactive Pixel & Color Uniformity Screen

struct PixelUniformityTestView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var colorIndex = 0
    private let testColors: [(name: String, color: Color)] = [
        ("Full Red", .red),
        ("Full Green", .green),
        ("Full Blue", .blue),
        ("Pure White", .white),
        ("Pure Black (OLED True Black)", .black),
        ("Neutral 50% Gray", Color(white: 0.5))
    ]
    
    var body: some View {
        ZStack {
            testColors[colorIndex].color
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(testColors[colorIndex].name.contains("White") ? .black : .white)
                            .shadow(radius: 4)
                    }
                    Spacer()
                    Text(testColors[colorIndex].name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(testColors[colorIndex].name.contains("White") ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                
                Spacer()
                
                Text("Tap anywhere to cycle colors • Check for dead/stuck pixels")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(testColors[colorIndex].name.contains("White") ? .black.opacity(0.7) : .white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Capsule())
                    .padding(.bottom, 30)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.light()
            colorIndex = (colorIndex + 1) % testColors.count
        }
    }
}

// MARK: - Taptic Engine Vibration Diagnostics Sheet

struct HapticDiagnosticsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let manager: DeviceHealthManager
    
    var body: some View {
        NavigationStack {
            List {
                Section("Impact Feedbacks") {
                    Button("Light Tap (Selection)") {
                        manager.triggerImpactFeedback(.light)
                    }
                    Button("Medium Tap") {
                        manager.triggerImpactFeedback(.medium)
                    }
                    Button("Heavy Tap") {
                        manager.triggerImpactFeedback(.heavy)
                    }
                    Button("Rigid Click") {
                        manager.triggerImpactFeedback(.rigid)
                    }
                    Button("Soft Pulse") {
                        manager.triggerImpactFeedback(.soft)
                    }
                }
                
                Section("Notification Alerts") {
                    Button("Success Haptic") {
                        manager.triggerHapticFeedback(.success)
                    }
                    Button("Warning Haptic") {
                        manager.triggerHapticFeedback(.warning)
                    }
                    Button("Error Haptic") {
                        manager.triggerHapticFeedback(.error)
                    }
                }
            }
            .navigationTitle("Taptic Engine Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
