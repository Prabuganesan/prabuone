import Foundation

/// Data model representing screen capture telemetry and status.
public struct CaptureStats: Equatable, Sendable {
    public var isCapturing: Bool
    public var statusDescription: String
    public var framesReceived: UInt64
    public var framesDropped: UInt64
    public var fps: Double
    public var width: Int
    public var height: Int
    
    public init(
        isCapturing: Bool = false,
        statusDescription: String = "Stopped",
        framesReceived: UInt64 = 0,
        framesDropped: UInt64 = 0,
        fps: Double = 0.0,
        width: Int = 0,
        height: Int = 0
    ) {
        self.isCapturing = isCapturing
        self.statusDescription = statusDescription
        self.framesReceived = framesReceived
        self.framesDropped = framesDropped
        self.fps = fps
        self.width = width
        self.height = height
    }
}
