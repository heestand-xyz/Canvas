import SwiftUI
import MultiViews
import CoreGraphics
import CoreGraphicsExtensions
import DisplayLink

struct CCanvasInteractViewRepresentable<Content: View>: ViewRepresentable {

    @ObservedObject var canvas: CCanvas
    let content: () -> Content
    
    init(canvas: CCanvas, content: @escaping () -> Content = { EmptyView() }) {
        self.canvas = canvas
        self.content = content
    }

    func makeView(context: Context) -> CCanvasInteractView {
        let contentView: MPView = MPHostingController(rootView: content()).view
#if !os(macOS)
        contentView.backgroundColor = .clear
#endif
        return CCanvasInteractView(
            canvas: canvas,
            contentView: contentView,
            didMoveInteractions: context.coordinator.didMoveInteractions(_:),
            didStartScroll: context.coordinator.didStartScroll,
            didScroll: context.coordinator.didScroll(_:withScrollWheel:),
            didEndScroll: context.coordinator.didEndScroll,
            didStartMagnify: context.coordinator.didStartMagnify,
            didMagnify: context.coordinator.didMagnify(_:),
            didEndMagnify: context.coordinator.didEndMagnify,
            didStartRotate: context.coordinator.didStartRotate,
            didRotate: context.coordinator.didRotate(_:),
            didEndRotate: context.coordinator.didEndRotate,
            didStartInteract: context.coordinator.didStartInteract,
            didInteract: context.coordinator.didInteract,
            didEndInteract: context.coordinator.didEndInteract
        )
    }
    
    func updateView(_ canvasInteractView: CCanvasInteractView, context: Context) {
        
        if context.coordinator.canvas != canvas {
            context.coordinator.canvas = canvas
            
            canvasInteractView.canvas = canvas

            canvasInteractView.didMoveInteractions = context.coordinator.didMoveInteractions(_:)
            
            canvasInteractView.didStartScroll = context.coordinator.didStartScroll
            canvasInteractView.didScroll = context.coordinator.didScroll(_:withScrollWheel:)
            canvasInteractView.didEndScroll = context.coordinator.didEndScroll
            
            canvasInteractView.didStartMagnify = context.coordinator.didStartMagnify
            canvasInteractView.didMagnify = context.coordinator.didMagnify(_:)
            canvasInteractView.didEndMagnify = context.coordinator.didEndMagnify
            
            canvasInteractView.didStartRotate = context.coordinator.didStartRotate
            canvasInteractView.didRotate = context.coordinator.didRotate(_:)
            canvasInteractView.didEndRotate = context.coordinator.didEndRotate
            
            canvasInteractView.didEndInteract = context.coordinator.didEndInteract
        }
        
//        if !context.coordinator.canvas.isTimeBased {
//            context.coordinator.main()
//        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(canvas: canvas)
    }
    
    class Coordinator {
        
        let velocityStartDampenThreshold: CGFloat = 2.5
        let velocityRadiusThreshold: CGFloat = 0.02
        let snapAngleThreshold: Angle = Angle(degrees: 5)
        let isOnGridRadiusThreshold: CGFloat = 0.2
        let initialRotationThreshold: Angle = Angle(degrees: 10)
        let zoomScrollVelocityMultiplier: CGFloat = 0.0075
        let middleMouseDragVelocityMultiplier: CGFloat = 0.01

        @ObservedObject var canvas: CCanvas

        let displayLink: DisplayLink?
        
        init(canvas: CCanvas) {
            
            self.canvas = canvas
            
            
            if canvas.isTimeBased {
                displayLink = DisplayLink()
                displayLink!.listen(frameLoop: frameLoop)
            } else {
                displayLink = nil
            }
        }
        
        deinit {
            displayLink?.stop()
        }
        
//        var frameLoopIndex: Int = 0
        
        func frameLoop() {
            DispatchQueue.main.async {
                self.main()
            }
        }
        
        func didStartInteract() {
            if !canvas.isTimeBased {
                main()
            }
        }
        
        func didInteract() {
            if !canvas.isTimeBased {
                main()
            }
        }
        
        func didEndInteract() {
            if !canvas.isTimeBased {
                main()
            }
        }
        
        func main() {
            
//            frameLoopIndex += 1
//
//            #if DEBUG
//            guard frameLoopIndex % 30 == 0 else { return }
//            #endif
            
            func potentialTap(of interaction: CCanvasInteraction) {
                guard canvas.maximumTapCount > 0 else { return }
                func clearTimer() {
                    canvas.tapTimer?.invalidate()
                    canvas.tapTimer = nil
                }
                clearTimer()
                func clean() {
                    canvas.tapCount = nil
                    canvas.tapKeyboardFlags = nil
                    clearTimer()
                }
                guard interaction.duration < canvas.tapDuration else {
                    clean()
                    return
                }
                guard interaction.distance < canvas.tapDistance else {
                    clean()
                    return
                }
                func tap(count: Int) {
                    guard let tapKeyboardFlags: Set<CCanvasKeyboardFlag> = canvas.tapKeyboardFlags else {
                        clean()
                        return
                    }
                    let position: CGPoint = canvas.coordinate.position(at: interaction.location)
#if os(macOS)
                    canvas.delegate?.canvasClick(count: count, at: position, with: interaction.info.mouseButton, keyboardFlags: tapKeyboardFlags, coordinate: canvas.coordinate)
#else
                    canvas.delegate?.canvasTap(count: count, at: position, coordinate: canvas.coordinate)
#endif
                    clean()
                }
                func wait(count: Int) {
                    canvas.tapCount = count
                    canvas.tapTimer = .scheduledTimer(withTimeInterval: canvas.betweenTapDuration, repeats: false) { _ in
                        tap(count: count)
                    }
                }
                if let tapCount = canvas.tapCount {
                    let newTapCount = tapCount + 1
                    if newTapCount == canvas.maximumTapCount {
                        tap(count: newTapCount)
                    } else {
                        wait(count: newTapCount)
                    }
                } else {
                    canvas.tapKeyboardFlags = canvas.keyboardFlags
                    if canvas.maximumTapCount > 1 {
                        wait(count: 1)
                    } else {
                        tap(count: 1)
                    }
                }
            }
            
            func endDrag(of interaction: CCanvasInteraction) {
                if let dragInteraction: CCanvasDragInteraction = canvas.dragInteractions.first(where: { dragInteraction in
                    dragInteraction.interaction == interaction
                }) {
                    let position: CGPoint = canvas.coordinate.position(at: interaction.location)
                    canvas.delegate?.canvasDragWillEnd(dragInteraction.drag, at: position, coordinate: canvas.coordinate)
                    snapToGrid(dragInteraction) { [weak self] in
                        guard let coordinate: CCanvasCoordinate = self?.canvas.coordinate else { return }
                        self?.canvas.delegate?.canvasDragDidEnd(dragInteraction.drag, at: position, coordinate: coordinate)
                    }
                }
            }
            
            func snapToGrid(_ dragInteraction: CCanvasDragInteraction, done: @escaping () -> ()) {
                guard let snapGrid: CCanvasSnapGrid = dragInteraction.drag.snapGrid else { done(); return }
                guard let position: CGPoint = canvas.delegate?.canvasDragGetPosition(dragInteraction.drag, coordinate: canvas.coordinate) else { done(); return }
                if !isOnGrid(position: position, snapGrid: snapGrid) {
                    dragDone(dragInteraction: dragInteraction, done: done)
                } else { done() }
            }
            
            func startMove(with interaction: CCanvasInteraction) {
                let interactionPosition: CGPoint = canvas.coordinate.position(at: interaction.location)
#if os(iOS) || os(visionOS)
                canvas.delegate?.canvasMoveStarted(at: interactionPosition, viaScroll: false, info: interaction.info, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
#elseif os(macOS)
                if interaction.info.mouseButton == .left {
                    canvas.delegate?.canvasSelectionStarted(at: interactionPosition, info: interaction.info, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
                } else if [.right, .middle].contains(interaction.info.mouseButton) {
                    canvas.delegate?.canvasMoveStarted(at: interactionPosition, viaScroll: false, info: interaction.info, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
                }
#endif
            }
            
            for interaction in canvas.interactions {
                
                func remove() {
                    DispatchQueue.main.async {
                        self.canvas.interactions.remove(interaction)
                        endDrag(of: interaction)
                    }
                }
                
                if !interaction.active || interaction.timeout {
                    
                    if !interaction.auto || interaction.timeout {
                        if interaction.timeout {
                            print("Canvas Interaction Timeout")
                        }
                        var dragPhysics: CCanvasDrag.Physics?
                        if let dragInteraction: CCanvasDragInteraction = canvas.dragInteractions.first(where: { dragInteraction in
                            dragInteraction.interaction == interaction
                        }) {
                            dragPhysics = dragInteraction.drag.physics
                            let position: CGPoint = canvas.coordinate.position(at: interaction.location)
                            canvas.delegate?.canvasDragReleased(dragInteraction.drag, at: position, ignoreTap: false, info: interaction.info, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
                        }
                        guard canvas.physics && dragPhysics?.hasForce != false else {
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
                    
                    #if !os(macOS)
                    
                    interaction.location += interaction.velocity
                    
                    let velocityDampening: CGFloat = interaction.velocityDampening ?? CCanvasDrag.Physics.Force.standard.velocityDampening
                    interaction.velocity *= velocityDampening
                    
                    #endif
                    
                }
                
            }
            
            // MARK: Drag
            
            let filteredPotentialDragInteractions: [CCanvasInteraction] = canvas.interactions.filter { interaction in
                interaction.active && !canvas.dragInteractions.map(\.interaction).contains(interaction) && interaction != canvas.panInteraction && interaction != canvas.pinchInteraction?.0 && interaction != canvas.pinchInteraction?.1
            }
            /// End
            for dragInteraction in canvas.dragInteractions {
                let isInteracting: Bool = canvas.interactions.contains(dragInteraction.interaction)
                if !isInteracting {
                    canvas.dragInteractions.remove(dragInteraction)
                }
            }
            /// Start
            for interaction in filteredPotentialDragInteractions {
                #if os(macOS)
                guard interaction.info.mouseButton == .left else { continue }
                #endif
                let interactionPosition: CGPoint = canvas.coordinate.position(at: interaction.location)
                guard let drag: CCanvasDrag = canvas.delegate?.canvasDragHitTest(at: interactionPosition, coordinate: canvas.coordinate) else { continue }
                guard !canvas.dragInteractions.filter({ $0.interaction.active }).contains(where: { $0.drag.id == drag.id }) else { continue }
                let dragInteraction = CCanvasDragInteraction(drag: drag, interaction: interaction)
                canvas.dragInteractions.insert(dragInteraction)
                let position: CGPoint = canvas.coordinate.position(at: interaction.location)
                canvas.delegate?.canvasDragStarted(drag, at: position, info: interaction.info, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
            }
            
            // MARK: Pinch
            
            let filteredPotentialPinchInteractions: [CCanvasInteraction] = canvas.interactions.filter { interaction in
                interaction.active
            }
            /// End
            if let pinchInteraction: (CCanvasInteraction, CCanvasInteraction) = canvas.pinchInteraction {
                let isInteracting: Bool = filteredPotentialPinchInteractions.contains(pinchInteraction.0) && filteredPotentialPinchInteractions.contains(pinchInteraction.1)
                if !isInteracting {
                    pinchDone(pinchInteraction)
                    let interactionPosition0: CGPoint = canvas.coordinate.position(at: pinchInteraction.0.location)
                    let interactionPosition1: CGPoint = canvas.coordinate.position(at: pinchInteraction.0.location)
                    let interactionPosition: CGPoint = (interactionPosition0 + interactionPosition1) / 2
                    #if !os(macOS)
                    canvas.delegate?.canvasMoveEnded(at: interactionPosition, viaScroll: false, info: pinchInteraction.0.info, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
                    #endif
                    canvas.pinchInteraction = nil
                }
            }
            /// Start
            if canvas.pinchInteraction == nil {
                if filteredPotentialPinchInteractions.count >= 2 {
                    
                    /// End Drag
                    if let firstDragInteraciton = canvas.dragInteractions.first(where: { $0.interaction == filteredPotentialPinchInteractions[0] }) {
                        let position: CGPoint = canvas.coordinate.position(at: firstDragInteraciton.interaction.location)
                        canvas.delegate?.canvasDragReleased(firstDragInteraciton.drag, at: position, ignoreTap: true, info: firstDragInteraciton.interaction.info, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
                        endDrag(of: firstDragInteraciton.interaction)
                        canvas.dragInteractions.remove(firstDragInteraciton)
                    }
                    if let secondDragInteraction = canvas.dragInteractions.first(where: { $0.interaction == filteredPotentialPinchInteractions[1] }) {
                        let position: CGPoint = canvas.coordinate.position(at: secondDragInteraction.interaction.location)
                        canvas.delegate?.canvasDragReleased(secondDragInteraction.drag, at: position, ignoreTap: true, info: secondDragInteraction.interaction.info, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
                        endDrag(of: secondDragInteraction.interaction)
                        canvas.dragInteractions.remove(secondDragInteraction)
                    }
                    
                    /// Start Pinch
                    canvas.pinchInteraction = (filteredPotentialPinchInteractions[0], filteredPotentialPinchInteractions[1])
                    
                    if canvas.panInteraction == nil {
                        startMove(with: canvas.pinchInteraction!.0)
                    }
                    
                    /// End Pan
                    canvas.panInteraction = nil
                }
            }
            
            // MARK: Pan
            
            let filteredPotentialPanInteractions: [CCanvasInteraction] = canvas.interactions.filter { interaction in
                interaction.active && !canvas.dragInteractions.contains(where: { $0.interaction == interaction })
            }
            /// End
            if let panInteraction: CCanvasInteraction = canvas.panInteraction {
                let isInteracting: Bool = canvas.interactions.contains(panInteraction)
                let interactionPosition: CGPoint = canvas.coordinate.position(at: panInteraction.location)
                if !isInteracting {
                    #if !os(macOS)
                    canvas.delegate?.canvasMoveEnded(at: interactionPosition, viaScroll: false, info: panInteraction.info, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
                    #else
                    if panInteraction.info.mouseButton == .left {
                        canvas.delegate?.canvasSelectionEnded(at: interactionPosition, info: panInteraction.info, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
                    } else if [.right, .middle].contains(panInteraction.info.mouseButton) {
                        canvas.delegate?.canvasMoveEnded(at: interactionPosition, viaScroll: false, info: panInteraction.info, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
                    }
                    #endif
                    canvas.panInteraction = nil
                    potentialTap(of: panInteraction)
                } else if !panInteraction.active {
                    if filteredPotentialPanInteractions.count == 1 {
                        #if !os(macOS)
                        canvas.delegate?.canvasMoveEnded(at: interactionPosition, viaScroll: false, info: panInteraction.info, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
                        #else
                        if panInteraction.info.mouseButton == .left {
                            canvas.delegate?.canvasSelectionEnded(at: interactionPosition, info: panInteraction.info, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
                        } else if [.right, .middle].contains(panInteraction.info.mouseButton) {
                            canvas.delegate?.canvasMoveEnded(at: interactionPosition, viaScroll: false, info: panInteraction.info, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
                        }
                        #endif
                        canvas.panInteraction = nil
                        potentialTap(of: panInteraction)
                    }
                }
            }
            /// Start
            if canvas.panInteraction == nil && canvas.pinchInteraction == nil {
                if filteredPotentialPanInteractions.count == 1 {
                    canvas.panInteraction = filteredPotentialPanInteractions[0]
                    startMove(with: canvas.panInteraction!)
                }
            }
            
            // MARK: Auto
            
            /// Pan
            if let panInteraction: CCanvasInteraction = canvas.panInteraction,
               panInteraction.auto {
                pan()
            }
            
            /// Drag
            for dragInteraction in canvas.dragInteractions {
                guard dragInteraction.interaction.auto else { continue }
                drag(dragInteraction: dragInteraction)
            }
            
        }
        
        func didMoveInteractions(_ interactions: Set<CCanvasInteraction>) {
            
            /// Pan
            if let panInteraction: CCanvasInteraction = canvas.panInteraction,
               interactions.contains(panInteraction) {
                pan()
            }
            
            /// Pinch
            if let pinchInteraction: (CCanvasInteraction, CCanvasInteraction) = canvas.pinchInteraction,
               interactions.contains(pinchInteraction.0) || interactions.contains(pinchInteraction.1),
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
        
        // MARK: - Scroll
        
        func didStartScroll() {
            guard let mouseLocation: CGPoint = canvas.mouseLocation else { return }
            let interactionPosition: CGPoint = canvas.coordinate.position(at: mouseLocation)
            canvas.delegate?.canvasMoveStarted(at: interactionPosition, viaScroll: true, info: nil, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
        }
        
        func didScroll(_ velocity: CGVector, withScrollWheel: Bool) {
            guard let mouseLocation: CGPoint = canvas.mouseLocation else { return }
            if canvas.keyboardFlags.contains(.command) || withScrollWheel {
                let relativeScale: CGFloat = 1.0 + velocity.dy * zoomScrollVelocityMultiplier
                scaleCanvas(by: relativeScale, at: mouseLocation)
            } else if canvas.keyboardFlags.contains(.option) {
                guard canvas.rotationEnabled else { return }
                let relativeAngle: Angle = Angle(degrees: Double(velocity.dy) * 0.5)
                rotateCanvas(by: relativeAngle, at: mouseLocation)
            } else {
                offsetCanvas(by: velocity)
            }
            let interactionPosition: CGPoint = canvas.coordinate.position(at: mouseLocation)
            canvas.delegate?.canvasMoveUpdated(at: interactionPosition, viaScroll: true, info: nil, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
        }
        
        func didEndScroll() {
            guard let mouseLocation: CGPoint = canvas.mouseLocation else { return }
            if canvas.keyboardFlags.contains(.option) {
                snapToAngle(at: mouseLocation)
            }
            let interactionPosition: CGPoint = canvas.coordinate.position(at: mouseLocation)
            canvas.delegate?.canvasMoveEnded(at: interactionPosition, viaScroll: true, info: nil, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
        }
        
        // MARK: - Magnify
        
        func didStartMagnify() {
            guard let mouseLocation: CGPoint = canvas.mouseLocation else { return }
            let interactionPosition: CGPoint = canvas.coordinate.position(at: mouseLocation)
            canvas.delegate?.canvasMoveStarted(at: interactionPosition, viaScroll: true, info: nil, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
        }
        
        func didMagnify(_ velocity: CGFloat) {
            guard let mouseLocation: CGPoint = canvas.mouseLocation else { return }
            let relativeScale: CGFloat = 1.0 + velocity
            scaleCanvas(by: relativeScale, at: mouseLocation)
            let interactionPosition: CGPoint = canvas.coordinate.position(at: mouseLocation)
            canvas.delegate?.canvasMoveUpdated(at: interactionPosition, viaScroll: true, info: nil, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
        }
        
        func didEndMagnify() {
            guard let mouseLocation: CGPoint = canvas.mouseLocation else { return }
            let interactionPosition: CGPoint = canvas.coordinate.position(at: mouseLocation)
            canvas.delegate?.canvasMoveEnded(at: interactionPosition, viaScroll: true, info: nil, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
        }
        
        // MARK: - Rotate
        
        func didStartRotate() {
            guard let mouseLocation: CGPoint = canvas.mouseLocation else { return }
            let interactionPosition: CGPoint = canvas.coordinate.position(at: mouseLocation)
            canvas.delegate?.canvasMoveStarted(at: interactionPosition, viaScroll: true, info: nil, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
        }
        
        func didRotate(_ velocity: CGFloat) {
            guard let mouseLocation: CGPoint = canvas.mouseLocation else { return }
            let relativeAngle: Angle = Angle(degrees: Double(velocity * -1))
            rotateCanvas(by: relativeAngle, at: mouseLocation)
            let interactionPosition: CGPoint = canvas.coordinate.position(at: mouseLocation)
            canvas.delegate?.canvasMoveUpdated(at: interactionPosition, viaScroll: true, info: nil, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
        }
        
        func didEndRotate() {
            guard let mouseLocation: CGPoint = canvas.mouseLocation else { return }
            snapToAngle(at: mouseLocation)
            let interactionPosition: CGPoint = canvas.coordinate.position(at: mouseLocation)
            canvas.delegate?.canvasMoveEnded(at: interactionPosition, viaScroll: true, info: nil, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
        }
        
        // MARK: - Drag
        
        func drag(dragInteraction: CCanvasDragInteraction) {
            
            let interaction: CCanvasInteraction = dragInteraction.interaction
            
            if interaction.auto,
               interaction.predictedEndLocation == nil,
               dragInteraction.drag.physics.hasForce,
               dragInteraction.drag.snapGrid != nil {

                let snapPack: (CGPoint, CGVector) = predictSnapPack(dragInteraction: dragInteraction)
                interaction.predictedEndLocation = snapPack.0
                interaction.velocity = snapPack.1
            }
            
            guard let position: CGPoint = canvas.delegate?.canvasDragGetPosition(dragInteraction.drag, coordinate: canvas.coordinate) else { return }
            
            if interaction.contentCenterOffset == nil {
                interaction.contentCenterOffset = (canvas.coordinate.position(at: interaction.location) - position).asVector
            }
            
            let offset: CGVector = canvas.coordinate.scaleRotate(interaction.velocity)
            if isNaN(offset.dx) || isNaN(offset.dy) {
                print("Canvas Drag by NaN")
                return
            }
            
            canvas.delegate?.canvasDragSetPosition(dragInteraction.drag, to: position + offset, coordinate: canvas.coordinate)
            
        }
        
        func absoluteDrag(dragInteraction: CCanvasDragInteraction) {
            
            let interaction: CCanvasInteraction = dragInteraction.interaction

            guard interaction.active else { return }
            guard let contentCenterOffset: CGVector = interaction.contentCenterOffset else { return }
                        
            let center: CGPoint = canvas.coordinate.position(at: interaction.location) - contentCenterOffset
            if isNaN(center.x) || isNaN(center.y) {
                print("Canvas Abolute Drag by NaN")
                return
            }
            
            canvas.delegate?.canvasDragSetPosition(dragInteraction.drag, to: center, coordinate: canvas.coordinate)

        }
        
        func predictSnapPack(dragInteraction: CCanvasDragInteraction) -> (CGPoint, CGVector) {
            
            guard let snapGrid: CCanvasSnapGrid = dragInteraction.drag.snapGrid else { return (.zero, .zero) }
            
            let interaction: CCanvasInteraction = dragInteraction.interaction
            
            guard let position: CGPoint = canvas.delegate?.canvasDragGetPosition(dragInteraction.drag, coordinate: canvas.coordinate) else { return (.zero, .zero) }
            let velocity: CGVector = interaction.velocity
            
            let interactionPosition: CGPoint = canvas.coordinate.position(at: interaction.location)
            let interactionCenterOffset: CGPoint = interactionPosition - position
            
            let predictedEndLocation: CGPoint = predictInteractionLocation(interaction: interaction)
            
            let predictedInteractionPosition: CGPoint = canvas.coordinate.position(at: predictedEndLocation)
            let predictedPosition: CGPoint = predictedInteractionPosition - interactionCenterOffset
            let predictedSnapPosition: CGPoint = CCanvas.snapToGrid(position: predictedPosition, snapGrid: snapGrid)
            
            let predictedDifference: CGPoint = canvas.coordinate.location(at: predictedPosition) - canvas.coordinate.location(at: position)
            let predictedSnapDifference: CGPoint = canvas.coordinate.location(at: predictedSnapPosition) - canvas.coordinate.location(at: position)
            if predictedDifference.x == 0.0 || predictedDifference.y == 0.0 {
                print("Zer0: \(predictedDifference)")
                return (CGPoint.zero, CGVector.zero)
            }
            let difference: CGPoint = predictedSnapDifference / predictedDifference
            
            let predictedSnapVelocity: CGVector = velocity * difference
            
            return (predictedEndLocation, predictedSnapVelocity)
            
        }
        
        func predictInteractionLocation(interaction: CCanvasInteraction) -> CGPoint {
            var location: CGPoint = interaction.location
            var velocity: CGVector = interaction.velocity
            let velocityDampening: CGFloat = interaction.velocityDampening ?? CCanvasDrag.Physics.Force.standard.velocityDampening
            while sqrt(pow(velocity.dx, 2.0) + pow(velocity.dy, 2.0)) > velocityRadiusThreshold {
                location += velocity
                velocity *= velocityDampening
            }
            return location
        }
        
        func isOnGrid(position: CGPoint, snapGrid: CCanvasSnapGrid) -> Bool {
            
            let snapPosition: CGPoint = CCanvas.snapToGrid(position: position, snapGrid: snapGrid)
            let difference: CGPoint = snapPosition - position
            let distance: CGFloat = sqrt(pow(difference.x, 2.0) + pow(difference.y, 2.0))
            return distance < isOnGridRadiusThreshold
            
        }
        
        func dragDone(dragInteraction: CCanvasDragInteraction, done: @escaping () -> ()) {
            
            snapToGrid(dragInteraction: dragInteraction, done: done)
            
        }

        func snapToGrid(dragInteraction: CCanvasDragInteraction, done: @escaping () -> ()) {
            
            guard let snapGrid: CCanvasSnapGrid = dragInteraction.drag.snapGrid else { return }
            
            guard let position: CGPoint = canvas.delegate?.canvasDragGetPosition(dragInteraction.drag, coordinate: canvas.coordinate) else { return }
            let snapPosition: CGPoint = CCanvas.snapToGrid(position: position, snapGrid: snapGrid)
            
            CCanvasAnimation.animate(duration: 0.25, ease: .easeOut) { [weak self] fraction in
                
                guard let coordinate: CCanvasCoordinate = self?.canvas.coordinate else { return }
                let animatedPosition: CGPoint = position * (1.0 - fraction) + snapPosition * fraction
                self?.canvas.delegate?.canvasDragSetPosition(dragInteraction.drag, to: animatedPosition, coordinate: coordinate)
                
            } done: {
                done()
            }
            
        }
        
        // MARK: - Pan
        
        func pan() {
            
            guard let panInteraction: CCanvasInteraction = canvas.panInteraction else { return }
            
            let interactionPosition: CGPoint = canvas.coordinate.position(at: panInteraction.location)

            #if !os(macOS)
            
            move(panInteraction)
            transformed()
            
            #else
            
            if panInteraction.info.mouseButton == .left {
                canvas.delegate?.canvasSelectionChanged(to: interactionPosition, coordinate: canvas.coordinate)
            } else if panInteraction.info.mouseButton == .right {
                move(panInteraction)
                transformed()
            } else if panInteraction.info.mouseButton == .middle {
                scale(panInteraction)
                transformed()
            }
            
            #endif
            
            canvas.delegate?.canvasMoveUpdated(at: interactionPosition, viaScroll: false, info: panInteraction.info, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
            
        }
        
        // MARK: - Pinch
        
        func pinch() {
            
            guard let pinchInteraction: (CCanvasInteraction, CCanvasInteraction) = canvas.pinchInteraction else { return }
            
            if !canvas.magnifyInPlace {
                
                move(pinchInteraction)
            }
                
            scale(pinchInteraction)
            
            if !canvas.magnifyInPlace {
                
                if canvas.rotationEnabled {
                    
                    if pinchInteraction.0.initialRotationThresholdReached || {
                        let relativeAngle: Angle = relativeRotation(pinchInteraction)
                        let initialRotation: Angle = pinchInteraction.0.initialRotation + relativeAngle
                        pinchInteraction.0.initialRotation = initialRotation
                        if abs(initialRotation.degrees) > initialRotationThreshold.degrees {
                            pinchInteraction.0.initialRotationThresholdReached = true
                            CCanvasAnimation.animateRelative(duration: 0.25, ease: .easeInOut) { [weak self] fraction, relativeFraction in
                                self?.rotate(relativeAngle: Angle(degrees: initialRotation.degrees * Double(relativeFraction)), pinchInteraction)
                            }
                            return true
                        }
                        return false
                    }() {
                        rotate(pinchInteraction)
                    }
                }
                
                transformed()
            }
            
            let interactionPosition: CGPoint
            if canvas.magnifyInPlace {
                interactionPosition = canvas.coordinate.position(at: (pinchInteraction.0.startLocation + pinchInteraction.1.startLocation) / 2)
            } else {
                interactionPosition = canvas.coordinate.position(at: (pinchInteraction.0.location + pinchInteraction.1.location) / 2)                
            }
            canvas.delegate?.canvasMoveUpdated(at: interactionPosition, viaScroll: false, info: pinchInteraction.0.info, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
            
        }
        
        // MARK: - Pinch Done
        
        func pinchDone(_ pinchInteraction: (CCanvasInteraction, CCanvasInteraction)) {
            
            snapToAngle(pinchInteraction)
            
        }
        
        func snapToAngle(_ pinchInteraction: (CCanvasInteraction, CCanvasInteraction)) {
            let averageLocation: CGPoint = (pinchInteraction.0.location + pinchInteraction.1.location) / 2.0
            snapToAngle(at: averageLocation)
        }
        
        func snapToAngle(at location: CGPoint) {
            guard let snapAngle: Angle = canvas.snapGridToAngle else { return }
            let count: Int = Int(360.0 / snapAngle.degrees)
            let angles: [Angle] = ((count / -2)...(count / 2)).map { offset in
                Angle(degrees: snapAngle.degrees * Double(offset))
            }
            func narrow(angle: Angle) -> Angle {
                var angle: Angle = angle
                while !(-180.0...180).contains(angle.degrees) {
                    if angle.degrees > 180 {
                        angle -= Angle(degrees: 360)
                    } else if angle.degrees < -180 {
                        angle += Angle(degrees: 360)
                    }
                }
                return angle
            }
            let narrowCanvasAngle: Angle = narrow(angle: canvas.angle)
            for angle in angles {
                let angleDiff: Angle = Angle(degrees: abs(narrowCanvasAngle.degrees - angle.degrees))
                if angleDiff < snapAngleThreshold {
                    let currentAngle: Angle = canvas.angle
                    let currentOffset: CGPoint = canvas.offset
                    let relativeAngle: Angle = angle - narrowCanvasAngle
                    let newAngle: Angle = currentAngle + relativeAngle
                    let offset: CGPoint = currentOffset + rotationOffset(relativeAngle: relativeAngle, at: canvas.centerLocation)
                    CCanvasAnimation.animate(duration: 0.25, ease: .easeOut) { [weak self] fraction in
                        self?.canvas.offset = currentOffset * (1.0 - fraction) + offset * fraction
                        self?.canvas.angle = currentAngle * Double(1.0 - fraction) + newAngle * Double(fraction)
                    } done: {}
                    break
                }
            }
        }
        
        // MARK: - Transform
        
        func move(_ interaction: CCanvasInteraction) {
            
            offsetCanvas(by: interaction.velocity)
            
        }
        
        func move(_ interactions: (CCanvasInteraction, CCanvasInteraction)) {
            
            let averageVelocity: CGVector = (interactions.0.velocity + interactions.1.velocity) / 2.0
            
            offsetCanvas(by: averageVelocity)
            
        }
        
        func scale(_ pinchInteraction: (CCanvasInteraction, CCanvasInteraction)) {
            
            let distanceDirection: CGPoint = pinchInteraction.0.location - pinchInteraction.1.location
            let distance: CGFloat = sqrt(pow(distanceDirection.x, 2.0) + pow(distanceDirection.y, 2.0))
            let lastDistanceDirection: CGPoint = pinchInteraction.0.lastLocation - pinchInteraction.1.lastLocation
            let lastDistance: CGFloat = sqrt(pow(lastDistanceDirection.x, 2.0) + pow(lastDistanceDirection.y, 2.0))
            let relativeScale: CGFloat = distance / lastDistance
            
            if isNaN(relativeScale) {
                print("Canvas Scale by NaN")
                return
            }
            
            let averageLocation: CGPoint = (pinchInteraction.0.location + pinchInteraction.1.location) / 2.0
            
            scaleCanvas(by: relativeScale, at: averageLocation)
            
        }
        
        #if os(macOS)
        func scale(_ panInteraction: CCanvasInteraction) {
            
            let relativeScale: CGFloat = 1.0 + panInteraction.velocity.dy * middleMouseDragVelocityMultiplier
            
            let location: CGPoint = panInteraction.startLocation
            
            scaleCanvas(by: relativeScale, at: location)
            
        }
        #endif
        
        func scaleCanvas(by relativeScale: CGFloat, at location: CGPoint) {
            
            let oldScale: CGFloat = canvas.scale
            canvas.scale *= relativeScale
            let newScale: CGFloat = canvas.scale
            let realRelativeScale: CGFloat = newScale / oldScale

            if !canvas.magnifyInPlace {
                offsetCanvas(by: canvas.scaleOffset(relativeScale: realRelativeScale, at: location).asVector)
            }
        }
        
        func relativeRotation(_ pinchInteraction: (CCanvasInteraction, CCanvasInteraction)) -> Angle {
            
            let distanceDirection: CGPoint = pinchInteraction.0.location - pinchInteraction.1.location
            let lastDistanceDirection: CGPoint = pinchInteraction.0.lastLocation - pinchInteraction.1.lastLocation
            let angleInRadians: CGFloat = atan2(distanceDirection.y, distanceDirection.x)
            let lastAngleInRadians: CGFloat = atan2(lastDistanceDirection.y, lastDistanceDirection.x)
            let relativeAngle: Angle = Angle(radians: Double(angleInRadians - lastAngleInRadians))
            
            return relativeAngle
        }
        
        func rotate(_ pinchInteraction: (CCanvasInteraction, CCanvasInteraction)) {
        
            let relativeAngle: Angle = relativeRotation(pinchInteraction)
            
            rotate(relativeAngle: relativeAngle, pinchInteraction)
        }
        
        func rotate(relativeAngle: Angle, _ pinchInteraction: (CCanvasInteraction, CCanvasInteraction)) {
        
            if isNaN(CGFloat(relativeAngle.degrees)) {
                print("Canvas Rotate by NaN")
                return
            }
            
            let averageLocation: CGPoint = (pinchInteraction.0.location + pinchInteraction.1.location) / 2.0
            
            rotateCanvas(by: relativeAngle, at: averageLocation)
            
        }
        
        func rotateCanvas(by relativeAngle: Angle, at location: CGPoint) {
            
            canvas.angle += relativeAngle
            
            offsetCanvas(by: rotationOffset(relativeAngle: relativeAngle, at: location).asVector)
            
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
                print("Canvas Offset by NaN")
                return
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
