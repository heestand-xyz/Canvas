import CoreGraphics
import CoreGraphicsExtensions
import SwiftUI

public struct CanvasCoordinate {
    public let offset: CGPoint
    public let scale: CGFloat
    public let angle: Angle
}

public extension CanvasCoordinate {
    var scaledOffset: CGPoint {
        offset * scale
    }
}

public extension CanvasCoordinate {
    static let zero: CanvasCoordinate = CanvasCoordinate(offset: .zero, scale: 1.0, angle: .zero)
}

public extension View {
    func canvasCoordinateRotationOffset(_ canvasCoordinate: CanvasCoordinate) -> some View {
        self.rotationEffect(canvasCoordinate.angle)
            .offset(x: canvasCoordinate.offset.x,
                    y: canvasCoordinate.offset.y)
    }
}
