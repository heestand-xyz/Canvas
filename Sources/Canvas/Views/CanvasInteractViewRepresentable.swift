import SwiftUI
import MultiViews
import CoreGraphics
import CoreGraphicsExtensions

struct CanvasInteractViewRepresentable<FrontContent: View, BackContent: View>: ViewRepresentable {

    @ObservedObject var canvas: Canvas<FrontContent, BackContent>
    
    init(canvas: Canvas<FrontContent, BackContent>) {
        self.canvas = canvas
    }

    func makeView(context: Context) -> CanvasInteractView {
        CanvasInteractView(canvasInteractions: $canvas.interactions,
                           canvasKeyboardFlags: $canvas.keyboardFlags,
                           canvasMouseLocation: $canvas.mouseLocation,
                           didMoveCanvasInteractions: context.coordinator.didMoveCanvasInteractions(_:),
                           didScroll: context.coordinator.didScroll(_:))
    }
    
    func updateView(_ view: CanvasInteractView, context: Context) {}
    
    func makeCoordinator() -> Coordinator<FrontContent, BackContent> {
        Coordinator(canvas: canvas)
    }
    
    class Coordinator<FrontContent: View, BackContent: View> {
        
        let velocityStartDampenThreshold: CGFloat = 2.5
        let velocityDampening: CGFloat = 0.98
        let velocityRadiusThreshold: CGFloat = 0.02
        let snapAngleRadius: Angle = Angle(degrees: 5)
        let isOnGridRadiusThreshold: CGFloat = 0.2

        @ObservedObject var canvas: Canvas<FrontContent, BackContent>

        #if os(iOS)
        var displayLink: CADisplayLink!
        #endif
        
        init(canvas: Canvas<FrontContent, BackContent>) {
            
            self.canvas = canvas
            
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
            
            let count: Int = canvas.interactions.count
            for index in 0..<count {
                let reverseIndex: Int = count - index - 1
                let canvasInteraction: CanvasInteraction = canvas.interactions[reverseIndex]
            
                func remove() {
                    snapToGrid()
                    canvas.interactions.remove(at: reverseIndex)
                }
                
                func snapToGrid() {
                    if let dragID: UUID = canvas.dragInteractions.first(where: { (id, dragInteraction) in
                        dragInteraction == canvasInteraction
                    })?.key {
                        if let index: Int = canvas.frameContentList.firstIndex(where: { $0.id == dragID }),
                           let snapGrid: CanvasSnapGrid = canvas.snapContentToGrid {
                            let frameContent: CanvasFrameContent = canvas.frameContentList[index]
                            let position: CGPoint = frameContent.center
                            if !isOnGrid(position: position, snapGrid: snapGrid) {
                                dragDone(id: dragID, interaction: canvasInteraction)
                            }
                        }
                    }
                }
                
                if !canvasInteraction.active {
                    if !canvasInteraction.auto {
                        guard iOS && canvasInteraction.velocityRadius > velocityStartDampenThreshold else {
                            remove()
                            continue
                        }
                        canvasInteraction.auto = true
                    }
                    guard iOS && canvasInteraction.velocityRadius > velocityRadiusThreshold else {
                        remove()
                        continue
                    }
                    #if os(iOS)
                    canvasInteraction.location += canvasInteraction.velocity
                    canvasInteraction.velocity *= velocityDampening
                    #endif
                }
                
            }
            
            /// Drag
            let filteredPotentialDragInteractions: [CanvasInteraction] = canvas.interactions.filter { interaction in
                interaction != canvas.panInteraction && interaction != canvas.pinchInteraction?.0 && interaction != canvas.pinchInteraction?.1
            }
            for (id, dragInteraction) in canvas.dragInteractions {
                #if os(iOS)
                let isInteracting: Bool = canvas.interactions.contains(dragInteraction)
                if !isInteracting {
                    canvas.dragInteractions.removeValue(forKey: id)
                }
                #elseif os(macOS)
                let isInteracting: Bool = filteredPotentialDragInteractions.contains(dragInteraction)
                if !isInteracting {
                    dragDone(id: id, interaction: dragInteraction)
                    canvas.dragInteractions.removeValue(forKey: id)
                }
                #endif
            }
            for interaction in filteredPotentialDragInteractions {
                guard let hitTestIndex: Int = hitTestFrameContentIndex(at: interaction.location) else { continue }
                let hitTestID: UUID = canvas.frameContentList[hitTestIndex].id
                guard !canvas.dragInteractions.filter({ $0.value.active }).contains(where: { $0.key == hitTestID }) else { continue }
                canvas.dragInteractions[hitTestID] = interaction
            }
              
            /// Pinch
            let filteredPotentialPinchInteractions: [CanvasInteraction] = canvas.interactions.filter { interaction in
                interaction.active && !canvas.dragInteractions.contains(where: { $0.value == interaction })
            }
            if let pinchInteraction: (CanvasInteraction, CanvasInteraction) = canvas.pinchInteraction {
                let isInteracting: Bool = filteredPotentialPinchInteractions.contains(pinchInteraction.0) && filteredPotentialPinchInteractions.contains(pinchInteraction.1)
                if !isInteracting {
                    pinchDone(pinchInteraction)
                    canvas.pinchInteraction = nil
                }
            }
            if canvas.pinchInteraction == nil {
                if filteredPotentialPinchInteractions.count >= 2 {
                    canvas.pinchInteraction = (filteredPotentialPinchInteractions[0], filteredPotentialPinchInteractions[1])
                    canvas.panInteraction = nil
                }
            }
            
            /// Pan
            let filteredPotentialPanInteractions: [CanvasInteraction] = canvas.interactions.filter { interaction in
                interaction.active && !canvas.dragInteractions.contains(where: { $0.value == interaction })
            }
            if let panInteraction: CanvasInteraction = canvas.panInteraction {
                let isInteracting: Bool = canvas.interactions.contains(panInteraction)
                if !isInteracting {
                    canvas.panInteraction = nil
                } else if !panInteraction.active {
                    if filteredPotentialPanInteractions.count == 1 {
                        canvas.panInteraction = nil
                    }
                }
            }
            if canvas.panInteraction == nil && canvas.pinchInteraction == nil {
                if filteredPotentialPanInteractions.count == 1 {
                    canvas.panInteraction = filteredPotentialPanInteractions[0]
                }
            }
            
            /// Auto Pan
            if let panInteraction: CanvasInteraction = canvas.panInteraction,
               panInteraction.auto {
                pan()
            }
            
            /// Auto Drag
            for (id, interaction) in canvas.dragInteractions {
                guard interaction.auto else { continue }
                drag(id: id, interaction: interaction)
            }
            
        }
        
        func didMoveCanvasInteractions(_ canvasInteractions: [CanvasInteraction]) {
            
            /// Pan
            if let panInteraction: CanvasInteraction = canvas.panInteraction,
               canvasInteractions.contains(panInteraction) {
                pan()
            }
            
            /// Pinch
            if let pinchInteraction: (CanvasInteraction, CanvasInteraction) = canvas.pinchInteraction,
               canvasInteractions.contains(pinchInteraction.0) && canvasInteractions.contains(pinchInteraction.1),
               pinchInteraction.0.active && pinchInteraction.1.active {
                pinch()
            }
            
            /// Drag
            for (id, interaction) in canvas.dragInteractions {
                guard interaction.active else { continue }
                guard canvasInteractions.contains(interaction) else { continue }
                drag(id: id, interaction: interaction)
            }
            
        }
        
        func didScroll(_ velocity: CGVector) {
            if canvas.keyboardFlags.contains(.option) {
                guard let mouseLocation: CGPoint = canvas.mouseLocation else { return }
                let relativeScale: CGFloat = 1.0 + velocity.dy * 0.0025
                canvas.scale *= relativeScale
                offsetCanvas(by: scaleOffset(relativeScale: relativeScale, at: mouseLocation).vector)
            } else {
                offsetCanvas(by: velocity)
            }
        }
        
        // MARK: - Drag
        
        func drag(id: UUID, interaction: CanvasInteraction) {
            
            guard let index: Int = canvas.frameContentList.firstIndex(where: { $0.id == id }) else { return }
            let frameContent: CanvasFrameContent = canvas.frameContentList[index]

            if interaction.auto,
               interaction.predictedEndLocation == nil,
               let snapGrid: CanvasSnapGrid = canvas.snapContentToGrid {

                let snapPack: (CGPoint, CGVector) = predictSnapPack(id: id, interaction: interaction, snapGrid: snapGrid)
                interaction.predictedEndLocation = snapPack.0
                interaction.velocity = snapPack.1
                
            }
            
            if interaction.contentCenterOffset == nil {
                interaction.contentCenterOffset = (canvas.coordinate.absolute(location: interaction.location) - frameContent.center).vector
            }
            
            let offset: CGVector = canvas.coordinate.scaleRotate(interaction.velocity)
            if isNaN(offset.dx) || isNaN(offset.dy) {
                fatalError("NaNaN")
            }
            canvas.frameContentList[index].frame.origin += offset
            
        }
        
        func absoluteDrag(id: UUID, interaction: CanvasInteraction) {

            guard interaction.active else { return }
            guard let contentCenterOffset: CGVector = interaction.contentCenterOffset else { return }

            guard let index: Int = canvas.frameContentList.firstIndex(where: { $0.id == id }) else { return }
            
            let center: CGPoint = canvas.coordinate.absolute(location: interaction.location) - contentCenterOffset
            if isNaN(center.x) || isNaN(center.y) {
                fatalError("NaNaN")
            }
            canvas.frameContentList[index].center = center

        }
        
        func predictSnapPack(id: UUID, interaction: CanvasInteraction, snapGrid: CanvasSnapGrid) -> (CGPoint, CGVector) {
            
            guard let index: Int = canvas.frameContentList.firstIndex(where: { $0.id == id }) else { return (.zero, .zero) }
            let frameContent: CanvasFrameContent = canvas.frameContentList[index]
            
            let position: CGPoint = frameContent.center
            let velocity: CGVector = interaction.velocity
            
            let interactionPosition: CGPoint = canvas.coordinate.absolute(location: interaction.location)
            let interactionCenterOffset: CGPoint = interactionPosition - position
            
            let predictedEndLocation: CGPoint = predictInteractionLocation(interaction: interaction)
            
            let predictedInteractionPosition: CGPoint = canvas.coordinate.absolute(location: predictedEndLocation)
            let predictedPosition: CGPoint = predictedInteractionPosition - interactionCenterOffset
            let predictedSnapPosition: CGPoint = snapToGridPosition(around: predictedPosition, snapGrid: snapGrid)
            
            let predictedDifference: CGPoint = canvas.coordinate.relative(position: predictedPosition) - canvas.coordinate.relative(position: position)
            let predictedSnapDifference: CGPoint = canvas.coordinate.relative(position: predictedSnapPosition) - canvas.coordinate.relative(position: position)
            if predictedDifference.x == 0.0 || predictedDifference.y == 0.0 {
                print("Zer0: \(predictedDifference)")
                return (CGPoint.zero, CGVector.zero)
            }
            let difference: CGPoint = predictedSnapDifference / predictedDifference
            
            let predictedSnapVelocity: CGVector = velocity * difference
            
            return (predictedEndLocation, predictedSnapVelocity)
            
        }
        
        func predictInteractionLocation(interaction: CanvasInteraction) -> CGPoint {
            var location: CGPoint = interaction.location
            var velocity: CGVector = interaction.velocity
            while sqrt(pow(velocity.dx, 2.0) + pow(velocity.dy, 2.0)) > velocityRadiusThreshold {
                location += velocity
                velocity *= velocityDampening
            }
            return location
        }
        
        func isOnGrid(position: CGPoint, snapGrid: CanvasSnapGrid) -> Bool {
            
            let snapPosition: CGPoint = snapToGridPosition(around: position, snapGrid: snapGrid)
            let difference: CGPoint = snapPosition - position
            let distance: CGFloat = sqrt(pow(difference.x, 2.0) + pow(difference.y, 2.0))
            return distance < isOnGridRadiusThreshold
            
        }
        
        func dragDone(id: UUID, interaction: CanvasInteraction) {
            snapToGrid(id: id, interaction: interaction)
        }

        func snapToGrid(id: UUID, interaction: CanvasInteraction) {

            guard let index: Int = canvas.frameContentList.firstIndex(where: { $0.id == id }) else { return }
            let frameContent: CanvasFrameContent = canvas.frameContentList[index]
            
            guard let snapGrid: CanvasSnapGrid = canvas.snapContentToGrid else { return }
            
            let position: CGPoint = frameContent.center
            let snapPosition: CGPoint = snapToGridPosition(around: position, snapGrid: snapGrid)
            
            animate(for: 0.25, ease: .easeOut) { fraction in
                
                self.canvas.frameContentList[index].center = position * (1.0 - fraction) + snapPosition * fraction
                
            } done: {}
            
        }
        
        func snapToGridPosition(around position: CGPoint, snapGrid: CanvasSnapGrid) -> CGPoint {
            
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
            
            return snapPosition
            
        }
        
        // MARK: - Pan
        
        func pan() {
            
            guard let panInteraction: CanvasInteraction = canvas.panInteraction else { return }
            
            move(panInteraction)
            
            transformed()
            
        }
        
        // MARK: - Pinch
        
        func pinch() {
            
            guard let pinchInteraction: (CanvasInteraction, CanvasInteraction) = canvas.pinchInteraction else { return }
            
            move(pinchInteraction)
            
            scale(pinchInteraction)
            
            rotate(pinchInteraction)
            
            transformed()
            
        }
        
        // MARK: - Pinch Done
        
        func pinchDone(_ pinchInteraction: (CanvasInteraction, CanvasInteraction)) {
            snapToAngle(pinchInteraction)
        }
        
        func snapToAngle(_ pinchInteraction: (CanvasInteraction, CanvasInteraction)) {
            guard let snapAngle: Angle = canvas.snapGridToAngle else { return }
            let count: Int = Int(360.0 / snapAngle.degrees)
            let angles: [Angle] = (0..<count).map { index in
                Angle(degrees: snapAngle.degrees * Double(index))
            }
            for angle in angles {
                if canvas.angle > (angle - snapAngleRadius) && canvas.angle < (angle + snapAngleRadius) {
                    let currentAngle: Angle = canvas.angle
                    let currentOffset: CGPoint = canvas.offset
                    let relativeAngle: Angle = angle - currentAngle
                    let averageLocation: CGPoint = (pinchInteraction.0.location + pinchInteraction.1.location) / 2.0
                    let offset: CGPoint = currentOffset + rotationOffset(relativeAngle: relativeAngle, at: averageLocation)
                    animate(for: 0.25, ease: .easeOut) { fraction in
                        self.canvas.offset = currentOffset * (1.0 - fraction) + offset * fraction
                        self.canvas.angle = currentAngle * Double(1.0 - fraction) + angle * Double(fraction)
                    } done: {}
                    break
                }
            }
        }
        
        // MARK: - Transform
        
        func move(_ interaction: CanvasInteraction) {
            
            offsetCanvas(by: interaction.velocity)
            
        }
        
        func move(_ interactions: (CanvasInteraction, CanvasInteraction)) {
            
            let averageVelocity: CGVector = (interactions.0.velocity + interactions.1.velocity) / 2.0
            
            offsetCanvas(by: averageVelocity)
            
        }
        
        func scale(_ pinchInteraction: (CanvasInteraction, CanvasInteraction)) {
            
            let distanceDirection: CGPoint = pinchInteraction.0.location - pinchInteraction.1.location
            let distance: CGFloat = sqrt(pow(distanceDirection.x, 2.0) + pow(distanceDirection.y, 2.0))
            let lastDistanceDirection: CGPoint = pinchInteraction.0.lastLocation - pinchInteraction.1.lastLocation
            let lastDistance: CGFloat = sqrt(pow(lastDistanceDirection.x, 2.0) + pow(lastDistanceDirection.y, 2.0))
            let relativeScale: CGFloat = distance / lastDistance
            
            if isNaN(relativeScale) {
                fatalError("NaNaN")
            }
            
            canvas.scale *= relativeScale

            let averageLocation: CGPoint = (pinchInteraction.0.location + pinchInteraction.1.location) / 2.0
            
            offsetCanvas(by: scaleOffset(relativeScale: relativeScale, at: averageLocation).vector)
            
        }
        
        func scaleOffset(relativeScale: CGFloat, at location: CGPoint) -> CGPoint {
            
            let locationOffset: CGPoint = location - canvas.offset
            let scaledAverageLocationOffset: CGPoint = locationOffset * relativeScale
            let relativeScaleOffset: CGPoint = locationOffset - scaledAverageLocationOffset
            
            return relativeScaleOffset
            
        }
        
        func rotate(_ pinchInteraction: (CanvasInteraction, CanvasInteraction)) {
            
            let distanceDirection: CGPoint = pinchInteraction.0.location - pinchInteraction.1.location
            let lastDistanceDirection: CGPoint = pinchInteraction.0.lastLocation - pinchInteraction.1.lastLocation
            let angleInRadians: CGFloat = atan2(distanceDirection.y, distanceDirection.x)
            let lastAngleInRadians: CGFloat = atan2(lastDistanceDirection.y, lastDistanceDirection.x)
            let relativeAngle: Angle = Angle(radians: Double(angleInRadians - lastAngleInRadians))
            
            if isNaN(CGFloat(relativeAngle.degrees)) {
                fatalError("NaNaN")
            }
            canvas.angle += relativeAngle
            
            let averageLocation: CGPoint = (pinchInteraction.0.location + pinchInteraction.1.location) / 2.0
            
            offsetCanvas(by: rotationOffset(relativeAngle: relativeAngle, at: averageLocation).vector)
            
        }
        
        func rotationOffset(relativeAngle: Angle, at location: CGPoint) -> CGPoint {
            
            let locationOffset: CGPoint = location - canvas.offset
            let locationOffsetRadius: CGFloat = sqrt(pow(locationOffset.x, 2.0) + pow(locationOffset.y, 2.0))
            let locationOffsetAngle: Angle = Angle(radians: Double(atan2(locationOffset.y, locationOffset.x)))
            let rotatedAverageLocactionOffsetAngle: Angle = locationOffsetAngle + relativeAngle
            let rotatedAverageLocationOffset: CGPoint = CGPoint(x: cos(CGFloat(rotatedAverageLocactionOffsetAngle.radians)) * locationOffsetRadius, y: sin(CGFloat(rotatedAverageLocactionOffsetAngle.radians)) * locationOffsetRadius)
            let relativeRotationOffset: CGPoint = locationOffset - rotatedAverageLocationOffset
            
            return relativeRotationOffset
            
        }
        
        func offsetCanvas(by offset: CGVector) {
            
            if isNaN(offset.dx) || isNaN(offset.dy) {
                fatalError("NaNaN")
            }
            
            canvas.offset += offset
            
//            for (id, interaction) in canvas.dragInteractions {
//                guard interaction.active else { continue }
//                guard let index: Int = canvas.frameContentList.firstIndex(where: { $0.id == id }) else { continue }
//                canvas.frameContentList[index].frame.origin -= canvas.coordinate.scaleRotate(offset)
//            }
            
        }
        
        func transformed() {

            for (id, interaction) in canvas.dragInteractions {
                guard interaction.active else { continue }
                absoluteDrag(id: id, interaction: interaction)
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
        
        // MARK: - Helpers
        
        func distance(from pointA: CGPoint, to pointB: CGPoint) -> CGFloat {
            sqrt(pow(pointA.x - pointB.x, 2.0) + pow(pointA.y - pointB.y, 2.0))
        }
        
        func hitTestFrameContentIndex(at location: CGPoint) -> Int? {
            let absoluteLocation: CGPoint = canvas.coordinate.absolute(location: location)
            for (index, frameContent) in canvas.frameContentList.enumerated() {
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
        
        func isNaN(_ value: CGFloat) -> Bool {
            value == .nan || "\(value)".lowercased() == "nan"
        }
        
    }
    
}
