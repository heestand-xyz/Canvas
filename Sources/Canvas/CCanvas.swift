import Foundation
import SwiftUI
import CoreGraphicsExtensions
import MultiViews

public class CCanvas: ObservableObject, Codable, Identifiable {
    
    public weak var delegate: CCanvasDelegate?
    
    public let id: UUID
    
    var physics: Bool = iOS
    let snapGridToAngle: Angle?
    
    #if os(macOS)
    #warning("Window can't be weak, it will crash on second window close.")
    public var window: NSWindow?
    #endif
    
    @Published public var offset: CGPoint = .zero
    @Published public var scale: CGFloat = 1.0
    @Published public var angle: Angle = .zero
    public var coordinate: CCanvasCoordinate {
        get {
            CCanvasCoordinate(offset: offset, scale: scale, angle: angle)
        }
        set {
            offset = newValue.offset
            scale = newValue.scale
            angle = newValue.angle
        }
    }
    
    /// Only used for centering.
    @Published public var size: CGSize = .zero

    public var centerLocation: CGPoint { size.point / 2 }
    public var centerPosition: CGPoint { coordinate.position(at: centerLocation) }

    @Published var interactions: Set<CCanvasInteraction> = []
    @Published var panInteraction: CCanvasInteraction? = nil
    @Published var pinchInteraction: (CCanvasInteraction, CCanvasInteraction)? = nil
    @Published var dragInteractions: Set<CCanvasDragInteraction> = []
    
    @Published public var keyboardFlags: Set<CCanvasKeyboardFlag> = []
    @Published public var mouseLocation: CGPoint? = nil
    
    public var interactionEnabled: Bool = true

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
            CCanvasAnimation.animate(for: duration, ease: .easeInOut) { [weak self] fraction in
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
        CCanvasCoordinate(offset: size.point / 2, scale: 1.0, angle: .zero)
    }
    
    func resetToOrigin(animated: Bool = false) {
        move(to: originCoordinate, animatedDuration: animated ? 0.25 : nil)
    }
    
}

// MARK: - Fit

public extension CCanvas {
    
    func fitCoordinate(in frame: CGRect, padding: CGFloat) -> CCanvasCoordinate {
        
        guard size != .zero else { return .zero }
        
        let targetScale: CGFloat = min(size.width / frame.width,
                                       size.height / frame.height)
        let targetFrame: CGRect = CGRect(origin: frame.origin - padding * targetScale,
                                         size: frame.size + (padding * 2) * targetScale)

        let fitScale: CGFloat = min(size.width / targetFrame.width,
                                    size.height / targetFrame.height)
        let fitOffset: CGPoint = size / 2 - targetFrame.center * fitScale
        let fitAngle: Angle = .zero
        let fitCoordinate = CCanvasCoordinate(offset: fitOffset,
                                             scale: fitScale,
                                             angle: fitAngle)

        return fitCoordinate
    }
    
    func fit(in frame: CGRect, padding: CGFloat, animated: Bool = false) {
        move(to: fitCoordinate(in: frame, padding: padding), animatedDuration: animated ? 0.25 : nil)
    }
}
