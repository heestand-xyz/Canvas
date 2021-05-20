import Foundation
import SwiftUI
import CoreGraphicsExtensions
import MultiViews

public class Canvas: ObservableObject, Codable, Identifiable {
    
    public weak var delegate: CanvasDelegate?
    
    public let id: UUID
    
    var physics: Bool = iOS
    let snapGridToAngle: Angle?
    
    #if os(macOS)
    public var window: NSWindow?
    #endif
    
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

    public var center: CGPoint { offset + size / 2 }
    
    @Published var interactions: Set<CanvasInteraction> = []
    @Published var panInteraction: CanvasInteraction? = nil
    @Published var pinchInteraction: (CanvasInteraction, CanvasInteraction)? = nil
    @Published var dragInteractions: Set<CanvasDragInteraction> = []
    
    @Published public var keyboardFlags: Set<CanvasKeyboardFlag> = []
    @Published public var mouseLocation: CGPoint? = nil

    public init(physics: Bool = iOS, snapGridToAngle: Angle? = nil) {
        self.id = UUID()
        self.physics = physics
        self.snapGridToAngle = snapGridToAngle
    }
    
    // MARK: Codable
    
    enum CodingKeys: CodingKey {
        case id
        case snapGridToAngle
        case size
        case offset
        case scale
        case angle
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        if let degrees = try container.decode(Double?.self, forKey: .snapGridToAngle) {
            snapGridToAngle = Angle(degrees: degrees)
        } else {
            snapGridToAngle = nil
        }
        offset = try container.decode(CGPoint.self, forKey: .offset)
        scale = try container.decode(CGFloat.self, forKey: .scale)
        angle = Angle(degrees: try container.decode(Double.self, forKey: .angle))

        let savedAtSize = try container.decode(CGSize.self, forKey: .size)
        offset -= savedAtSize / 2
        
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(snapGridToAngle?.degrees, forKey: .snapGridToAngle)
        try container.encode(size, forKey: .size)
        try container.encode(offset, forKey: .offset)
        try container.encode(scale, forKey: .scale)
        try container.encode(angle.degrees, forKey: .angle)

    }
}

extension Canvas: Equatable {
    
    public static func == (lhs: Canvas, rhs: Canvas) -> Bool {
        lhs.id == rhs.id
    }
}

extension Canvas: Hashable {
        
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

extension Canvas {
    
    public static func snapToGrid(position: CGPoint, snapGrid: CanvasSnapGrid) -> CGPoint {
        
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
}

// MARK: - Move

public extension Canvas {
    
    func move(to coordinate: CanvasCoordinate, animatedDuration: CGFloat? = nil) {
        let currentOffset: CGPoint = self.offset
        let currentScale: CGFloat = self.scale
        let currentAngle: Angle = self.angle
        if let duration: CGFloat = animatedDuration {
            CanvasAnimation.animate(for: duration, ease: .easeInOut) { fraction in
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
        move(to: originCoordinate, animatedDuration: animated ? 0.25 : nil)
    }
    
}

// MARK: - Fit

public extension Canvas {
    
    func fitCoordinate(in frame: CGRect, padding: CGFloat) -> CanvasCoordinate {
        
        guard size != .zero else { return .zero }
        
        let targetScale: CGFloat = min(size.width / frame.width,
                                       size.height / frame.height)
        let targetFrame: CGRect = CGRect(origin: frame.origin - padding * targetScale,
                                         size: frame.size + (padding * 2) * targetScale)

        let fitScale: CGFloat = min(size.width / targetFrame.width,
                                    size.height / targetFrame.height)
        let fitOffset: CGPoint = size / 2 - targetFrame.center * fitScale
        let fitAngle: Angle = .zero
        let fitCoordinate = CanvasCoordinate(offset: fitOffset,
                                             scale: fitScale,
                                             angle: fitAngle)

        return fitCoordinate
    }
    
    func fit(in frame: CGRect, padding: CGFloat, animated: Bool = false) {
        move(to: fitCoordinate(in: frame, padding: padding), animatedDuration: animated ? 0.25 : nil)
    }
}
