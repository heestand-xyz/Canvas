import SwiftUI
import MultiViews
import CoreGraphics
import CoreGraphicsExtensions

struct CanvasInteractViewRepresentable<FrontContent: View, BackContent: View>: ViewRepresentable {

    let snapAngle: Angle?
    let snapGrid: CanvasSnapGrid?

    @Binding var frameContentList: [CanvasFrameContent<FrontContent, BackContent>]
    
    @Binding var canvasOffset: CGPoint
    @Binding var canvasScale: CGFloat
    @Binding var canvasAngle: Angle
    
    @Binding var canvasInteractions: [CanvasInteraction]
    @Binding var canvasPanInteraction: CanvasInteraction?
    @Binding var canvasPinchInteraction: (CanvasInteraction, CanvasInteraction)?
    @Binding var canvasDragInteractions: [UUID: CanvasInteraction]

    func makeView(context: Context) -> CanvasInteractView {
        CanvasInteractView(canvasInteractions: $canvasInteractions,
                           didMoveCanvasInteractions: context.coordinator.didMoveCanvasInteractions(_:))
    }
    
    func updateView(_ view: CanvasInteractView, context: Context) {}
    
    func makeCoordinator() -> Coordinator<FrontContent, BackContent> {
        Coordinator(snapAngle: snapAngle,
                    snapGrid: snapGrid,
                    frameContentList: $frameContentList,
                    canvasOffset: $canvasOffset,
                    canvasScale: $canvasScale,
                    canvasAngle: $canvasAngle,
                    canvasInteractions: $canvasInteractions,
                    canvasPanInteraction: $canvasPanInteraction,
                    canvasPinchInteraction: $canvasPinchInteraction,
                    canvasDragInteractions: $canvasDragInteractions)
    }
    
    class Coordinator<FrontContent: View, BackContent: View> {
        
        let velocityStartDampenThreshold: CGFloat = 2.0
        let velocityDampening: CGFloat = 0.98
        let velocityRadiusThreshold: CGFloat = 0.02
        let snapAngleRadius: Angle = Angle(degrees: 5)

        let snapAngle: Angle?
        let snapGrid: CanvasSnapGrid?
        
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
        @Binding var canvasDragInteractions: [UUID: CanvasInteraction]

        #if os(iOS)
        var displayLink: CADisplayLink!
        #endif
        
        init(snapAngle: Angle?,
             snapGrid: CanvasSnapGrid?,
             frameContentList: Binding<[CanvasFrameContent<FrontContent, BackContent>]>,
             canvasOffset: Binding<CGPoint>,
             canvasScale: Binding<CGFloat>,
             canvasAngle: Binding<Angle>,
             canvasInteractions: Binding<[CanvasInteraction]>,
             canvasPanInteraction: Binding<CanvasInteraction?>,
             canvasPinchInteraction: Binding<(CanvasInteraction, CanvasInteraction)?>,
             canvasDragInteractions: Binding<[UUID: CanvasInteraction]>) {
            
            self.snapAngle = snapAngle
            self.snapGrid = snapGrid
            _frameContentList = frameContentList
            _canvasOffset = canvasOffset
            _canvasScale = canvasScale
            _canvasAngle = canvasAngle
            _canvasInteractions = canvasInteractions
            _canvasPanInteraction = canvasPanInteraction
            _canvasPinchInteraction = canvasPinchInteraction
            _canvasDragInteractions = canvasDragInteractions
            
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
            
            /// Drag
            let filteredPotentialDragInteractions: [CanvasInteraction] = canvasInteractions.filter { interaction in
                interaction.active && interaction != canvasPanInteraction && interaction != canvasPinchInteraction?.0 && interaction != canvasPinchInteraction?.1
            }
            for (id, dragInteraction) in canvasDragInteractions {
                let isInteracting: Bool = filteredPotentialDragInteractions.contains(dragInteraction)
                if !isInteracting {
                    dragDone(id: id, interaction: dragInteraction)
                    canvasDragInteractions.removeValue(forKey: id)
                }
            }
            for interaction in filteredPotentialDragInteractions {
                guard let index: Int = hitTestFrameContentIndex(at: interaction.location) else { continue }
                let id: UUID = frameContentList[index].id
                guard !canvasDragInteractions.contains(where: { $0.key == id }) else { return }
                canvasDragInteractions[id] = interaction
            }
              
            /// Pinch
            let filteredPotentialPinchInteractions: [CanvasInteraction] = canvasInteractions.filter { interaction in
                interaction.active && !canvasDragInteractions.contains(where: { $0.value == interaction })
            }
            if let pinchInteraction: (CanvasInteraction, CanvasInteraction) = canvasPinchInteraction {
                let isInteracting: Bool = filteredPotentialPinchInteractions.contains(pinchInteraction.0) && filteredPotentialPinchInteractions.contains(pinchInteraction.1)
                if !isInteracting {
                    pinchDone(pinchInteraction)
                    canvasPinchInteraction = nil
                }
            }
            if canvasPinchInteraction == nil {
                if filteredPotentialPinchInteractions.count >= 2 {
                    canvasPinchInteraction = (filteredPotentialPinchInteractions[0], filteredPotentialPinchInteractions[1])
                    canvasPanInteraction = nil
                }
            }
            
            /// Pan
            let filteredPotentialPanInteractions: [CanvasInteraction] = canvasInteractions.filter { interaction in
                interaction.active && !canvasDragInteractions.contains(where: { $0.value == interaction })
            }
            if let panInteraction: CanvasInteraction = canvasPanInteraction {
                let isInteracting: Bool = canvasInteractions.contains(panInteraction)
                if !isInteracting {
                    canvasPanInteraction = nil
                } else if !panInteraction.active {
                    if filteredPotentialPanInteractions.count == 1 {
                        canvasPanInteraction = nil
                    }
                }
            }
            if canvasPanInteraction == nil && canvasPinchInteraction == nil {
                if filteredPotentialPanInteractions.count == 1 {
                    canvasPanInteraction = filteredPotentialPanInteractions[0]
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
            
//            /// Drag
//            for (id, interaction) in canvasDragInteractions {
//                guard interaction.auto else { continue }
//                drag(id: id, interaction: interaction)
//            }
            
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
            
            /// Drag
            for (id, interaction) in canvasDragInteractions {
                guard interaction.active else { continue }
                guard canvasInteractions.contains(interaction) else { continue }
                drag(id: id, interaction: interaction)
            }
            
        }
        
        // MARK: - Drag
        
        func drag(id: UUID, interaction: CanvasInteraction) {
            
            guard let index: Int = frameContentList.firstIndex(where: { $0.id == id }) else { return }

            frameContentList[index].frame.origin += canvasCoordinate
                .scaleRotate(CGPoint(x: interaction.velocity.dx, y: interaction.velocity.dy))
            
        }
        
        func dragDone(id: UUID, interaction: CanvasInteraction) {
            snapToGrid(id: id, interaction: interaction)
        }

        func snapToGrid(id: UUID, interaction: CanvasInteraction) {

            guard let index: Int = frameContentList.firstIndex(where: { $0.id == id }) else { return }
            let frameContent: CanvasFrameContent = frameContentList[index]

            guard let snapGrid: CanvasSnapGrid = snapGrid else { return }
            
            let position: CGPoint = frameContent.center
            let snapPosition: CGPoint
            switch snapGrid {
            case .square(size: let size):
                snapPosition = CGPoint(x: round(position.x / size) * size,
                                       y: round(position.y / size) * size)
            case .triangle(size: let size):
                let width: CGFloat = size / sqrt(0.75)
                let height: CGFloat = size
                let snapPositionA = CGPoint(x: round(position.x / width) * width,
                                            y: round(position.y / (height * 2)) * (height * 2))
                let snapPositionB = CGPoint(x: round((position.x - width / 2) / width) * width + (width / 2),
                                            y: round((position.y - height) / (height * 2)) * (height * 2) + height)
                if distance(from: snapPositionA, to: position) < distance(from: snapPositionB, to: position) {
                    snapPosition = snapPositionA
                } else {
                    snapPosition = snapPositionB
                }
            }
            
            animate(for: 0.25, ease: .easeOut) { fraction in
                
                self.frameContentList[index].center = position * (1.0 - fraction) + snapPosition * fraction
                
            } done: {}

            
        }
        
        func distance(from pointA: CGPoint, to pointB: CGPoint) -> CGFloat {
            sqrt(pow(pointA.x - pointB.x, 2.0) + pow(pointA.y - pointB.y, 2.0))
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
        
        // MARK: - Pan
        
        func pan() {
            
            guard let panInteraction: CanvasInteraction = canvasPanInteraction else { return }
            
            canvasOffset += panInteraction.velocity
            
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
