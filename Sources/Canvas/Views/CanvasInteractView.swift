import SwiftUI
import MultiViews
import CoreGraphicsExtensions

class CanvasInteractView: MPView {
    
    var canvas: Canvas
    var didMoveCanvasInteractions: (Set<CanvasInteraction>) -> ()
    var didScroll: (CGVector) -> ()

    init(canvas: Canvas,
         didMoveCanvasInteractions: @escaping (Set<CanvasInteraction>) -> (),
         didScroll: @escaping (CGVector) -> ()) {
        
        self.canvas = canvas
        self.didMoveCanvasInteractions = didMoveCanvasInteractions
        self.didScroll = didScroll
        
        super.init(frame: .zero)
        
        #if os(iOS)
        isMultipleTouchEnabled = true
        #endif
        
        #if os(macOS)
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) {
            self.flagsChanged(with: $0)
            return $0
        }
        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) {
            self.mouseMoved(with: $0)
            return $0
        }
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
            canvas.interactions.insert(canvasInteraction)
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        var movedCanvasInteractions: Set<CanvasInteraction> = []
        for touch in touches {
            guard let canvasInteraction: CanvasInteraction = canvas.interactions.first(where: { canvasInteraction in
                canvasInteraction.touch == touch
            }) else { continue }
            let lastLocation: CGPoint = canvasInteraction.location
            let location: CGPoint = touch.location(in: self)
            canvasInteraction.location = location
            let velocity: CGVector = CGVector(dx: location.x - lastLocation.x,
                                              dy: location.y - lastLocation.y)
            canvasInteraction.velocity = velocity
            movedCanvasInteractions.insert(canvasInteraction)
        }
        didMoveCanvasInteractions(movedCanvasInteractions)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let canvasInteraction: CanvasInteraction = canvas.interactions.first(where: { canvasInteraction in
                canvasInteraction.touch == touch
            }) else { continue }
            canvasInteraction.active = false
        }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let canvasInteraction: CanvasInteraction = canvas.interactions.first(where: { canvasInteraction in
                canvasInteraction.touch == touch
            }) else { continue }
            canvasInteraction.active = false
        }
    }
    #endif
    
    #if os(macOS)
    override func mouseDown(with event: NSEvent) {
        let location: CGPoint = getMouseLocation(event: event)
        let id = UUID()
        let canvasInteraction = CanvasInteraction(id: id, location: location)
        canvas.interactions.insert(canvasInteraction)
    }
    override func mouseUp(with event: NSEvent) {
        guard let canvasInteraction: CanvasInteraction = canvas.interactions.first else { return }
        canvasInteraction.active = false
    }
    override func mouseDragged(with event: NSEvent) {
        let location: CGPoint = getMouseLocation(event: event)
        guard let canvasInteraction: CanvasInteraction = canvas.interactions.first else { return }
        let lastLocation: CGPoint = canvasInteraction.location
        canvasInteraction.location = location
        let velocity: CGVector = CGVector(dx: location.x - lastLocation.x,
                                          dy: location.y - lastLocation.y)
        canvasInteraction.velocity = velocity
        didMoveCanvasInteractions([canvasInteraction])
        
        print("DRAG", canvas.interactions.count)
    }
    override func mouseMoved(with event: NSEvent) {
        canvas.mouseLocation = getMouseLocation(event: event)
    }
    func getMouseLocation(event: NSEvent) -> CGPoint {
        guard let window: NSWindow = window else { return .zero }
        let mouseLocation: CGPoint = window.mouseLocationOutsideOfEventStream
        guard let vcView: NSView = window.contentViewController?.view else { return .zero }
        let point: CGPoint = convert(.zero, to: vcView)
        let origin: CGPoint = CGPoint(x: point.x, y: vcView.bounds.size.height - point.y)
        let location: CGPoint = mouseLocation - origin
        let flippedLocation: CGPoint = CGPoint(x: location.x, y: bounds.size.height - location.y)
        return flippedLocation
    }
    #endif
    
    #if os(macOS)
    override func scrollWheel(with event: NSEvent) {
        didScroll(CGVector(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY))
    }
    #endif
    
    #if os(macOS)
    override func flagsChanged(with event: NSEvent) {
        var keyboardFlags: Set<CanvasKeyboardFlag> = []
        switch event.modifierFlags.intersection(.deviceIndependentFlagsMask) {
        case .command:
            keyboardFlags.insert(.command)
        case .control:
            keyboardFlags.insert(.control)
        case .shift:
            keyboardFlags.insert(.shift)
        case .option:
            keyboardFlags.insert(.option)
        default:
            break
        }
        canvas.keyboardFlags = keyboardFlags
    }
    #endif
    
}
