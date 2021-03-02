import SwiftUI
import MultiViews
import CoreGraphics
import CoreGraphicsExtensions

struct CanvasInteractViewRepresentable<FrontContent: View, BackContent: View>: ViewRepresentable {

    let snapAngle: Angle?

    @Binding var frameContentList: [CanvasFrameContent<FrontContent, BackContent>]
    
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
    
    func makeCoordinator() -> Coordinator<FrontContent, BackContent> {
        Coordinator(snapAngle: snapAngle,
                    frameContentList: $frameContentList,
                    canvasOffset: $canvasOffset,
                    canvasScale: $canvasScale,
                    canvasAngle: $canvasAngle,
                    canvasInteractions: $canvasInteractions,
                    canvasPanInteraction: $canvasPanInteraction,
                    canvasPinchInteraction: $canvasPinchInteraction)
    }
    
    class Coordinator<FrontContent: View, BackContent: View> {
        
        let velocityStartDampenThreshold: CGFloat = 2.0
        let velocityDampening: CGFloat = 0.98
        let velocityRadiusThreshold: CGFloat = 0.02
        let snapAngleRadius: Angle = Angle(degrees: 5)
        
        let snapAngle: Angle?

        @Binding var frameContentList: [CanvasFrameContent<FrontContent, BackContent>]

        @Binding var canvasOffset: CGPoint
        @Binding var canvasScale: CGFloat
        @Binding var canvasAngle: Angle
        var canvasCoordinate: CanvasCoordinate {
            CanvasCoordinate(offset: canvasOffset,
                             scale: canvasScale,
                             angle: canvasAngle)
        }
        
        @Binding var canvasInteractions: [CanvasInteraction]
        @Binding var canvasPanInteraction: CanvasInteraction?
        @Binding var canvasPinchInteraction: (CanvasInteraction, CanvasInteraction)?

        #if os(iOS)
        var displayLink: CADisplayLink!
        #endif
        
        init(snapAngle: Angle?,
             frameContentList: Binding<[CanvasFrameContent<FrontContent, BackContent>]>,
             canvasOffset: Binding<CGPoint>,
             canvasScale: Binding<CGFloat>,
             canvasAngle: Binding<Angle>,
             canvasInteractions: Binding<[CanvasInteraction]>,
             canvasPanInteraction: Binding<CanvasInteraction?>,
             canvasPinchInteraction: Binding<(CanvasInteraction, CanvasInteraction)?>) {
            
            self.snapAngle = snapAngle
            _frameContentList = frameContentList
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
                    if !canvasInteraction.auto {
                        guard iOS && canvasInteraction.velocityRadius > velocityStartDampenThreshold else {
                            canvasInteractions.remove(at: reverseIndex)
                            continue
                        }
                        canvasInteraction.auto = true
                    }
                    guard iOS && canvasInteraction.velocityRadius > velocityRadiusThreshold else {
                        canvasInteractions.remove(at: reverseIndex)
                        continue
                    }
                    #if os(iOS)
                    canvasInteraction.location += canvasInteraction.velocity
                    canvasInteraction.velocity *= velocityDampening
                    #endif
                }
                
            }
              
            /// Pinch
            if let pinchInteraction: (CanvasInteraction, CanvasInteraction) = canvasPinchInteraction {
                let isInteracting: Bool = canvasInteractions.filter(\.active).contains(pinchInteraction.0) && canvasInteractions.filter(\.active).contains(pinchInteraction.1)
                if !isInteracting {
                    pinchDone(pinchInteraction)
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
            
//            /// Pinch
//            if let pinchInteraction: (CanvasInteraction, CanvasInteraction) = canvasPinchInteraction,
//               pinchInteraction.0.auto || pinchInteraction.1.auto {
//                pinch()
//            }
            
            /// Pan
            if let panInteraction: CanvasInteraction = canvasPanInteraction,
               panInteraction.auto {
                pan()
            }
            
        }
        
        func didMoveCanvasInteractions(_ canvasInteractions: [CanvasInteraction]) {
            
            /// Pan
            if let panInteraction: CanvasInteraction = canvasPanInteraction,
               canvasInteractions.contains(panInteraction) {
                pan()
            }
            
            /// Pinch
            if let pinchInteraction: (CanvasInteraction, CanvasInteraction) = canvasPinchInteraction,
               canvasInteractions.contains(pinchInteraction.0) && canvasInteractions.contains(pinchInteraction.1),
               pinchInteraction.0.active && pinchInteraction.1.active {
                pinch()
            }
            
        }
        
        // MARK: - Pan
        
        func pan() {
            
            guard let panInteraction: CanvasInteraction = canvasPanInteraction else { return }
            
            if let frameContentIndex: Int = hitTestFrameContentIndex(at: panInteraction.location) {

                // ...
                
            } else {

                canvasOffset += panInteraction.velocity
                
            }
            
        }
        
        func hitTestFrameContentIndex(at location: CGPoint) -> Int? {
            let absoluteLocation: CGPoint = canvasCoordinate.absolute(location: location)
            for (index, frameContent) in frameContentList.enumerated() {
                let frame: CGRect = frameContent.frame
                switch frameContent.shape {
                case .rectangle:
                    if frame.contains(absoluteLocation) {
                        return index
                    }
                case .circle:
                    let center: CGPoint = frame.origin + frame.size / 2
                    let distance: CGFloat = sqrt(pow(center.x - absoluteLocation.x, 2.0) + pow(center.y - absoluteLocation.y, 2.0))
                    let radius: CGFloat = min(frame.size.width, frame.size.height) / 2.0
                    if distance < radius {
                        return index
                    }
                }
            }
            return nil
        }
        
        // MARK: - Pinch
        
        func pinch() {
            
            guard let pinchInteraction: (CanvasInteraction, CanvasInteraction) = canvasPinchInteraction else { return }
            
            move(pinchInteraction)
            
            scale(pinchInteraction)
            
            rotate(pinchInteraction)
            
        }
        
        func move(_ pinchInteraction: (CanvasInteraction, CanvasInteraction)) {
            
            let averageVelocity: CGVector = (pinchInteraction.0.velocity + pinchInteraction.1.velocity) / 2.0
            
            canvasOffset += averageVelocity
            
        }
        
        func scale(_ pinchInteraction: (CanvasInteraction, CanvasInteraction)) {
            
            let distanceDirection: CGPoint = pinchInteraction.0.location - pinchInteraction.1.location
            let distance: CGFloat = sqrt(pow(distanceDirection.x, 2.0) + pow(distanceDirection.y, 2.0))
            let lastDistanceDirection: CGPoint = pinchInteraction.0.lastLocation - pinchInteraction.1.lastLocation
            let lastDistance: CGFloat = sqrt(pow(lastDistanceDirection.x, 2.0) + pow(lastDistanceDirection.y, 2.0))
            let relativeScale: CGFloat = distance / lastDistance
            
            canvasScale *= relativeScale

            let averageLocation: CGPoint = (pinchInteraction.0.location + pinchInteraction.1.location) / 2.0
            let averageLocationOffset: CGPoint = averageLocation - canvasOffset
            let scaledAverageLocationOffset: CGPoint = averageLocationOffset * relativeScale
            let relativeScaleOffset: CGPoint = averageLocationOffset - scaledAverageLocationOffset
            
            canvasOffset += relativeScaleOffset
            
        }
        
        func rotate(_ pinchInteraction: (CanvasInteraction, CanvasInteraction)) {
            
            let distanceDirection: CGPoint = pinchInteraction.0.location - pinchInteraction.1.location
            let lastDistanceDirection: CGPoint = pinchInteraction.0.lastLocation - pinchInteraction.1.lastLocation
            let angleInRadians: CGFloat = atan2(distanceDirection.y, distanceDirection.x)
            let lastAngleInRadians: CGFloat = atan2(lastDistanceDirection.y, lastDistanceDirection.x)
            let relativeAngle: Angle = Angle(radians: Double(angleInRadians - lastAngleInRadians))
                        
            canvasAngle += relativeAngle
            
            let averageLocation: CGPoint = (pinchInteraction.0.location + pinchInteraction.1.location) / 2.0
            
            canvasOffset += rotationOffset(relativeAngle: relativeAngle, at: averageLocation)
            
        }
        
        func rotationOffset(relativeAngle: Angle, at location: CGPoint) -> CGPoint {
            
            let locationOffset: CGPoint = location - canvasOffset
            let locationOffsetRadius: CGFloat = sqrt(pow(locationOffset.x, 2.0) + pow(locationOffset.y, 2.0))
            let locationOffsetAngle: Angle = Angle(radians: Double(atan2(locationOffset.y, locationOffset.x)))
            let rotatedAverageLocactionOffsetAngle: Angle = locationOffsetAngle + relativeAngle
            let rotatedAverageLocationOffset: CGPoint = CGPoint(x: cos(CGFloat(rotatedAverageLocactionOffsetAngle.radians)) * locationOffsetRadius, y: sin(CGFloat(rotatedAverageLocactionOffsetAngle.radians)) * locationOffsetRadius)
            let relativeRotationOffset: CGPoint = locationOffset - rotatedAverageLocationOffset
            
            return relativeRotationOffset
            
        }
        
        // MARK: - Pinch Done
        
        func pinchDone(_ pinchInteraction: (CanvasInteraction, CanvasInteraction)) {
            snapToAngle(pinchInteraction)
        }
        
        func snapToAngle(_ pinchInteraction: (CanvasInteraction, CanvasInteraction)) {
            guard let snapAngle: Angle = snapAngle else { return }
            let count: Int = Int(360.0 / snapAngle.degrees)
            let angles: [Angle] = (0..<count).map { index in
                Angle(degrees: snapAngle.degrees * Double(index))
            }
            for angle in angles {
                if canvasAngle > (angle - snapAngleRadius) && canvasAngle < (angle + snapAngleRadius) {
                    let currentAngle: Angle = canvasAngle
                    let currentOffset: CGPoint = canvasOffset
                    let relativeAngle: Angle = angle - currentAngle
                    let averageLocation: CGPoint = (pinchInteraction.0.location + pinchInteraction.1.location) / 2.0
                    let offset: CGPoint = currentOffset + rotationOffset(relativeAngle: relativeAngle, at: averageLocation)
                    animate(for: 0.25, ease: .easeOut) { fraction in
                        self.canvasOffset = currentOffset * (1.0 - fraction) + offset * fraction
                        self.canvasAngle = currentAngle * Double(1.0 - fraction) + angle * Double(fraction)
                    } done: {}
                    break
                }
            }
        }
        
        // MARK: - Animation
        
        enum AnimationEase {
            case linear
            case easeIn
            case easeInOut
            case easeOut
        }
        
        func animate(for duration: CGFloat, ease: AnimationEase = .linear, loop: @escaping (CGFloat) -> (), done: @escaping () -> ()) {
            let startTime = Date()
            #if os(iOS)
            let fps: Int = UIScreen.main.maximumFramesPerSecond
            #else
            let fps: Int = 60
            #endif
            RunLoop.current.add(Timer(timeInterval: 1.0 / Double(fps), repeats: true, block: { t in
                let elapsedTime = CGFloat(-startTime.timeIntervalSinceNow)
                let fraction = min(elapsedTime / duration, 1.0)
                var easeFraction = fraction
                switch ease {
                case .linear: break
                case .easeIn: easeFraction = cos(fraction * .pi / 2 - .pi) + 1
                case .easeInOut: easeFraction = cos(fraction * .pi - .pi) / 2 + 0.5
                case .easeOut: easeFraction = cos(fraction * .pi / 2 - .pi / 2)
                }
                loop(easeFraction)
                if fraction == 1.0 {
                    done()
                    t.invalidate()
                }
            }), forMode: .common)
        }
        
    }
    
}
