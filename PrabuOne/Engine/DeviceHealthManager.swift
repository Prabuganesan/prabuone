import SwiftUI
import UIKit
import Network
import LocalAuthentication
import AVFoundation
import Darwin

/// Comprehensive Phone & Hardware Telemetry Manager.
/// Provides live metrics for Battery Health, Low Power Mode, Thermal Throttling,
/// Storage, Physical RAM, Apple Silicon Processor, Display specs, and Network.
public final class DeviceHealthManager: ObservableObject {
    public static let shared = DeviceHealthManager()
    
    // MARK: - Battery & Power
    @Published public var batteryLevel: Float = 0.85 // 0.0 to 1.0
    @Published public var batteryState: UIDevice.BatteryState = .unplugged
    @Published public var isLowPowerMode: Bool = false
    @Published public var thermalState: ProcessInfo.ThermalState = .nominal
    @Published public var isSimulator: Bool = false
    
    // MARK: - Storage (Bytes)
    @Published public var totalDiskBytes: Int64 = 0
    @Published public var freeDiskBytes: Int64 = 0
    @Published public var usedDiskBytes: Int64 = 0
    
    // MARK: - RAM (Bytes)
    @Published public var totalRAMBytes: UInt64 = 0
    @Published public var usedRAMBytes: UInt64 = 0
    @Published public var freeRAMBytes: UInt64 = 0
    
    // MARK: - Network
    @Published public var networkType: String = "Wi-Fi"
    @Published public var isConnected: Bool = true
    @Published public var isExpensiveNetwork: Bool = false
    @Published public var isConstrainedNetwork: Bool = false
    @Published public var localIPAddress: String = "Not available"
    
    // MARK: - Hardware & System
    @Published public var deviceName: String = ""
    @Published public var marketingModel: String = ""
    @Published public var modelIdentifier: String = ""
    @Published public var systemVersion: String = ""
    @Published public var processorCores: Int = 0
    @Published public var activeCores: Int = 0
    
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.prabuone.networkmonitor")
    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?
    
    public init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refreshAll()
        startNetworkMonitoring()
        startPeriodicUpdates()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelDidChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateDidChange),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerModeDidChange),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }
    
    deinit {
        timer?.invalidate()
        pathMonitor.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Refresh Telemetry
    
    public func refreshAll() {
        updateBattery()
        updateStorage()
        updateRAM()
        updateDeviceIdentity()
        updateNetworkInfo()
    }
    
    private func startPeriodicUpdates() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateBattery()
            self?.updateRAM()
            self?.updateStorage()
        }
    }
    
    @objc private func batteryLevelDidChange() {
        updateBattery()
    }
    
    @objc private func batteryStateDidChange() {
        updateBattery()
    }
    
    @objc private func powerModeDidChange() {
        DispatchQueue.main.async {
            self.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
    
    // MARK: - Battery Metrics
    
    private func updateBattery() {
        let level = UIDevice.current.batteryLevel
        if level < 0 {
            // Simulator or unsupported
            self.batteryLevel = 0.85
            self.isSimulator = true
        } else {
            self.batteryLevel = level
            self.isSimulator = false
        }
        self.batteryState = UIDevice.current.batteryState
        self.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        self.thermalState = ProcessInfo.processInfo.thermalState
    }
    
    public var batteryPercentage: Int {
        Int(round(batteryLevel * 100))
    }
    
    public var batteryStateDescription: String {
        switch batteryState {
        case .charging: return "Charging"
        case .full: return "100% Fully Charged"
        case .unplugged: return isLowPowerMode ? "Discharging (Low Power Mode)" : "On Battery Power"
        case .unknown: return "Normal"
        @unknown default: return "Active"
        }
    }
    
    public var thermalStateDescription: String {
        switch thermalState {
        case .nominal: return "Nominal (Cool)"
        case .fair: return "Fair (Moderate Warmth)"
        case .serious: return "Warm (Throttled)"
        case .critical: return "Critical (Overheating)"
        @unknown default: return "Optimal"
        }
    }
    
    public var thermalColor: Color {
        switch thermalState {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .green
        }
    }
    
    public var estimatedRuntime: (standby: String, browsing: String, video: String) {
        let pct = Double(batteryLevel)
        let standbyHours = Int(pct * 48.0)
        let browsingHours = Int(pct * 14.0)
        let videoHours = Int(pct * 18.0)
        return (
            standby: "~\(max(1, standbyHours)) hrs",
            browsing: "~\(max(1, browsingHours)) hrs",
            video: "~\(max(1, videoHours)) hrs"
        )
    }
    
    // MARK: - Storage Metrics
    
    private func updateStorage() {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try fileURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])
            if let total = values.volumeTotalCapacity {
                self.totalDiskBytes = Int64(total)
            }
            if let available = values.volumeAvailableCapacityForImportantUsage {
                self.freeDiskBytes = available
            }
            self.usedDiskBytes = max(0, totalDiskBytes - freeDiskBytes)
        } catch {
            var stat = statvfs()
            if statvfs(NSHomeDirectory(), &stat) == 0 {
                let total = Int64(stat.f_blocks) * Int64(stat.f_frsize)
                let free = Int64(stat.f_bavail) * Int64(stat.f_frsize)
                self.totalDiskBytes = total
                self.freeDiskBytes = free
                self.usedDiskBytes = max(0, total - free)
            }
        }
    }
    
    public var usedDiskPercentage: Double {
        guard totalDiskBytes > 0 else { return 0.0 }
        return Double(usedDiskBytes) / Double(totalDiskBytes)
    }
    
    public func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    public func formatRAMBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // MARK: - RAM Metrics
    
    private func updateRAM() {
        self.totalRAMBytes = ProcessInfo.processInfo.physicalMemory
        
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let active = UInt64(stats.active_count) * pageSize
            let wire = UInt64(stats.wire_count) * pageSize
            let free = UInt64(stats.free_count) * pageSize
            self.usedRAMBytes = active + wire
            self.freeRAMBytes = free
        } else {
            // Approximation
            self.usedRAMBytes = UInt64(Double(totalRAMBytes) * 0.65)
            self.freeRAMBytes = UInt64(Double(totalRAMBytes) * 0.35)
        }
    }
    
    public var usedRAMPercentage: Double {
        guard totalRAMBytes > 0 else { return 0.0 }
        return Double(usedRAMBytes) / Double(totalRAMBytes)
    }
    
    // MARK: - Device Identity
    
    private func updateDeviceIdentity() {
        self.deviceName = UIDevice.current.name
        self.systemVersion = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        self.processorCores = ProcessInfo.processInfo.processorCount
        self.activeCores = ProcessInfo.processInfo.activeProcessorCount
        
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        self.modelIdentifier = identifier
        self.marketingModel = resolveMarketingName(identifier)
    }
    
    private func resolveMarketingName(_ id: String) -> String {
        switch id {
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPhone17,1": return "iPhone 16 Pro"
        case "iPhone17,2": return "iPhone 16 Pro Max"
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"
        case "iPhone17,5": return "iPhone 16e"
        case "arm64", "x86_64": return "iPhone Simulator"
        default:
            if id.hasPrefix("iPhone") {
                return "iPhone (\(id))"
            } else if id.hasPrefix("iPad") {
                return "iPad (\(id))"
            }
            return UIDevice.current.model
        }
    }
    
    public var uptimeString: String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let days = Int(uptime / 86400)
        let hours = Int((uptime.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((uptime.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
    
    // MARK: - Display Specs
    
    public var screenResolutionString: String {
        let bounds = UIScreen.main.bounds
        let scale = UIScreen.main.scale
        let pxW = Int(bounds.width * scale)
        let pxH = Int(bounds.height * scale)
        return "\(pxW) × \(pxH) px (@\(Int(scale))x)"
    }
    
    public var screenRefreshRate: String {
        let maxFps = UIScreen.main.maximumFramesPerSecond
        if maxFps >= 120 {
            return "120Hz ProMotion"
        } else {
            return "60Hz"
        }
    }
    
    public var screenBrightnessPercentage: Int {
        Int(round(UIScreen.main.brightness * 100))
    }
    
    // MARK: - Network Info
    
    private func startNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.isExpensiveNetwork = path.isExpensive
                self?.isConstrainedNetwork = path.isConstrained
                
                if path.usesInterfaceType(.wifi) {
                    self?.networkType = "Wi-Fi"
                } else if path.usesInterfaceType(.cellular) {
                    self?.networkType = "Cellular 5G/4G"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.networkType = "Ethernet"
                } else {
                    self?.networkType = path.status == .satisfied ? "Connected" : "Offline"
                }
                self?.updateNetworkInfo()
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }
    
    private func updateNetworkInfo() {
        self.localIPAddress = getWiFiIPAddress() ?? "Unavailable"
    }
    
    private func getWiFiIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            
            if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                if addr.sa_family == UInt8(AF_INET) {
                    let name = String(cString: ptr.pointee.ifa_name)
                    if name == "en0" || name == "en1" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                            address = String(cString: hostname)
                            break
                        }
                    }
                }
            }
        }
        freeifaddrs(ifaddr)
        return address
    }
    
    // MARK: - Biometrics & Sensors
    
    public var biometryTypeString: String {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .opticID: return "Optic ID"
            case .none: return "Passcode Only"
            @unknown default: return "Biometrics Supported"
            }
        }
        return "Passcode"
    }
    
    // MARK: - Interactive Diagnostic Tools
    
    public func triggerHapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    public func triggerImpactFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public func openiOSSettings(destination: String = "general") {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
