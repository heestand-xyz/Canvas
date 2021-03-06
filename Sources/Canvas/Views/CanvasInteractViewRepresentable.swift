import SwiftUI
import MultiViews
import CoreGraphics
import CoreGraphicsExtensions

struct CanvasInteractViewRepresentable: ViewRepresentable {

    @ObservedObject var canvas: Canvas
    
    init(canvas: Canvas) {
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
    
    func makeCoordinator() -> Coordinator {
        Coordinator(canvas: canvas)
    }
    
    class Coordinator {
        
        let velocityStartDampenThreshold: CGFloat = 2.5
        let velocityDampening: CGFloat = 0.98
        let velocityRadiusThreshold: CGFloat = 0.02
        let snapAngleRadius: Angle = Angle(degrees: 5)
        let isOnGridRadiusThreshold: CGFloat = 0.2

        @ObservedObject var canvas: Canvas

        #if os(iOS)
        var displayLink: CADisplayLink!
        #endif
        
        init(canvas: Canvas) {
            
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
            
            for interaction in canvas.interactions {
            
                func remove() {
                    canvas.interactions.remove(interaction)
                    endDrag()
                }
                
                func endDrag() {
                    if let dragInteraction: CanvasDragInteraction = canvas.dragInteractions.first(where: { dragInteraction in
                        dragInteraction.interaction == interaction
                    }) {
                        let position: CGPoint = canvas.coordinate.absolute(location: interaction.location)
                        canvas.delegate?.canvasDragWillEnd(dragInteraction.drag, at: position)
                        snapToGrid(dragInteraction) {
                            self.canvas.delegate?.canvasDragDidEnd(dragInteraction.drag, at: position)
                        }
                    }
                }
                
                func snapToGrid(_ dragInteraction: CanvasDragInteraction, done: @escaping () -> ()) {
                    guard let snapGrid: CanvasSnapGrid = dragInteraction.drag.snapGrid else { done(); return }
                    guard let position: CGPoint = canvas.delegate?.canvasDragGetPosition(dragInteraction.drag) else { done(); return }
                    if !isOnGrid(position: position, snapGrid: snapGrid) {
                        dragDone(dragInteraction: dragInteraction, done: done)
                    }
                }
                
                if !interaction.active {
                    
                    if !interaction.auto {
                        var dragPhysics: Bool?
                        if let dragInteraction: CanvasDragInteraction = canvas.dragInteractions.first(where: { dragInteraction in
                            dragInteraction.interaction == interaction
                        }) {
                            dragPhysics = dragInteraction.drag.physics
                            let position: CGPoint = canvas.coordinate.absolute(location: interaction.location)
                            canvas.delegate?.canvasDragReleased(dragInteraction.drag, at: position)
                        }
                        guard canvas.physics && dragPhysics != false else {
                            remove()
                            continue
                        }
                        guard interaction.velocityRadius > velocityStartDampenThreshold else {
                            remove()
                            continue
                        }
                        interaction.auto = true
                    }
                    
                    guard iOS && interaction.velocityRadius > velocityRadiusThreshold else {
                        remove()
                        continue
                    }
                    #if os(iOS)
                    interaction.location += interaction.velocity
                    interaction.velocity *= velocityDampening
                    #endif
                    
                }
                
            }
            
            /// Drag
            let filteredPotentialDragInteractions: [CanvasInteraction] = canvas.interactions.filter { interaction in
                interaction != canvas.panInteraction && interaction != canvas.pinchInteraction?.0 && interaction != canvas.pinchInteraction?.1
            }
            for dragInteraction in canvas.dragInteractions {
                #if os(iOS)
                let isInteracting: Bool = canvas.interactions.contains(dragInteraction.interaction)
                if !isInteracting {
                    canvas.dragInteractions.remove(dragInteraction)
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
                let interactionPosition: CGPoint = canvas.coordinate.absolute(location: interaction.location)
                guard let drag: CanvasDrag = canvas.delegate?.canvasDragHitTest(at: interactionPosition) else { continue }
                guard !canvas.dragInteractions.filter({ $0.interaction.active }).contains(where: { $0.drag.id == drag.id }) else { continue }
                let dragInteraction = CanvasDragInteraction(drag: drag, interaction: interaction)
                canvas.dragInteractions.insert(dragInteraction)
                let position: CGPoint = canvas.coordinate.absolute(location: interaction.location)
                canvas.delegate?.canvasDragStarted(drag, at: position)
            }
              
            /// Pinch
            let filteredPotentialPinchInteractions: [CanvasInteraction] = canvas.interactions.filter { interaction in
                interaction.active && !canvas.dragInteractions.contains(where: { $0.interaction == interaction })
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
                interaction.active && !canvas.dragInteractions.contains(where: { $0.interaction == interaction })
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
            for dragInteraction in canvas.dragInteractions {
                guard dragInteraction.interaction.auto else { continue }
                drag(dragInteraction: dragInteraction)
            }
            
        }
        
        func didMoveCanvasInteractions(_ interactions: Set<CanvasInteraction>) {
            
            /// Pan
            if let panInteraction: CanvasInteraction = canvas.panInteraction,
               interactions.contains(panInteraction) {
                pan()
            }
            
            /// Pinch
            if let pinchInteraction: (CanvasInteraction, CanvasInteraction) = canvas.pinchInteraction,
               interactions.contains(pinchInteraction.0) && interactions.contains(pinchInteraction.1),
               pinchInteraction.0.active && pinchInteraction.1.active {
                pinch()
            }
            
            /// Drag
            for dragInteraction in canvas.dragInteractions {
                guard dragInteraction.interaction.active else { continue }
                guard interactions.contains(dragInteraction.interaction) else { continue }
                drag(dragInteraction: dragInteraction)
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
        
        func drag(dragInteraction: CanvasDragInteraction) {
            
            let interaction: CanvasInteraction = dragInteraction.interaction
            
            if interaction.auto,
               interaction.predictedEndLocation == nil,
               dragInteraction.drag.physics,
               dragInteraction.drag.snapGrid != nil {

                let snapPack: (CGPoint, CGVector) = predictSnapPack(dragInteraction: dragInteraction)
                interaction.predictedEndLocation = snapPack.0
                interaction.velocity = snapPack.1
                
            }
            
            guard let position: CGPoint = canvas.delegate?.canvasDragGetPosition(dragInteraction.drag) else { return }
            
            if interaction.contentCenterOffset == nil {
                interaction.contentCenterOffset = (canvas.coordinate.absolute(location: interaction.location) - position).vector
            }
            
            let offset: CGVector = canvas.coordinate.scaleRotate(interaction.velocity)
            if isNaN(offset.dx) || isNaN(offset.dy) {
                fatalError("NaNaN")
            }
            
            canvas.delegate?.canvasDragSetPosition(dragInteraction.drag, to: position + offset)
            
        }
        
        func absoluteDrag(dragInteraction: CanvasDragInteraction) {
            
            let interaction: CanvasInteraction = dragInteraction.interaction

            guard interaction.active else { return }
            guard let contentCenterOffset: CGVector = interaction.contentCenterOffset else { return }
                        
            let center: CGPoint = canvas.coordinate.absolute(location: interaction.location) - contentCenterOffset
            if isNaN(center.x) || isNaN(center.y) {
                fatalError("NaNaN")
            }
            
            canvas.delegate?.canvasDragSetPosition(dragInteraction.drag, to: center)

        }
        
        func predictSnapPack(dragInteraction: CanvasDragInteraction) -> (CGPoint, CGVector) {
            
            guard let snapGrid: CanvasSnapGrid = dragInteraction.drag.snapGrid else { return (.zero, .zero) }
            
            let interaction: CanvasInteraction = dragInteraction.interaction
            
            guard let position: CGPoint = canvas.delegate?.canvasDragGetPosition(dragInteraction.drag) else { return (.zero, .zero) }
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
        
        func dragDone(dragInteraction: CanvasDragInteraction, done: @escaping () -> ()) {
            
            snapToGrid(dragInteraction: dragInteraction, done: done)
            
        }

        func snapToGrid(dragInteraction: CanvasDragInteraction, done: @escaping () -> ()) {
            
            guard let snapGrid: CanvasSnapGrid = dragInteraction.drag.snapGrid else { return }
            
            guard let position: CGPoint = canvas.delegate?.canvasDragGetPosition(dragInteraction.drag) else { return }
            let snapPosition: CGPoint = snapToGridPosition(around: position, snapGrid: snapGrid)
            
            Animation.animate(for: 0.25, ease: .easeOut) { fraction in
                
                let animatedPosition: CGPoint = position * (1.0 - fraction) + snapPosition * fraction
                self.canvas.delegate?.canvasDragSetPosition(dragInteraction.drag, to: animatedPosition)
                
            } done: {
                done()
            }
            
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
                if CanvasCoordinate.distance(from: snapPositionA, to: position) < CanvasCoordinate.distance(from: snapPositionB, to: position) {
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
                    Animation.animate(for: 0.25, ease: .easeOut) { fraction in
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

            for dragInteraction in canvas.dragInteractions {
                guard dragInteraction.interaction.active else { continue }
                absoluteDrag(dragInteraction: dragInteraction)
            }
            
        }
        
        // MARK: - Helpers
        
        func isNaN(_ value: CGFloat) -> Bool {
            value == .nan || "\(value)".lowercased() == "nan"
        }
        
    }
    
}
