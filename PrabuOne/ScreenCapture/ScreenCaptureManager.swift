import Foundation
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif
import AVFoundation
import Combine
import UIKit
import os

/// Manages the full display capture session using iOS 27 ScreenCaptureKit APIs.
/// Fully decoupled from UI layout and responsible for stream lifecycle and frame telemetry.
public final class ScreenCaptureManager: NSObject, ObservableObject {
    
    // MARK: - Published State
    
    @Published public private(set) var stats: CaptureStats = CaptureStats()
    
    // MARK: - Public Properties
    
    public let displayLayer: AVSampleBufferDisplayLayer = {
        let layer = AVSampleBufferDisplayLayer()
        layer.videoGravity = .resizeAspect
        return layer
    }()
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.prabuganesan.prabuone", category: "ScreenCapture")
    private let captureQueue = DispatchQueue(label: "com.prabuone.captureQueue", qos: .userInteractive)
    
    #if canImport(ScreenCaptureKit)
    private var stream: SCStream?
    private let picker = SCContentSharingPicker.shared
    private var activeFilter: SCContentFilter?
    #endif
    
    // Telemetry tracking (accessed on captureQueue or synchronized)
    private var rawFramesReceived: UInt64 = 0
    private var rawFramesDropped: UInt64 = 0
    private var lastIntervalFrameCount: UInt64 = 0
    private var lastFPSCalculationTime: CFAbsoluteTime = 0
    private var currentFPS: Double = 0.0
    private var currentWidth: Int = 0
    private var currentHeight: Int = 0
    
    private var telemetryTimer: AnyCancellable?
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        #if canImport(ScreenCaptureKit)
        setupPicker()
        #else
        updateStatsOnMain { stats in
            stats.statusDescription = "Simulator (Requires iPhone Device)"
        }
        #endif
        setupLifecycleObservers()
    }
    
    deinit {
        stopTelemetryTimer()
        #if canImport(ScreenCaptureKit)
        picker.remove(self)
        #endif
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public API
    
    /// Starts the ScreenCaptureKit capture flow by presenting the system display sharing picker.
    public func startCapture() {
        #if canImport(ScreenCaptureKit)
        guard !stats.isCapturing else {
            logger.info("startCapture invoked while already capturing")
            return
        }
        
        logger.info("Activating SCContentSharingPicker for display capture")
        
        picker.isActive = true
        picker.add(self)
        
        updateStatsOnMain { stats in
            stats.statusDescription = "Selecting Display..."
        }
        
        // On iOS 27, present display-level content picker
        picker.present(using: .display)
        #else
        logger.warning("ScreenCaptureKit is not available in Simulator. Please run on a physical iPhone.")
        updateStatsOnMain { stats in
            stats.statusDescription = "Unavailable in Simulator"
        }
        #endif
    }
    
    /// Stops the active screen capture session and flushes the preview layer.
    public func stopCapture() {
        logger.info("Stopping screen capture session")
        stopTelemetryTimer()
        
        #if canImport(ScreenCaptureKit)
        Task { [weak self] in
            guard let self = self else { return }
            
            if let activeStream = self.stream {
                do {
                    try await activeStream.stopCapture()
                    logger.info("SCStream capture successfully stopped")
                } catch {
                    self.logger.error("Error stopping SCStream: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                self.stream = nil
                self.activeFilter = nil
                self.displayLayer.sampleBufferRenderer.flush()
                self.updateStatsOnMain { stats in
                    stats.isCapturing = false
                    stats.statusDescription = "Stopped"
                    stats.fps = 0.0
                }
            }
        }
        #else
        updateStatsOnMain { stats in
            stats.isCapturing = false
            stats.statusDescription = "Stopped"
        }
        #endif
    }
    
    // MARK: - Setup & Configuration
    
    #if canImport(ScreenCaptureKit)
    private func setupPicker() {
        var config = SCContentSharingPickerConfiguration()
        config.showsMicrophoneControl = false
        config.showsCameraControl = false
        picker.defaultConfiguration = config
    }
    #endif
    
    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppDidEnterBackground() {
        logger.info("App entered background during capture")
    }
    
    @objc private func handleAppDidBecomeActive() {
        logger.info("App became active")
    }
    
    // MARK: - Stream Creation
    
    #if canImport(ScreenCaptureKit)
    private func createAndStartStream(with filter: SCContentFilter) {
        let streamConfig = SCStreamConfiguration()
        // Baseline 720p 30 FPS target for Phase 1
        streamConfig.width = 1280
        streamConfig.height = 720
        streamConfig.capturesAudio = false
        
        let newStream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
        
        do {
            try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)
            self.stream = newStream
            self.activeFilter = filter
            
            Task { [weak self] in
                guard let self = self else { return }
                do {
                    try await newStream.startCapture()
                    self.logger.info("SCStream successfully started capturing")
                    
                    await MainActor.run {
                        self.resetTelemetry()
                        self.startTelemetryTimer()
                        self.updateStatsOnMain { stats in
                            stats.isCapturing = true
                            stats.statusDescription = "Running"
                        }
                    }
                } catch {
                    self.logger.error("Failed to start SCStream: \(error.localizedDescription)")
                    await MainActor.run {
                        self.updateStatsOnMain { stats in
                            stats.isCapturing = false
                            stats.statusDescription = "Failed: \(error.localizedDescription)"
                        }
                    }
                }
            }
        } catch {
            logger.error("Failed to add stream output: \(error.localizedDescription)")
            updateStatsOnMain { stats in
                stats.isCapturing = false
                stats.statusDescription = "Output Error: \(error.localizedDescription)"
            }
        }
    }
    #endif
    
    // MARK: - Telemetry Helpers
    
    private func resetTelemetry() {
        rawFramesReceived = 0
        rawFramesDropped = 0
        lastIntervalFrameCount = 0
        lastFPSCalculationTime = CFAbsoluteTimeGetCurrent()
        currentFPS = 0.0
        currentWidth = 0
        currentHeight = 0
    }
    
    private func startTelemetryTimer() {
        stopTelemetryTimer()
        telemetryTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshTelemetry()
            }
    }
    
    private func stopTelemetryTimer() {
        telemetryTimer?.cancel()
        telemetryTimer = nil
    }
    
    private func refreshTelemetry() {
        captureQueue.async { [weak self] in
            guard let self = self else { return }
            let now = CFAbsoluteTimeGetCurrent()
            let elapsed = now - self.lastFPSCalculationTime
            
            if elapsed >= 0.5 {
                let framesDelta = self.rawFramesReceived - self.lastIntervalFrameCount
                self.currentFPS = Double(framesDelta) / elapsed
                self.lastIntervalFrameCount = self.rawFramesReceived
                self.lastFPSCalculationTime = now
            }
            
            let received = self.rawFramesReceived
            let dropped = self.rawFramesDropped
            let fps = self.currentFPS
            let width = self.currentWidth
            let height = self.currentHeight
            
            DispatchQueue.main.async {
                self.updateStatsOnMain { stats in
                    stats.framesReceived = received
                    stats.framesDropped = dropped
                    stats.fps = fps
                    stats.width = width
                    stats.height = height
                }
            }
        }
    }
    
    private func updateStatsOnMain(_ block: @escaping (inout CaptureStats) -> Void) {
        if Thread.isMainThread {
            block(&stats)
        } else {
            DispatchQueue.main.async {
                block(&self.stats)
            }
        }
    }
}

// MARK: - SCContentSharingPickerObserver

#if canImport(ScreenCaptureKit)
extension ScreenCaptureManager: SCContentSharingPickerObserver {
    public func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        logger.info("SCContentSharingPicker selected content filter")
        createAndStartStream(with: filter)
    }
    
    public func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        logger.info("SCContentSharingPicker cancelled by user")
        if !stats.isCapturing {
            updateStatsOnMain { stats in
                stats.statusDescription = "Cancelled by user"
            }
        }
    }
    
    public func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        logger.error("SCContentSharingPicker failed to start: \(error.localizedDescription)")
        updateStatsOnMain { stats in
            stats.statusDescription = "Picker error: \(error.localizedDescription)"
        }
    }
}

// MARK: - SCStreamDelegate

extension ScreenCaptureManager: SCStreamDelegate {
    public func stream(_ stream: SCStream, didStopWithError error: any Error) {
        logger.error("SCStream stopped with error: \(error.localizedDescription)")
        stopTelemetryTimer()
        
        updateStatsOnMain { stats in
            stats.isCapturing = false
            stats.statusDescription = "Stopped: \(error.localizedDescription)"
            stats.fps = 0.0
        }
    }
}

// MARK: - SCStreamOutput

extension ScreenCaptureManager: SCStreamOutput {
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        
        // Inspect frame status attachments
        if let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]],
           let firstAttachment = attachmentsArray.first,
           let statusRaw = firstAttachment[SCStreamFrameInfo.status.rawValue as CFString] as? Int,
           let status = SCFrameStatus(rawValue: statusRaw) {
            
            // If display was idle (no change), it's not a dropped frame, but we don't need to re-render
            if status == .idle {
                return
            }
        }
        
        rawFramesReceived += 1
        
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            currentWidth = CVPixelBufferGetWidth(imageBuffer)
            currentHeight = CVPixelBufferGetHeight(imageBuffer)
        }
        
        // Low-latency local preview rendering using iOS 18+ sampleBufferRenderer
        let renderer = displayLayer.sampleBufferRenderer
        if renderer.status == .failed {
            renderer.flush()
        }
        
        if renderer.isReadyForMoreMediaData {
            renderer.enqueue(sampleBuffer)
        } else {
            rawFramesDropped += 1
        }
    }
}
#endif
