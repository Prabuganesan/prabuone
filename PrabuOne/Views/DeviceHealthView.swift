import SwiftUI
import UIKit
import AVFoundation

/// Full Phone Details, Battery Health, Storage, RAM & Comprehensive Hardware Diagnostics Hub.
public struct DeviceHealthView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = DeviceHealthManager.shared
    
    // Interactive Diagnostic Modal states
    @State private var showingPixelTest = false
    @State private var showingTouchDigitizerTest = false
    @State private var showingHapticTester = false
    @State private var showingGyroLevel = false
    @State private var showingDecibelMeter = false
    
    // Flashlight state
    @State private var torchBrightness: Float = 0.5
    
    // Toast Notification
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
                    
                    // MARK: - Comprehensive Hardware Diagnostic Suite
                    hardwareDiagnosticsSuite
                    
                    // MARK: - Storage & Memory (RAM) Breakdown + Cache Cleaner
                    storageAndMemoryCard
                    
                    // MARK: - Hardware & Processor Specs
                    processorAndSystemCard
                    
                    // MARK: - Super Retina Display Specs
                    displaySpecsCard
                    
                    // MARK: - Network, Latency & Connectivity
                    networkSpecsCard
                    
                    // MARK: - Battery Longevity & Care Guidelines
                    batteryLongevityTipsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Phone Info & Diagnostics")
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
            .fullScreenCover(isPresented: $showingTouchDigitizerTest) {
                TouchDigitizerTestView()
            }
            .sheet(isPresented: $showingHapticTester) {
                HapticDiagnosticsSheet(manager: manager)
            }
            .sheet(isPresented: $showingGyroLevel) {
                GyroLevelModalView(manager: manager)
            }
            .sheet(isPresented: $showingDecibelMeter) {
                DecibelMeterModalView(manager: manager)
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
            
            // Big Circular Progress Ring & Status
            HStack(spacing: 20) {
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
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(manager.batteryStateDescription)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if manager.isLowPowerMode {
                        HStack(spacing: 5) {
                            Image(systemName: "bolt.slash.fill")
                                .foregroundColor(.yellow)
                            Text("Low Power Mode Active")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Text("Thermal health is nominal. Power management is operating at peak performance capacity.")
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
                    Text("View Battery Health & Cycles in iOS Settings")
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
    
    // MARK: - Comprehensive Hardware Diagnostic Suite
    
    private var hardwareDiagnosticsSuite: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.emeraldAccent)
                Text("Hardware Diagnostic Suite")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            
            Text("Interactive diagnostic utilities to test sensors, display, speakers, microphone, and motors.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            VStack(spacing: 10) {
                // 1. Touch Digitizer Dead Zone Matrix Test
                diagnosticActionRow(
                    icon: "hand.draw.fill",
                    color: .teal,
                    title: "Screen Multi-Touch Matrix Test",
                    subtitle: "Wipe screen to detect touchscreen dead spots",
                    action: { showingTouchDigitizerTest = true }
                )
                
                // 2. Dead Pixel & Tint Inspection
                diagnosticActionRow(
                    icon: "checkerboard.rectangle",
                    color: .blue,
                    title: "Dead Pixel & Tint Inspection",
                    subtitle: "Cycles full-screen RGBW to check pixel health",
                    action: { showingPixelTest = true }
                )
                
                // 3. Dual Stereo Speaker Frequency Test
                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.orange.opacity(0.12))
                                .frame(width: 38, height: 38)
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 17))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Stereo Speaker Balance Test")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            Text(manager.activeToneDescription ?? "Check earpiece vs bottom speaker volume")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    HStack(spacing: 8) {
                        Button("Test Left (Ear)") {
                            HapticManager.selection()
                            manager.playSpeakerTone(channel: .leftEarpiece)
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.14))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                        
                        Button("Test Right (Bottom)") {
                            HapticManager.selection()
                            manager.playSpeakerTone(channel: .rightBottom)
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.14))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                        
                        Button("Stereo") {
                            HapticManager.selection()
                            manager.playSpeakerTone(channel: .stereo)
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.14))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                    }
                }
                .padding(10)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(12)
                
                // 4. Water Ejection & Dust Cleaner Tone
                diagnosticActionRow(
                    icon: "drop.triangle.fill",
                    color: .cyan,
                    title: "Water Eject & Dust Cleaner",
                    subtitle: "165Hz acoustic pulsation to shake trapped moisture",
                    action: {
                        HapticManager.success()
                        manager.startWaterEjectSound()
                    }
                )
                
                // 5. Microphone Live Decibel (dB) Sound Level Meter
                diagnosticActionRow(
                    icon: "mic.fill",
                    color: .red,
                    title: "Microphone Live Decibel Meter",
                    subtitle: "Measure ambient audio levels & test microphone",
                    action: { showingDecibelMeter = true }
                )
                
                // 6. 3-Axis Gyroscope & Spirit Bubble Level
                diagnosticActionRow(
                    icon: "circle.grid.cross.fill",
                    color: .green,
                    title: "Gyroscope & Spirit Bubble Level",
                    subtitle: "Live pitch, roll, yaw & surface tilt angles",
                    action: { showingGyroLevel = true }
                )
                
                // 7. Taptic Engine Vibration Test
                diagnosticActionRow(
                    icon: "hand.tap.fill",
                    color: .purple,
                    title: "Taptic Engine Vibration Test",
                    subtitle: "Test selection, impact, rigid, and warning pulses",
                    action: { showingHapticTester = true }
                )
                
                // 8. Flashlight Multi-Level & SOS Morse Strobe
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.yellow.opacity(0.15))
                                .frame(width: 38, height: 38)
                            Image(systemName: "flashlight.on.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 17))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Flashlight Multi-Intensity & SOS")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Variable brightness levels and emergency strobe")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    HStack(spacing: 8) {
                        Button(manager.torchLevel > 0 ? "Turn Off" : "Torch 25%") {
                            HapticManager.selection()
                            manager.setTorchLevel(manager.torchLevel > 0 ? 0.0 : 0.25)
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(manager.torchLevel > 0 ? Color.yellow.opacity(0.25) : Color.yellow.opacity(0.12))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                        
                        Button("Torch 100%") {
                            HapticManager.selection()
                            manager.setTorchLevel(1.0)
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(Color.yellow.opacity(0.12))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                        
                        Button(manager.isSOSActive ? "Stop SOS" : "SOS Strobe") {
                            HapticManager.selection()
                            manager.toggleSOSStrobe()
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(manager.isSOSActive ? Color.red.opacity(0.25) : Color.red.opacity(0.12))
                        .foregroundColor(manager.isSOSActive ? .red : .primary)
                        .cornerRadius(8)
                    }
                }
                .padding(10)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
        .padding(18)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    private func diagnosticActionRow(icon: String, color: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.selection()
            action()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
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
    
    // MARK: - Storage & RAM Memory Card
    
    private var storageAndMemoryCard: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.purple)
                    Text("Storage & Physical RAM")
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
            
            // App Cache Cleaner Action
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Temporary Cache")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(manager.formatBytes(manager.appCacheSizeBytes)) temporary files")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Clean Cache") {
                    HapticManager.selection()
                    manager.cleanAppTempCache { freed in
                        showToast("Cleaned \(manager.formatBytes(freed)) cache")
                    }
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.purple)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.12))
                .cornerRadius(8)
            }
            .padding(10)
            .background(Color(UIColor.tertiarySystemGroupedBackground))
            .cornerRadius(12)
            
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
    
    // MARK: - Network & Connectivity + Ping Tester
    
    private var networkSpecsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.blue)
                    Text("Wireless & DNS Latency")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                Spacer()
                
                Button(action: {
                    HapticManager.selection()
                    manager.runPingLatencyTest()
                }) {
                    HStack(spacing: 4) {
                        if manager.isTestingPing {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "bolt.horizontal.fill")
                        }
                        Text(manager.pingLatencyMs != nil ? "\(manager.pingLatencyMs!) ms" : "Test Ping")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Capsule())
                }
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

// MARK: - Multi-Touch Screen Digitizer Matrix Test View

struct TouchDigitizerTestView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let columns = 7
    private let rows = 12
    @State private var touchedBlocks: Set<Int> = []
    
    private var totalBlocks: Int { columns * rows }
    private var progressPercent: Int {
        Int((Double(touchedBlocks.count) / Double(totalBlocks)) * 100)
    }
    
    var body: some View {
        GeometryReader { geo in
            let blockWidth = geo.size.width / CGFloat(columns)
            let blockHeight = geo.size.height / CGFloat(rows)
            
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Grid of blocks
                VStack(spacing: 2) {
                    ForEach(0..<rows, id: \.self) { r in
                        HStack(spacing: 2) {
                            ForEach(0..<columns, id: \.self) { c in
                                let index = r * columns + c
                                let isTouched = touchedBlocks.contains(index)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isTouched ? Color.green : Color.white.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(isTouched ? Color.green.opacity(0.8) : Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
                .padding(4)
                
                // Top Instructions Overlay
                VStack {
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Text("Touch Coverage: \(progressPercent)%")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(progressPercent == 100 ? .green : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    
                    Spacer()
                    
                    Text("Swipe across all tiles to verify digitizer responsiveness")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Capsule())
                        .padding(.bottom, 24)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let location = value.location
                        let c = Int(location.x / blockWidth)
                        let r = Int(location.y / blockHeight)
                        if c >= 0 && c < columns && r >= 0 && r < rows {
                            let idx = r * columns + c
                            if !touchedBlocks.contains(idx) {
                                touchedBlocks.insert(idx)
                                HapticManager.light()
                            }
                        }
                    }
            )
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

// MARK: - Gyroscope & Spirit Bubble Level Modal

struct GyroLevelModalView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var manager: DeviceHealthManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Interactive Bubble Level Target
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                        .frame(width: 240, height: 240)
                    
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                        .frame(width: 140, height: 140)
                    
                    Circle()
                        .stroke(Color.green.opacity(0.4), lineWidth: 2)
                        .frame(width: 50, height: 50)
                    
                    // Crosshair lines
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 240, height: 1)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 1, height: 240)
                    
                    // Floating Bubble
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 42, height: 42)
                        .shadow(color: Color.green.opacity(0.5), radius: 8)
                        .offset(
                            x: CGFloat(min(100, max(-100, manager.rollDegrees * 2.5))),
                            y: CGFloat(min(100, max(-100, manager.pitchDegrees * 2.5)))
                        )
                }
                .padding(.top, 20)
                
                // Live Readings
                HStack(spacing: 16) {
                    readingTile(label: "Pitch", value: String(format: "%.1f°", manager.pitchDegrees))
                    readingTile(label: "Roll", value: String(format: "%.1f°", manager.rollDegrees))
                    readingTile(label: "Pressure", value: String(format: "%.1f hPa", manager.pressureHPa))
                }
                .padding(.horizontal, 20)
                
                Text("Tilt your phone to test the 3-axis motion gyroscope and barometer.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                Spacer()
            }
            .navigationTitle("Gyroscope & Spirit Level")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        manager.stopMotionUpdates()
                        dismiss()
                    }
                }
            }
            .onAppear {
                manager.startMotionUpdates()
            }
            .onDisappear {
                manager.stopMotionUpdates()
            }
        }
    }
    
    private func readingTile(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Decibel Meter Modal View

struct DecibelMeterModalView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var manager: DeviceHealthManager
    
    private var normalizedLevel: Double {
        // -60 dB to 0 dB mapped to 0.0 ... 1.0
        let clamped = max(-60.0, min(0.0, manager.currentDecibels))
        return Double((clamped + 60.0) / 60.0)
    }
    
    private var decibelRating: String {
        let db = manager.currentDecibels + 90 // approximate SPL
        if db < 40 { return "Whisper Quiet" }
        else if db < 60 { return "Normal Conversation" }
        else if db < 75 { return "Busy Ambient" }
        else { return "Loud Environment" }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 14)
                        .frame(width: 200, height: 200)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(normalizedLevel))
                        .stroke(
                            LinearGradient(
                                colors: [Color.green, Color.yellow, Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.red)
                        Text(String(format: "%.1f dB", manager.currentDecibels))
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                        Text(decibelRating)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 30)
                
                Text("Speak into the microphone to inspect audio input sensitivity and diaphragm responsiveness.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                Spacer()
            }
            .navigationTitle("Microphone Sound Meter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        manager.stopDecibelMeter()
                        dismiss()
                    }
                }
            }
            .onAppear {
                manager.startDecibelMeter()
            }
            .onDisappear {
                manager.stopDecibelMeter()
            }
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
