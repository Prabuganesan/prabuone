import SwiftUI
import AVFoundation

/// SwiftUI wrapper for AVSampleBufferDisplayLayer to render captured screen frames with minimal latency.
public struct LocalPreviewView: UIViewRepresentable {
    private let displayLayer: AVSampleBufferDisplayLayer
    
    public init(displayLayer: AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
    }
    
    public func makeUIView(context: Context) -> SampleBufferContainerView {
        return SampleBufferContainerView(displayLayer: displayLayer)
    }
    
    public func updateUIView(_ uiView: SampleBufferContainerView, context: Context) {
        // Layout updates are automatically handled in layoutSubviews
    }
}

/// UIKit container view that embeds and manages the frame geometry of an AVSampleBufferDisplayLayer.
public final class SampleBufferContainerView: UIView {
    private let displayLayer: AVSampleBufferDisplayLayer
    
    public init(displayLayer: AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
        super.init(frame: .zero)
        backgroundColor = .black
        
        displayLayer.videoGravity = .resizeAspect
        layer.addSublayer(displayLayer)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.frame = bounds
        CATransaction.commit()
    }
}
