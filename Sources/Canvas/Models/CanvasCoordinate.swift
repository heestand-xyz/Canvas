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
        var angle: Angle = Angle(radians: Double(atan2(offset.y, offset.x)))
        angle -= self.angle
        let radius: CGFloat = sqrt(pow(offset.x, 2.0) + pow(offset.y, 2.0))
        return CGPoint(x: cos(CGFloat(angle.radians)) * radius,
                       y: sin(CGFloat(angle.radians)) * radius)
    }
}

public extension CanvasCoordinate {
    /// Converts from screen space to content space
    func absolute(location: CGPoint) -> CGPoint {
        (rotatedOffset + location) * scale
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
