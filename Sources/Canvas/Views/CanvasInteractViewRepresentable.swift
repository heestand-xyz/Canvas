import SwiftUI
import MultiViews
import CoreGraphics
import CoreGraphicsExtensions

struct CanvasInteractViewRepresentable: ViewRepresentable {
    
    @Binding var canvasOffset: CGPoint
    @Binding var canvasScale: CGFloat
    @Binding var canvasAngle: Angle
    
    @Binding var canvasInteractions: [CanvasInteraction]
    
    func makeView(context: Context) -> CanvasInteractView {
        CanvasInteractView(canvasInteractions: $canvasInteractions)
    }
    
    func updateView(_ view: CanvasInteractView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(canvasInteractions: $canvasInteractions)
    }
    
    class Coordinator {
        
        static let velocityDampening: CGFloat = 0.99
        static let velocityThresholdRadius: CGFloat = 0.01

        @Binding var canvasInteractions: [CanvasInteraction]

        #if os(iOS)
        var displayLink: CADisplayLink!
        #endif
        
        init(canvasInteractions: Binding<[CanvasInteraction]>) {
            _canvasInteractions = canvasInteractions
            #if os(iOS)
            displayLink = CADisplayLink(target: self, selector: #selector(frameLoop))
            displayLink.add(to: .current, forMode: .common)
            #elseif os(macOS)
            RunLoop.current.add(Timer(timeInterval: 1.0 / 60.0, repeats: true, block: { _ in
                self.frameLoop()
            }), forMode: .common)
            #endif
        }
        
        @objc func frameLoop() {
            for index in 0..<canvasInteractions.count {
                let reverseIndex: Int = canvasInteractions.count - index - 1
                let canvasInteraction: CanvasInteraction = canvasInteractions[reverseIndex]
                if !canvasInteraction.active {
                    guard canvasInteraction.velocityRadius > Coordinator.velocityThresholdRadius else {
                        canvasInteractions.remove(at: reverseIndex)
                        continue
                    }
                    canvasInteractions[reverseIndex].location += canvasInteraction.velocity
                    canvasInteractions[reverseIndex].velocity *= Coordinator.velocityDampening
                }
            }
        }
        
    }
    
}
