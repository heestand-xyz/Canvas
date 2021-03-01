import SwiftUI
import MultiViews
import CoreGraphicsExtensions

class CanvasInteractView: MPView {
    
    @Binding var canvasInteractions: [CanvasInteraction]
    var didMoveCanvasInteractions: ([CanvasInteraction]) -> ()

    init(canvasInteractions: Binding<[CanvasInteraction]>,
         didMoveCanvasInteractions: @escaping ([CanvasInteraction]) -> ()) {
        
        _canvasInteractions = canvasInteractions
        self.didMoveCanvasInteractions = didMoveCanvasInteractions
        
        super.init(frame: .zero)
        
        #if os(iOS)
        isMultipleTouchEnabled = true
        #endif
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = UUID()
            let location: CGPoint = touch.location(in: self)
            let canvasInteraction = CanvasInteraction(id: id, location: location)
            canvasInteraction.touch = touch
            canvasInteractions.append(canvasInteraction)
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        var movedCanvasInteractions: [CanvasInteraction] = []
        for touch in touches {
            guard let canvasInteraction: CanvasInteraction = canvasInteractions.first(where: { canvasInteraction in
                canvasInteraction.touch == touch
            }) else { continue }
            let lastLocation: CGPoint = canvasInteraction.location
            let location: CGPoint = touch.location(in: self)
            canvasInteraction.location = location
            let velocity: CGVector = CGVector(dx: location.x - lastLocation.x,
                                              dy: location.y - lastLocation.y)
            canvasInteraction.velocity = velocity
            movedCanvasInteractions.append(canvasInteraction)
        }
        didMoveCanvasInteractions(movedCanvasInteractions)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let canvasInteraction: CanvasInteraction = canvasInteractions.first(where: { canvasInteraction in
                canvasInteraction.touch == touch
            }) else { continue }
            canvasInteraction.active = false
        }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let canvasInteraction: CanvasInteraction = canvasInteractions.first(where: { canvasInteraction in
                canvasInteraction.touch == touch
            }) else { continue }
            canvasInteraction.active = false
        }
    }
    #endif
    
    #if os(macOS)
    override func mouseDown(with event: NSEvent) {
        guard let location: CGPoint = getMouseLocation(event: event) else { return }
        let id = UUID()
        let canvasInteraction = CanvasInteraction(id: id, location: location)
        canvasInteractions.append(canvasInteraction)
    }
    override func mouseDragged(with event: NSEvent) {
        guard let location: CGPoint = getMouseLocation(event: event) else { return }
        guard let canvasInteraction: CanvasInteraction = canvasInteractions.first else { return }
        let lastLocation: CGPoint = canvasInteraction.location
        canvasInteraction.location = location
        let velocity: CGVector = CGVector(dx: location.x - lastLocation.x,
                                          dy: location.y - lastLocation.y)
        canvasInteraction.velocity = velocity
        didMoveCanvasInteractions([canvasInteraction])
    }
    override func mouseUp(with event: NSEvent) {
        guard let canvasInteraction: CanvasInteraction = canvasInteractions.first else { return }
        canvasInteraction.active = false
    }
    func getMouseLocation(event: NSEvent) -> CGPoint? {
        let mouseLocation: CGPoint = event.locationInWindow
        guard let vcView: NSView = window?.contentViewController?.view else { return nil }
        let point: CGPoint = convert(.zero, to: vcView)
        let origin: CGPoint = CGPoint(x: point.x, y: vcView.bounds.size.height - point.y)
        let location: CGPoint = mouseLocation - origin
        let flippedLocation: CGPoint = CGPoint(x: location.x, y: bounds.size.height - location.y)
        return flippedLocation
    }
    #endif
    
}
