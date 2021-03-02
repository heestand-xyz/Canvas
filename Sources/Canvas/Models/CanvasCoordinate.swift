import CoreGraphics
import CoreGraphicsExtensions
import SwiftUI

public struct CanvasCoordinate {
    public let offset: CGPoint
    public let scale: CGFloat
    public let angle: Angle
}

public extension CanvasCoordinate {
    var rotatedOffset: CGPoint {
        rotate(offset, by: -angle)
    }
}

public extension CanvasCoordinate {
    /// Converts from screen space to content space
    func absolute(location: CGPoint) -> CGPoint {
        rotate((location - offset) / scale, by: -angle)
    }
    /// Converts from content space to screen space
    func relative(position: CGPoint) -> CGPoint {
        rotate(position, by: angle) * scale + offset
    }
    func scaleRotate(_ location: CGPoint) -> CGPoint {
        rotate(location, by: -angle) / scale
    }
}

public extension CanvasCoordinate {
    func rotate(_ point: CGPoint, by rotation: Angle) -> CGPoint {
        var angle: Angle = Angle(radians: Double(atan2(point.y, point.x)))
        angle += rotation
        let radius: CGFloat = sqrt(pow(point.x, 2.0) + pow(point.y, 2.0))
        return CGPoint(x: cos(CGFloat(angle.radians)) * radius,
                       y: sin(CGFloat(angle.radians)) * radius)
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
