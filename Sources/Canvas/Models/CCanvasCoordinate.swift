import CoreGraphics
import CoreGraphicsExtensions
import SwiftUI

public struct CCanvasCoordinate: Equatable, Sendable {
    public var offset: CGPoint
    public var scale: CGFloat
    public var angle: Angle
    public init(offset: CGPoint, scale: CGFloat, angle: Angle) {
        self.offset = offset
        self.scale = scale
        self.angle = angle
    }
}

extension CCanvasCoordinate: Codable {
    
    enum CodingKeys: CodingKey {
        case offset
        case scale
        case angle
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        offset = try container.decode(CGPoint.self, forKey: .offset)
        scale = try container.decode(CGFloat.self, forKey: .scale)
        let degrees: Double = try container.decode(Double.self, forKey: .angle)
        angle = .degrees(degrees)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(offset, forKey: .offset)
        try container.encode(scale, forKey: .scale)
        try container.encode(angle.degrees, forKey: .angle)
    }
}

public extension CCanvasCoordinate {
    static func cross(from fromCoordinate: CCanvasCoordinate, to toCoordinate: CCanvasCoordinate, at fraction: CGFloat) -> CCanvasCoordinate {
        CCanvasCoordinate(offset: fromCoordinate.offset * (1.0 - fraction) + toCoordinate.offset * fraction,
                         scale: fromCoordinate.scale * (1.0 - fraction) + toCoordinate.scale * fraction,
                         angle: Angle(degrees: fromCoordinate.angle.degrees * Double(1.0 - fraction) + toCoordinate.angle.degrees * Double(fraction)))
    }
}

public extension CCanvasCoordinate {
    var rotatedOffset: CGPoint {
        CCanvasCoordinate.rotate(offset, by: -angle)
    }
}

public extension CCanvasCoordinate {
    
    @available(*, deprecated, renamed: "position(at:)")
    func absolute(location: CGPoint) -> CGPoint {
        position(at: location)
    }
    /// Converts from screen space to content space
    func position(at location: CGPoint) -> CGPoint {
        CCanvasCoordinate.rotate((location - offset) / scale, by: -angle)
    }
    
    /// Converts from screen space to content space
    func absolute(frame: CGRect) -> (topLeft: CGPoint, bottomLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint) {
        (
            topLeft: position(at: CGPoint(x: frame.minX, y: frame.minY)),
            bottomLeft: position(at: CGPoint(x: frame.minX, y: frame.maxY)),
            topRight: position(at: CGPoint(x: frame.maxX, y: frame.minY)),
            bottomRight: position(at: CGPoint(x: frame.maxX, y: frame.maxY))
        )
    }
    
    @available(*, deprecated, renamed: "location(at:)")
    func relative(position: CGPoint) -> CGPoint {
        location(at: position)
    }
    /// Converts from content space to screen space
    func location(at position: CGPoint) -> CGPoint {
        CCanvasCoordinate.rotate(position, by: angle) * scale + offset
    }
    
    func scaleRotate(_ vector: CGVector) -> CGVector {
        (CCanvasCoordinate.rotate(vector.asPoint, by: -angle) / scale).asVector
    }
}

public extension CCanvasCoordinate {
    static func rotate(_ point: CGPoint, by rotation: Angle) -> CGPoint {
        var angle: Angle = Angle(radians: Double(atan2(point.y, point.x)))
        angle += rotation
        let radius: CGFloat = sqrt(pow(point.x, 2.0) + pow(point.y, 2.0))
        return CGPoint(x: cos(CGFloat(angle.radians)) * radius,
                       y: sin(CGFloat(angle.radians)) * radius)
    }
    static func direction(angle: Angle) -> CGPoint {
        CGPoint(x: cos(CGFloat(angle.radians)),
                y: sin(CGFloat(angle.radians)))
    }
    static func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        sqrt(pow(b.x - a.x, 2.0) + pow(b.y - a.y, 2.0))
    }
    static func angle(from a: CGPoint, to b: CGPoint) -> Angle {
        Angle(radians: Double(atan2(b.y - a.y, b.x - a.x)))
    }
}

extension CCanvasCoordinate {
    
    public static func lerp(from leadingCoordinate: CCanvasCoordinate,
                            to trailingCoordinate: CCanvasCoordinate,
                            at fraction: CGFloat) -> CCanvasCoordinate {
        
        CCanvasCoordinate(offset: leadingCoordinate.offset * (1.0 - fraction) + trailingCoordinate.offset * fraction,
                          scale: leadingCoordinate.scale * (1.0 - fraction) + trailingCoordinate.scale * fraction,
                          angle: Angle(radians: leadingCoordinate.angle.radians * (1.0 - fraction) + trailingCoordinate.angle.radians * fraction))
    }
}

public extension CCanvasCoordinate {
    static let zero: CCanvasCoordinate = CCanvasCoordinate(offset: .zero, scale: 1.0, angle: .zero)
}

public extension View {
    func canvasCoordinateRotationOffset(_ canvasCoordinate: CCanvasCoordinate) -> some View {
        self.rotationEffect(canvasCoordinate.angle, anchor: .topLeading)
            .offset(x: canvasCoordinate.offset.x,
                    y: canvasCoordinate.offset.y)
    }
}
