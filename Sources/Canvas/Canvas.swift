import Foundation
import SwiftUI
import CoreGraphicsExtensions

public class Canvas: ObservableObject, Identifiable {
    
    public weak var delegate: CanvasDelegate?
    
    public let id: UUID
    
    let physics: Bool
    let snapGridToAngle: Angle?
    
    @Published public var offset: CGPoint = .zero
    @Published public var scale: CGFloat = 1.0
    @Published public var angle: Angle = .zero
    public var coordinate: CanvasCoordinate {
        get {
            CanvasCoordinate(offset: offset, scale: scale, angle: angle)
        }
        set {
            offset = newValue.offset
            scale = newValue.scale
            angle = newValue.angle
        }
    }
    
    /// Only used for centering.
    @Published public var size: CGSize = .zero
    
    @Published var interactions: Set<CanvasInteraction> = []
    @Published var panInteraction: CanvasInteraction? = nil
    @Published var pinchInteraction: (CanvasInteraction, CanvasInteraction)? = nil
    @Published var dragInteractions: Set<CanvasDragInteraction> = []
    
    @Published var keyboardFlags: Set<CanvasKeyboardFlag> = []
    @Published var mouseLocation: CGPoint? = nil

    public init(physics: Bool = false, snapGridToAngle: Angle? = nil) {
        self.id = UUID()
        self.physics = physics
        self.snapGridToAngle = snapGridToAngle
    }
}

// MARK: - Equatable

extension Canvas: Equatable {
    
    public static func == (lhs: Canvas, rhs: Canvas) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Move

public extension Canvas {
    
    func move(to coordinate: CanvasCoordinate, animated: Bool = false) {
        let currentOffset: CGPoint = self.offset
        let currentScale: CGFloat = self.scale
        let currentAngle: Angle = self.angle
        if animated {
            CanvasAnimation.animate(for: 0.25, ease: .easeInOut) { fraction in
                self.offset = currentOffset * (1.0 - fraction) + coordinate.offset * fraction
                self.scale = currentScale * (1.0 - fraction) + coordinate.scale * fraction
                self.angle = Angle(degrees: currentAngle.degrees * Double(1.0 - fraction) + coordinate.angle.degrees * Double(fraction))
            }
        } else {
            self.offset = coordinate.offset
            self.scale = coordinate.scale
            self.angle = coordinate.angle
        }
    }
}


// MARK: - Origin

public extension Canvas {
    
    var originCoordinate: CanvasCoordinate {
        CanvasCoordinate(offset: size.point / 2, scale: 1.0, angle: .zero)
    }
    
    func resetToOrigin(animated: Bool = false) {
        move(to: originCoordinate, animated: animated)
    }
    
}

// MARK: - Fit

public extension Canvas {
    
    func fitCoordinate(in frame: CGRect, padding: CGFloat) -> CanvasCoordinate {
        
        guard size != .zero else { return .zero }
        
        let targetScale: CGFloat = min(size.width / frame.width, size.height / frame.height)
        let targetFrame: CGRect = CGRect(origin: frame.origin - padding / targetScale,
                                         size: frame.size + (padding * 2) / targetScale)

        #warning("Fit Canvas in Center of Nodes")
        let fitOffset: CGPoint = size.point / 2 // targetFrame.center + size / 2
        let fitScale: CGFloat = min(size.width / targetFrame.width, size.height / targetFrame.height)
        #warning("Fit Canvas with Angle")
        let fitAngle: Angle = .zero
        let fitCoordinate = CanvasCoordinate(offset: fitOffset, scale: fitScale, angle: fitAngle)

        return fitCoordinate
    }
    
    func fit(in frame: CGRect, padding: CGFloat, animated: Bool = false) {
        move(to: fitCoordinate(in: frame, padding: padding), animated: animated)
    }
}
