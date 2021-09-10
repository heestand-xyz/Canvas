import SwiftUI
import MultiViews
import CoreGraphicsExtensions
import Logger

public class CCanvasInteractView: MPView {
    
    var canvas: CCanvas
    var didMoveCCanvasInteractions: (Set<CCanvasInteraction>) -> ()
    
    var didStartScroll: () -> ()
    var didScroll: (CGVector, Bool) -> ()
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
    let middleMouseScrollVelocityMultiplier: CGFloat = 10
    #endif

    init(canvas: CCanvas,
         didMoveCCanvasInteractions: @escaping (Set<CCanvasInteraction>) -> (),
         didStartScroll: @escaping () -> (),
         didScroll: @escaping (CGVector, Bool) -> (),
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
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] in
            Logger.log(message: "Monitor - Flags Changed")
            self?.flagsChanged(with: $0)
            return $0
        }
//        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] in
//            self?.mouseMoved(with: $0)
//            return $0
//        }
//        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] in
//            Logger.log(message: "Monitor - Left Mouse Down")
//            self?.mouseDown(with: $0)
//            return $0
//        }
//        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] in
//            self?.mouseDragged(with: $0)
//            return $0
//        }
//        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] in
//            self?.mouseMoved(with: $0)
//            return $0
//        }
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] in
            Logger.log(message: "Monitor - Left Mouse Up")
            self?.mouseUp(with: $0)
            return $0
        }
        NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] in
            self?.magnify(with: $0)
            return $0
        }
        NSEvent.addLocalMonitorForEvents(matching: .rotate) { [weak self] in
            self?.rotate(with: $0)
            return $0
        }
        #endif
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    #if os(macOS)
    public override func updateTrackingAreas() {
        let trackingArea = NSTrackingArea(rect: bounds, options: [
            .mouseMoved,
            .enabledDuringMouseDrag,
            .mouseEnteredAndExited,
            .activeInKeyWindow,
        ], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
    #endif
    
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
        Logger.log()
        guard canvas.interactionEnabled else { return }
        for touch in touches {
            let id = UUID()
            let location: CGPoint = touch.location(in: self)
            let canvasInteraction = CCanvasInteraction(id: id, location: location, info: CCanvasInteractionInfo(view: self))
            canvasInteraction.touch = touch
            canvas.interactions.insert(canvasInteraction)
        }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard canvas.interactionEnabled else { return }
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
        Logger.log()
        guard canvas.interactionEnabled else { return }
        for touch in touches {
            guard let canvasInteraction: CCanvasInteraction = canvas.interactions.first(where: { canvasInteraction in
                canvasInteraction.touch == touch
            }) else { continue }
            canvasInteraction.active = false
        }
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        Logger.log()
        guard canvas.interactionEnabled else { return }
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
        Logger.log()
        guard canvas.interactionEnabled else { return }
        guard let location: CGPoint = getMouseLocation() else { return }
        let id = UUID()
        let canvasInteraction = CCanvasInteraction(id: id, location: location, info: CCanvasInteractionInfo(view: self, event: event, mouseButton: .left))
        canvas.interactions.insert(canvasInteraction)
    }
    
    public override func rightMouseDown(with event: NSEvent) {
        Logger.log()
        guard canvas.interactionEnabled else { return }
        guard let location: CGPoint = getMouseLocation() else { return }
        let id = UUID()
        let canvasInteraction = CCanvasInteraction(id: id, location: location, info: CCanvasInteractionInfo(view: self, event: event, mouseButton: .right))
        canvas.interactions.insert(canvasInteraction)
    }
    public override func otherMouseDown(with event: NSEvent) {
        Logger.log()
        let isMiddleMouseButton = event.buttonNumber == 2
        if isMiddleMouseButton {
            guard canvas.interactionEnabled else { return }
            guard let location: CGPoint = getMouseLocation() else { return }
            let id = UUID()
            let canvasInteraction = CCanvasInteraction(id: id, location: location, info: CCanvasInteractionInfo(view: self, event: event, mouseButton: .middle))
            canvas.interactions.insert(canvasInteraction)
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        Logger.log()
        guard canvas.interactionEnabled else { return }
        guard let canvasInteraction: CCanvasInteraction = canvas.interactions.first else { return }
        canvasInteraction.active = false
    }
    
    public override func rightMouseUp(with event: NSEvent) {
        Logger.log()
        guard canvas.interactionEnabled else { return }
        guard let canvasInteraction: CCanvasInteraction = canvas.interactions.first else { return }
        canvasInteraction.active = false
    }
    
    public override func otherMouseUp(with event: NSEvent) {
        let isMiddleMouseButton = event.buttonNumber == 2
        if isMiddleMouseButton {
            Logger.log()
            guard canvas.interactionEnabled else { return }
            guard let canvasInteraction: CCanvasInteraction = canvas.interactions.first else { return }
            canvasInteraction.active = false
        } else if let customMouseButton = CCustomMouseButton(rawValue: event.buttonNumber) {
            guard let location: CGPoint = getMouseLocation() else { return }
            canvas.delegate?.canvasCustomMouseButtonPress(at: location, with: customMouseButton, keyboardFlags: canvas.keyboardFlags, coordinate: canvas.coordinate)
        }
    }
    
    public override func mouseDragged(with event: NSEvent) {
        mouseDragged()
    }
    
    public override func rightMouseDragged(with event: NSEvent) {
        mouseDragged()
    }
    
    public override func otherMouseDragged(with event: NSEvent) {
        mouseDragged()
    }
    
    func mouseDragged() {
        guard canvas.interactionEnabled else { return }
        guard let location: CGPoint = getMouseLocation() else { return }
        guard let canvasInteraction: CCanvasInteraction = canvas.interactions.first else { return }
        let lastLocation: CGPoint = canvasInteraction.location
        canvasInteraction.location = location
        let velocity: CGVector = CGVector(dx: location.x - lastLocation.x,
                                          dy: location.y - lastLocation.y)
        canvasInteraction.velocity = velocity
        didMoveCCanvasInteractions([canvasInteraction])
    }
    
    public override func mouseMoved(with event: NSEvent) {
        canvas.mouseLocation = getMouseLocation()
    }
    
    func getMouseLocation() -> CGPoint? {
//        if window == nil || canvas.window == nil {
//            print("Some Mouse Window is Missing",
//                  window == nil ? "(View Window Missing)" : "",
//                  canvas.window == nil ? "(Canvas Window Missing)" : "")
//        }
        guard let window: NSWindow = canvas.window ?? window else { return nil }
//        let title: String = window.title
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
        guard canvas.trackpadEnabled else { return }
        
        var delta: CGVector = CGVector(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY)
        let withScrollWheel: Bool = !event.hasPreciseScrollingDeltas
        if withScrollWheel {
            delta *= middleMouseScrollVelocityMultiplier
        }
        
        if scrollTimer == nil {
            guard max(abs(delta.dx), abs(delta.dy)) > scrollThreshold else { return }
            didStartScroll()
        }
        
        didScroll(delta, withScrollWheel)
        
        scrollTimer?.invalidate()
        scrollTimer = Timer(timeInterval: scrollTimeout, repeats: false, block: { [weak self] _ in
            self?.scrollTimer = nil
            self?.didEndScroll()
        })
        RunLoop.current.add(scrollTimer!, forMode: .common)
    }
    
    // MARK: - Magnify
    
    public override func magnify(with event: NSEvent) {
        guard canvas.trackpadEnabled else { return }
        guard let mouseLocation: CGPoint = getMouseLocation() else { return }
        guard bounds.contains(mouseLocation) else { return }
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
        guard canvas.trackpadEnabled else { return }
        guard let mouseLocation: CGPoint = getMouseLocation() else { return }
        guard bounds.contains(mouseLocation) else { return }
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
    func contextSaveImage()
    func contextSaveImageInCircle()
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
    
    @objc public func contextSaveImage() {
        CCanvasInteractView.nodeContextActions?.contextSaveImage()
    }
    
    @objc public func contextSaveImageInCircle() {
        CCanvasInteractView.nodeContextActions?.contextSaveImageInCircle()
    }
}

public protocol AreaContextActions {
    func contextPaseNodes()
    func contextZoomToCircle()
    func contextZoomToNodes()
}

extension CCanvasInteractView: AreaContextActions {
    
    public static var areaContextActions: AreaContextActions?
    
    @objc public func contextPaseNodes() {
        CCanvasInteractView.areaContextActions?.contextPaseNodes()
    }
    
    @objc public func contextZoomToCircle() {
        CCanvasInteractView.areaContextActions?.contextZoomToCircle()
    }
    
    @objc public func contextZoomToNodes() {
        CCanvasInteractView.areaContextActions?.contextZoomToNodes()
    }
}

