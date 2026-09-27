import SwiftUI

/// Dedicated screen for the Car Mirror utility.
/// Provides live screen capture controls, hardware telemetry, and local frame preview.
public struct CarMirrorView: View {
    @ObservedObject var captureManager: ScreenCaptureManager
    @State private var isFullscreen = false
    
    public init(captureManager: ScreenCaptureManager) {
        self.captureManager = captureManager
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Status & Telemetry Card (collapsible)
            if !isFullscreen {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(captureManager.stats.isCapturing ? Color.green : Color.secondary.opacity(0.5))
                            .frame(width: 10, height: 10)
                        Text("Status:")
                            .fontWeight(.semibold)
                        Text(captureManager.stats.statusDescription)
                            .foregroundColor(captureManager.stats.isCapturing ? .green : .secondary)
                            .fontWeight(captureManager.stats.isCapturing ? .semibold : .regular)
                        
                        Spacer()
                        
                        if captureManager.stats.isCapturing {
                            Text("KEEP AWAKE ON")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FPS")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", captureManager.stats.fps))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dropped")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(captureManager.stats.framesDropped)")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(captureManager.stats.framesDropped > 0 ? .orange : .primary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Resolution")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(captureManager.stats.width > 0 ? "\(captureManager.stats.width)x\(captureManager.stats.height)" : "--")
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
                .padding(.horizontal)
            }
            
            // Local Preview Viewport
            ZStack {
                Color.black
                    .cornerRadius(16)
                
                LocalPreviewView(displayLayer: captureManager.displayLayer)
                    .cornerRadius(16)
                
                if !captureManager.stats.isCapturing {
                    VStack(spacing: 12) {
                        Image(systemName: "car.side.fill")
                            .font(.system(size: 46))
                            .foregroundColor(.gray)
                        Text("Tap Start Mirroring to stream display")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, isFullscreen ? 0 : 16)
            .onTapGesture {
                withAnimation {
                    isFullscreen.toggle()
                }
            }
            
            // Control Buttons
            if !isFullscreen {
                HStack(spacing: 16) {
                    Button(action: {
                        HapticManager.success()
                        captureManager.startCapture()
                        UIApplication.shared.isIdleTimerDisabled = true
                    }) {
                        Label("Start Mirroring", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(captureManager.stats.isCapturing ? Color.gray.opacity(0.4) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(captureManager.stats.isCapturing)
                    
                    Button(action: {
                        HapticManager.warning()
                        captureManager.stopCapture()
                        UIApplication.shared.isIdleTimerDisabled = false
                    }) {
                        Label("Stop Mirroring", systemImage: "stop.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(!captureManager.stats.isCapturing ? Color.gray.opacity(0.4) : Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!captureManager.stats.isCapturing)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("Car Mirror")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
