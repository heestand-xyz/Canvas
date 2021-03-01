import Foundation
import CoreGraphics
#if os(iOS)
import UIKit
#endif

struct CanvasInteraction {
    let id: UUID
    var location: CGPoint
    var velocity: CGVector
    var velocityRadius: CGFloat {
        sqrt(pow(velocity.dx, 2.0) + pow(velocity.dy, 2.0))
    }
    var active: Bool
    #if os(iOS)
    let touch: UITouch
    #endif
}
