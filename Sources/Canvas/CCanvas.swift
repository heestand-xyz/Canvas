import Foundation
import SwiftUI
import CoreGraphicsExtensions
import MultiViews

public class CCanvas: ObservableObject, Identifiable {
    
    public weak var delegate: CCanvasDelegate?
    
    public let id: UUID
    
    var physics: Bool = iOS
    let snapGridToAngle: Angle?
    
    // FIXME: Window can't be strong, it will not deallocate.
    // FIXME: Window can't be weak, it will crash on second window close.
    #if os(macOS)
    public var window: NSWindow? { primaryWindow ?? secondaryWindow }
    public weak var primaryWindow: NSWindow?
    public var secondaryWindow: NSWindow?
    #endif
    
    @Published public var coordinate: CCanvasCoordinate = .zero
    public var offset: CGPoint {
        get { coordinate.offset }
        set { coordinate.offset = newValue }
    }
    public var scale: CGFloat {
        get { coordinate.scale }
        set { coordinate.scale = newValue }
    }
    public var angle: Angle {
        get { coordinate.angle }
        set { coordinate.angle = newValue }
    }
    
//    @Published public var offset: CGPoint = .zero
//    @Published public var scale: CGFloat = 1.0
//    @Published public var angle: Angle = .zero
//    public var coordinate: CCanvasCoordinate {
//        get {
//            CCanvasCoordinate(offset: offset, scale: scale, angle: angle)
//        }
//        set {
//            offset = newValue.offset
//            scale = newValue.scale
//            angle = newValue.angle
//        }
//    }
    
    /// Only used for centering.
    @Published public var size: CGSize?

    public var centerLocation: CGPoint { (size ?? .zero).asPoint / 2 }
    public var centerPosition: CGPoint { coordinate.position(at: centerLocation) }

    @Published var interactions: Set<CCanvasInteraction> = []
    @Published var panInteraction: CCanvasInteraction? = nil
    @Published var pinchInteraction: (CCanvasInteraction, CCanvasInteraction)? = nil
    @Published var dragInteractions: Set<CCanvasDragInteraction> = []
    
    @Published public var keyboardFlags: Set<CCanvasKeyboardFlag> = []
    @Published public var mouseLocation: CGPoint? = nil
    
    public var interactionEnabled: Bool = true
    public var trackpadEnabled: Bool = true
    public var magnifyInPlace: Bool = false

    public init(physics: Bool = iOS, snapGridToAngle: Angle? = nil, magnifyInPlace: Bool = false) {
        self.id = UUID()
        self.physics = physics
        self.snapGridToAngle = snapGridToAngle
        self.magnifyInPlace = magnifyInPlace
    }
}

extension CCanvas: Equatable {
    
    public static func == (lhs: CCanvas, rhs: CCanvas) -> Bool {
        lhs.id == rhs.id
    }
}

extension CCanvas: Hashable {
        
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(physics)
        hasher.combine(snapGridToAngle)
        hasher.combine(offset.x)
        hasher.combine(offset.y)
        hasher.combine(scale)
        hasher.combine(angle)
    }
}

// MARK: - Snap to Grid

extension CCanvas {
    
    public static func snapToGrid(position: CGPoint, snapGrid: CCanvasSnapGrid) -> CGPoint {
        
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
            if CCanvasCoordinate.distance(from: snapPositionA, to: position) < CCanvasCoordinate.distance(from: snapPositionB, to: position) {
                snapPosition = snapPositionA
            } else {
                snapPosition = snapPositionB
            }
        }
        
        return snapPosition
        
    }
}

// MARK: - Move

public extension CCanvas {
    
    func move(to coordinate: CCanvasCoordinate, animatedDuration: CGFloat? = nil) {
        let currentOffset: CGPoint = self.offset
        let currentScale: CGFloat = self.scale
        let currentAngle: Angle = self.angle
        if let duration: CGFloat = animatedDuration {
            CCanvasAnimation.animate(duration: duration, ease: .easeInOut) { [weak self] fraction in
                self?.offset = currentOffset * (1.0 - fraction) + coordinate.offset * fraction
                self?.scale = currentScale * (1.0 - fraction) + coordinate.scale * fraction
                self?.angle = Angle(degrees: currentAngle.degrees * Double(1.0 - fraction) + coordinate.angle.degrees * Double(fraction))
            }
        } else {
            self.offset = coordinate.offset
            self.scale = coordinate.scale
            self.angle = coordinate.angle
        }
    }
}

// MARK: - Zoom

public extension CCanvas {
    
    func zoom(by relativeScale: CGFloat, at location: CGPoint? = nil, animated: Bool = false) {
        let scale = scale * relativeScale
        let offset = offset + scaleOffset(relativeScale: relativeScale, at: location ?? centerLocation)
        let coordinate = CCanvasCoordinate(offset: offset, scale: scale, angle: angle)
        move(to: coordinate, animatedDuration: animated ? 0.25 : nil)
    }
    
    func scaleOffset(relativeScale: CGFloat, at location: CGPoint) -> CGPoint {
        
        let locationOffset: CGPoint = location - offset
        let scaledAverageLocationOffset: CGPoint = locationOffset * relativeScale
        let relativeScaleOffset: CGPoint = locationOffset - scaledAverageLocationOffset
        
        return relativeScaleOffset
        
    }
}

// MARK: - Origin

public extension CCanvas {
    
    var originCoordinate: CCanvasCoordinate {
        CCanvasCoordinate(offset: (size ?? .zero).asPoint / 2, scale: 1.0, angle: .zero)
    }
    
    func resetToOrigin(animated: Bool = false) {
        move(to: originCoordinate, animatedDuration: animated ? 0.25 : nil)
    }
    
}

// MARK: - Fit

public extension CCanvas {
    
    func fitCoordinate(in frame: CGRect, padding: CGFloat = 0.0) -> CCanvasCoordinate {
        
        guard size != .zero else { return .zero }
        
        let targetScale: CGFloat = min((size?.width ?? 0.0) / frame.width,
                                       (size?.height ?? 0.0) / frame.height)
        let targetFrame: CGRect = CGRect(origin: frame.origin - padding * targetScale,
                                         size: frame.size + (padding * 2) * targetScale)

        let fitScale: CGFloat = min((size?.width ?? 0.0) / targetFrame.width,
                                     (size?.height ?? 0.0) / targetFrame.height)
        let fitOffset: CGPoint = (size ?? .zero) / 2 - targetFrame.center * fitScale
        let fitAngle: Angle = .zero
        let fitCoordinate = CCanvasCoordinate(offset: fitOffset,
                                             scale: fitScale,
                                             angle: fitAngle)

        return fitCoordinate
    }
    
    func fit(in frame: CGRect, padding: CGFloat = 0.0, animated: Bool = false) {
        move(to: fitCoordinate(in: frame, padding: padding), animatedDuration: animated ? 0.25 : nil)
    }
}

extension CCanvas {
    
    public static let mock = CCanvas(physics: false, snapGridToAngle: nil)
}
