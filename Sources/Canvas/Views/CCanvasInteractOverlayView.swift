//import SwiftUI
//import MultiViews
//import CoreGraphicsExtensions
//import Logger
//
//#if os(macOS)
//
//public class CCanvasInteractOverlayView: MPView {
//    
//    var canvas: CCanvas
//    
//    var didStartScroll: () -> ()
//    var didScroll: (CGVector, Bool) -> ()
//    var didEndScroll: () -> ()
//    
//    var didStartMagnify: () -> ()
//    var didMagnify: (CGFloat) -> ()
//    var didEndMagnify: () -> ()
//    
//    var didStartRotate: () -> ()
//    var didRotate: (CGFloat) -> ()
//    var didEndRotate: () -> ()
//    
//    var scrollTimer: Timer?
//    let scrollTimeout: Double = 0.15
//    let scrollThreshold: CGFloat = 1.5
//    let middleMouseScrollVelocityMultiplier: CGFloat = 10
//
//    init(canvas: CCanvas,
//         didStartScroll: @escaping () -> (),
//         didScroll: @escaping (CGVector, Bool) -> (),
//         didEndScroll: @escaping () -> (),
//         didStartMagnify: @escaping () -> (),
//         didMagnify: @escaping (CGFloat) -> (),
//         didEndMagnify: @escaping () -> (),
//         didStartRotate: @escaping () -> (),
//         didRotate: @escaping (CGFloat) -> (),
//         didEndRotate: @escaping () -> ()) {
//        
//        self.canvas = canvas
//        
//        self.didStartScroll = didStartScroll
//        self.didScroll = didScroll
//        self.didEndScroll = didEndScroll
//        
//        self.didStartMagnify = didStartMagnify
//        self.didMagnify = didMagnify
//        self.didEndMagnify = didEndMagnify
//        
//        self.didStartRotate = didStartRotate
//        self.didRotate = didRotate
//        self.didEndRotate = didEndRotate
//
//        super.init(frame: .zero)
//        
//        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] in
//            Logger.log(message: "Monitor - Flags Changed", frequency: .verbose)
//            self?.flagsChanged(with: $0)
//            return $0
//        }
//        NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] in
//            self?.magnify(with: $0)
//            return $0
//        }
//        NSEvent.addLocalMonitorForEvents(matching: .rotate) { [weak self] in
//            self?.rotate(with: $0)
//            return $0
//        }
//        
//        becomeFirstResponder()
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    public override func updateTrackingAreas() {
//        let trackingArea = NSTrackingArea(rect: bounds, options: [
//            .mouseMoved,
//            .enabledDuringMouseDrag,
//            .mouseEnteredAndExited,
//            .activeInKeyWindow,
//        ], owner: self, userInfo: nil)
//        addTrackingArea(trackingArea)
//    }
//    
//    public var canBecomeFirstResponder: Bool { true }
//    public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
//        action.description.contains("context")
//    }
//    
//    public override func mouseMoved(with event: NSEvent) {
//        canvas.mouseLocation = getMouseLocation()
//    }
//    
//    func getMouseLocation() -> CGPoint? {
//        guard let window: NSWindow = canvas.window ?? window else { return nil }
//        let mouseLocation: CGPoint = window.mouseLocationOutsideOfEventStream
//        guard let windowView: NSView = window.contentView else { return nil }
//        var point: CGPoint = convert(.zero, to: windowView)
//        if point.y == 0.0 { point = convert(CGPoint(x: 0.0, y: windowView.bounds.height), to: windowView) }
//        let origin: CGPoint = CGPoint(x: point.x, y: windowView.bounds.size.height - point.y)
//        let location: CGPoint = mouseLocation - origin
//        let finalLocation: CGPoint = CGPoint(x: location.x, y: bounds.size.height - location.y)
//        return finalLocation
//    }
//    
//    // MARK: - Scroll
//    
//    public override func scrollWheel(with event: NSEvent) {
//        guard canvas.trackpadEnabled else { return }
//        
//        var delta: CGVector = CGVector(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY)
//        let withScrollWheel: Bool = !event.hasPreciseScrollingDeltas
//        if withScrollWheel {
//            delta *= middleMouseScrollVelocityMultiplier
//        }
//        
//        if scrollTimer == nil {
//            guard max(abs(delta.dx), abs(delta.dy)) > scrollThreshold else { return }
//            didStartScroll()
//        }
//        
//        didScroll(delta, withScrollWheel)
//        
//        scrollTimer?.invalidate()
//        scrollTimer = Timer(timeInterval: scrollTimeout, repeats: false, block: { [weak self] _ in
//            self?.scrollTimer = nil
//            self?.didEndScroll()
//        })
//        RunLoop.current.add(scrollTimer!, forMode: .common)
//    }
//    
//    // MARK: - Magnify
//    
//    public override func magnify(with event: NSEvent) {
//        guard canvas.trackpadEnabled else { return }
//        guard let mouseLocation: CGPoint = getMouseLocation() else { return }
//        guard bounds.contains(mouseLocation) else { return }
//        switch event.phase {
//        case .began:
//            didStartMagnify()
//            case .changed:
//            let delta: CGFloat = event.magnification
//            didMagnify(delta)
//        case .ended, .cancelled:
//            didEndMagnify()
//        default:
//            break
//        }
//    }
//    
//    // MARK: - Rotate
//    
//    public override func rotate(with event: NSEvent) {
//        guard canvas.rotationEnabled else { return }
//        guard canvas.trackpadEnabled else { return }
//        guard let mouseLocation: CGPoint = getMouseLocation() else { return }
//        guard bounds.contains(mouseLocation) else { return }
//        switch event.phase {
//        case .began:
//            didStartRotate()
//        case .changed:
//            let delta: CGFloat = CGFloat(event.rotation)
//            didRotate(delta)
//        case .ended, .cancelled:
//            didEndRotate()
//        default:
//            break
//        }
//    }
//    
//    // MARK: - Flags
//    
//    public override func flagsChanged(with event: NSEvent) {
//        var keyboardFlags: Set<CCanvasKeyboardFlag> = []
//        switch event.modifierFlags.intersection(.deviceIndependentFlagsMask) {
//        case .command:
//            keyboardFlags.insert(.command)
//        case .control:
//            keyboardFlags.insert(.control)
//        case .shift:
//            keyboardFlags.insert(.shift)
//        case .option:
//            keyboardFlags.insert(.option)
//        default:
//            break
//        }
//        canvas.keyboardFlags = keyboardFlags
//    }
//}
//
//#endif
