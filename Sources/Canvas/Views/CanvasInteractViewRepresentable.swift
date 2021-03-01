import SwiftUI
import MultiViews
import CoreGraphics
import CoreGraphicsExtensions

struct CanvasInteractViewRepresentable: ViewRepresentable {
    
    @Binding var canvasOffset: CGPoint
    @Binding var canvasScale: CGFloat
    @Binding var canvasAngle: Angle
    
    @Binding var canvasInteractions: [CanvasInteraction]
    @Binding var canvasPanInteraction: CanvasInteraction?
    @Binding var canvasPinchInteraction: (CanvasInteraction, CanvasInteraction)?

    func makeView(context: Context) -> CanvasInteractView {
        CanvasInteractView(canvasInteractions: $canvasInteractions,
                           didMoveCanvasInteractions: context.coordinator.didMoveCanvasInteractions(_:))
    }
    
    func updateView(_ view: CanvasInteractView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(canvasOffset: $canvasOffset,
                    canvasScale: $canvasScale,
                    canvasAngle: $canvasAngle,
                    canvasInteractions: $canvasInteractions,
                    canvasPanInteraction: $canvasPanInteraction,
                    canvasPinchInteraction: $canvasPinchInteraction)
    }
    
    class Coordinator {
        
        static let velocityDampening: CGFloat = 0.98
        static let velocityRadiusThreshold: CGFloat = 0.02
        
        @Binding var canvasOffset: CGPoint
        @Binding var canvasScale: CGFloat
        @Binding var canvasAngle: Angle
        
        @Binding var canvasInteractions: [CanvasInteraction]
        @Binding var canvasPanInteraction: CanvasInteraction?
        @Binding var canvasPinchInteraction: (CanvasInteraction, CanvasInteraction)?

        #if os(iOS)
        var displayLink: CADisplayLink!
        #endif
        
        init(canvasOffset: Binding<CGPoint>,
             canvasScale: Binding<CGFloat>,
             canvasAngle: Binding<Angle>,
             canvasInteractions: Binding<[CanvasInteraction]>,
             canvasPanInteraction: Binding<CanvasInteraction?>,
             canvasPinchInteraction: Binding<(CanvasInteraction, CanvasInteraction)?>) {
            _canvasOffset = canvasOffset
            _canvasScale = canvasScale
            _canvasAngle = canvasAngle
            _canvasInteractions = canvasInteractions
            _canvasPanInteraction = canvasPanInteraction
            _canvasPinchInteraction = canvasPinchInteraction
            
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
            
            let count: Int = canvasInteractions.count
            for index in 0..<count {
                let reverseIndex: Int = count - index - 1
                let canvasInteraction: CanvasInteraction = canvasInteractions[reverseIndex]
                
                if !canvasInteraction.active {
                    guard iOS && canvasInteraction.velocityRadius > Coordinator.velocityRadiusThreshold else {
                        canvasInteractions.remove(at: reverseIndex)
                        continue
                    }
                    #if os(iOS)
                    canvasInteraction.location += canvasInteraction.velocity
                    canvasInteraction.velocity *= Coordinator.velocityDampening
                    #endif
                }
                
            }
              
            /// Pinch
            if let pinchInteraction: (CanvasInteraction, CanvasInteraction) = canvasPinchInteraction {
                let isInteracting: Bool = canvasInteractions.filter(\.active).contains(pinchInteraction.0) && canvasInteractions.filter(\.active).contains(pinchInteraction.1)
                if !isInteracting {
                    canvasPinchInteraction = nil
                }
            }
            if canvasPinchInteraction == nil {
                let activeCanvasInteractions: [CanvasInteraction] = canvasInteractions.filter(\.active)
                if activeCanvasInteractions.count >= 2 {
                    canvasPinchInteraction = (activeCanvasInteractions[0], activeCanvasInteractions[1])
                    canvasPanInteraction = nil
                }
            }
            
            /// Pan
            if let panInteraction: CanvasInteraction = canvasPanInteraction {
                let isInteracting: Bool = canvasInteractions.contains(panInteraction)
                if !isInteracting {
                    canvasPanInteraction = nil
                } else if !panInteraction.active {
                    let activeCanvasInteractions: [CanvasInteraction] = canvasInteractions.filter(\.active)
                    if activeCanvasInteractions.count == 1 {
                        canvasPanInteraction = nil
                    }
                }
            }
            if canvasPanInteraction == nil{
                let activeCanvasInteractions: [CanvasInteraction] = canvasInteractions.filter(\.active)
                if activeCanvasInteractions.count == 1 {
                    canvasPanInteraction = activeCanvasInteractions[0]
                }
            }
            
            /// Pinch
            if let pinchInteraction: (CanvasInteraction, CanvasInteraction) = canvasPinchInteraction,
               !pinchInteraction.0.active || !pinchInteraction.1.active {
                pinch()
            }
            
            /// Pan
            if let panInteraction: CanvasInteraction = canvasPanInteraction,
               !panInteraction.active {
                pan()
            }
            
        }
        
        func didMoveCanvasInteractions(_ canvasInteractions: [CanvasInteraction]) {
            print(canvasInteractions.map(\.id), ">>>>", canvasPanInteraction?.id)
            if let panInteraction: CanvasInteraction = canvasPanInteraction,
               canvasInteractions.contains(panInteraction) {
                pan()
            }
            if let pinchInteraction: (CanvasInteraction, CanvasInteraction) = canvasPinchInteraction,
               canvasInteractions.contains(pinchInteraction.0) && canvasInteractions.contains(pinchInteraction.1),
               pinchInteraction.0.active && pinchInteraction.1.active {
                pinch()
            }
        }
        
        func pan() {
            guard let panInteraction: CanvasInteraction = canvasPanInteraction else { return }
            canvasOffset += panInteraction.velocity
        }
        
        
        func pinch() {
            guard let pinchInteraction: (CanvasInteraction, CanvasInteraction) = canvasPinchInteraction else { return }
            let averageVelocity: CGVector = (pinchInteraction.0.velocity + pinchInteraction.1.velocity) / 2.0
            canvasOffset += averageVelocity
        }
        
    }
    
}
