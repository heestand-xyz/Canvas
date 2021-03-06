import CoreGraphics
import CoreGraphicsExtensions
import SwiftUI

public struct CanvasCoordinate {
    public let offset: CGPoint
    public let scale: CGFloat
    public let angle: Angle
    public init(offset: CGPoint, scale: CGFloat, angle: Angle) {
        self.offset = offset
        self.scale = scale
        self.angle = angle
    }
}

public extension CanvasCoordinate {
    var rotatedOffset: CGPoint {
        CanvasCoordinate.rotate(offset, by: -angle)
    }
}

public extension CanvasCoordinate {
    /// Converts from screen space to content space
    func absolute(location: CGPoint) -> CGPoint {
        CanvasCoordinate.rotate((location - offset) / scale, by: -angle)
    }
    /// Converts from content space to screen space
    func relative(position: CGPoint) -> CGPoint {
        CanvasCoordinate.rotate(position, by: angle) * scale + offset
    }
    func scaleRotate(_ vector: CGVector) -> CGVector {
        (CanvasCoordinate.rotate(vector.point, by: -angle) / scale).vector
    }
}

public extension CanvasCoordinate {
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
    #warning("flip a & b angle")
    static func angle(from a: CGPoint, to b: CGPoint) -> Angle {
        Angle(radians: Double(atan2(a.y - b.y, a.x - b.x)))
    }
}

public extension CanvasCoordinate {
    static let zero: CanvasCoordinate = CanvasCoordinate(offset: .zero, scale: 1.0, angle: .zero)
}

public extension View {
    func canvasCoordinateRotationOffset(_ canvasCoordinate: CanvasCoordinate) -> some View {
        self.rotationEffect(canvasCoordinate.angle, anchor: .topLeading)
            .offset(x: canvasCoordinate.offset.x,
                    y: canvasCoordinate.offset.y)
    }
}
