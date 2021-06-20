import SwiftUI
import MultiViews
import CoreGraphicsExtensions

public class CCanvasInteractView: MPView {
    
    var canvas: CCanvas
    var didMoveCCanvasInteractions: (Set<CCanvasInteraction>) -> ()
    
    var didStartScroll: () -> ()
    var didScroll: (CGVector) -> ()
    var didEndScroll: () -> ()
    
    var didStartMagnify: () -> ()
    var didMagnify: (CGFloat) -> ()
    var didEndMagnify: () -> ()
    
    var didStartRotate: () -> ()
    var didRotate: (CGFloat) -> ()
    var didEndRotate: () -> ()
    
    #if os(macOS)
    var scrollTimer: Timer?
    let scrollTimeout: Double = 0.15
    let scrollThreshold: CGFloat = 1.5
    #endif

    init(canvas: CCanvas,
         didMoveCCanvasInteractions: @escaping (Set<CCanvasInteraction>) -> (),
         didStartScroll: @escaping () -> (),
         didScroll: @escaping (CGVector) -> (),
         didEndScroll: @escaping () -> (),
         didStartMagnify: @escaping () -> (),
         didMagnify: @escaping (CGFloat) -> (),
         didEndMagnify: @escaping () -> (),
         didStartRotate: @escaping () -> (),
         didRotate: @escaping (CGFloat) -> (),
         didEndRotate: @escaping () -> ()) {
        
        self.canvas = canvas
        self.didMoveCCanvasInteractions = didMoveCCanvasInteractions
        
        self.didStartScroll = didStartScroll
        self.didScroll = didScroll
        self.didEndScroll = didEndScroll
        
        self.didStartMagnify = didStartMagnify
        self.didMagnify = didMagnify
        self.didEndMagnify = didEndMagnify
        
        self.didStartRotate = didStartRotate
        self.didRotate = didRotate
        self.didEndRotate = didEndRotate

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
    public override var canBecomeFirstResponder: Bool { true }
    public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        action.description.contains("context")
    }
    #elseif os(macOS)
    public var canBecomeFirstResponder: Bool { true }
    public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        action.description.contains("context")
    }
    #endif
    
    #if os(iOS)
    
    // MARK: - Touch
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = UUID()
            let location: CGPoint = touch.location(in: self)
            let canvasInteraction = CCanvasInteraction(id: id, location: location, info: CCanvasInteractionInfo(view: self))
            canvasInteraction.touch = touch
            canvas.interactions.insert(canvasInteraction)
        }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        var movedCCanvasInteractions: Set<CCanvasInteraction> = []
        for touch in touches {
            guard let canvasInteraction: CCanvasInteraction = canvas.interactions.first(where: { canvasInteraction in
                canvasInteraction.touch == touch
            }) else { continue }
            let lastLocation: CGPoint = canvasInteraction.location
            let location: CGPoint = touch.location(in: self)
            canvasInteraction.location = location
            let velocity: CGVector = CGVector(dx: location.x - lastLocation.x,
                                              dy: location.y - lastLocation.y)
            canvasInteraction.velocity = velocity
            movedCCanvasInteractions.insert(canvasInteraction)
        }
        didMoveCCanvasInteractions(movedCCanvasInteractions)
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let canvasInteraction: CCanvasInteraction = canvas.interactions.first(where: { canvasInteraction in
                canvasInteraction.touch == touch
            }) else { continue }
            canvasInteraction.active = false
        }
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let canvasInteraction: CCanvasInteraction = canvas.interactions.first(where: { canvasInteraction in
                canvasInteraction.touch == touch
            }) else { continue }
            canvasInteraction.active = false
        }
    }
    
    #elseif os(macOS)
    
    // MARK: - Mouse
    
    public override func mouseDown(with event: NSEvent) {
        guard let location: CGPoint = getMouseLocation(event: event) else { return }
        let id = UUID()
        let canvasInteraction = CCanvasInteraction(id: id, location: location, info: CCanvasInteractionInfo(view: self, event: event, isAlternative: false))
        canvas.interactions.insert(canvasInteraction)
    }
    
    public override func rightMouseDown(with event: NSEvent) {
        guard let location: CGPoint = getMouseLocation(event: event) else { return }
        let id = UUID()
        let canvasInteraction = CCanvasInteraction(id: id, location: location, info: CCanvasInteractionInfo(view: self, event: event, isAlternative: true))
        canvas.interactions.insert(canvasInteraction)
    }
    
    public override func mouseUp(with event: NSEvent) {
        guard let canvasInteraction: CCanvasInteraction = canvas.interactions.first else { return }
        canvasInteraction.active = false
    }
    
    public override func rightMouseUp(with event: NSEvent) {
        guard let canvasInteraction: CCanvasInteraction = canvas.interactions.first else { return }
        canvasInteraction.active = false
    }
    
    public override func mouseDragged(with event: NSEvent) {
        guard let location: CGPoint = getMouseLocation(event: event) else { return }
        guard let canvasInteraction: CCanvasInteraction = canvas.interactions.first else { return }
        let lastLocation: CGPoint = canvasInteraction.location
        canvasInteraction.location = location
        let velocity: CGVector = CGVector(dx: location.x - lastLocation.x,
                                          dy: location.y - lastLocation.y)
        canvasInteraction.velocity = velocity
        didMoveCCanvasInteractions([canvasInteraction])
    }
    
    public override func mouseMoved(with event: NSEvent) {
        canvas.mouseLocation = getMouseLocation(event: event)
    }
    
    func getMouseLocation(event: NSEvent) -> CGPoint? {
//        if window == nil || canvas.window == nil {
//            print("Some Mouse Window is Missing",
//                  window == nil ? "(View Window Missing)" : "",
//                  canvas.window == nil ? "(Canvas Window Missing)" : "")
//        }
        guard let window: NSWindow = canvas.window ?? window else { return nil }
        let title: String = window.title
        let mouseLocation: CGPoint = window.mouseLocationOutsideOfEventStream
        guard let windowView: NSView = window.contentView else { return nil }
        var point: CGPoint = convert(.zero, to: windowView)
        if point.y == 0.0 { point = convert(CGPoint(x: 0.0, y: windowView.bounds.height), to: windowView) }
        let origin: CGPoint = CGPoint(x: point.x, y: windowView.bounds.size.height - point.y)
        let location: CGPoint = mouseLocation - origin
        let finalLocation: CGPoint = CGPoint(x: location.x, y: bounds.size.height - location.y)
        return finalLocation
    }
    
    // MARK: - Scroll
    
    public override func scrollWheel(with event: NSEvent) {
        
        let delta: CGVector = CGVector(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY)
        
        if scrollTimer == nil {
            guard max(abs(delta.dx), abs(delta.dy)) > scrollThreshold else { return }
            didStartScroll()
        }
        
        didScroll(delta)
        
        scrollTimer?.invalidate()
        scrollTimer = Timer(timeInterval: scrollTimeout, repeats: false, block: { _ in
            self.scrollTimer = nil
            self.didEndScroll()
        })
        RunLoop.current.add(scrollTimer!, forMode: .common)
    }
    
    // MARK: - MAgnify
    
    public override func magnify(with event: NSEvent) {
        switch event.phase {
        case .began:
            didStartMagnify()
            case .changed:
            let delta: CGFloat = event.magnification
            didMagnify(delta)
        case .ended, .cancelled:
            didEndMagnify()
        default:
            break
        }
    }
    
    // MARK: - Rotate
    
    public override func rotate(with event: NSEvent) {
        switch event.phase {
        case .began:
            didStartRotate()
        case .changed:
            let delta: CGFloat = CGFloat(event.rotation)
            didRotate(delta)
        case .ended, .cancelled:
            didEndRotate()
        default:
            break
        }
    }
    
    // MARK: - Flags
    
    public override func flagsChanged(with event: NSEvent) {
        var keyboardFlags: Set<CCanvasKeyboardFlag> = []
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

public protocol NodeContextActions {
    func contextCopy()
    func contextDuplicate()
    func contextRemove()
    func contextFillView()
    func contextFullscreen()
}

extension CCanvasInteractView: NodeContextActions {
    
    public static var nodeContextActions: NodeContextActions?
    
    @objc public func contextCopy() {
        CCanvasInteractView.nodeContextActions?.contextCopy()
    }
    
    @objc public func contextDuplicate() {
        CCanvasInteractView.nodeContextActions?.contextDuplicate()
    }
    
    @objc public func contextRemove() {
        CCanvasInteractView.nodeContextActions?.contextRemove()
    }
    
    @objc public func contextFillView() {
        CCanvasInteractView.nodeContextActions?.contextFillView()
    }
    
    @objc public func contextFullscreen() {
        CCanvasInteractView.nodeContextActions?.contextFullscreen()
    }
}

public protocol AreaContextActions {
    func contextPaseNodes()
    func contextFitCanvas()
}

extension CCanvasInteractView: AreaContextActions {
    
    public static var areaContextActions: AreaContextActions?
    
    @objc public func contextPaseNodes() {
        CCanvasInteractView.areaContextActions?.contextPaseNodes()
    }
    
    @objc public func contextFitCanvas() {
        CCanvasInteractView.areaContextActions?.contextFitCanvas()
    }
}
