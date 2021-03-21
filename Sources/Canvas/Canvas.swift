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

// MARK: - Reset

extension Canvas {
    
    public func reset(animated: Bool = false) {
        let currentOffset: CGPoint = self.offset
        let currentScale: CGFloat = self.scale
        let currentAngle: Angle = self.angle
        let currentSize: CGSize = self.size
        if animated {
            CanvasAnimation.animate(for: 0.25, ease: .easeInOut) { fraction in
                self.offset = currentOffset * (1.0 - fraction) + (currentSize.point / 2) * fraction
                self.scale = currentScale * (1.0 - fraction) + fraction
                self.angle = Angle(degrees: currentAngle.degrees * (1.0 - Double(fraction)))
            }
        } else {
            self.offset = offset
            self.scale = 1.0
            self.angle = .zero
        }
    }
}
