import Foundation
import CoreGraphics
#if os(iOS)
import UIKit
#endif

class CanvasInteraction: Identifiable, Equatable {
    
    let id: UUID
    
    var location: CGPoint
    var lastLocation: CGPoint {
        CGPoint(x: location.x - velocity.dx,
                y: location.y - velocity.dy)
    }

    var velocity: CGVector
    var velocityRadius: CGFloat {
        sqrt(pow(velocity.dx, 2.0) + pow(velocity.dy, 2.0))
    }


    var active: Bool
    var auto: Bool

    #if os(iOS)
    var touch: UITouch?
    #endif
    
    init(id: UUID,
         location: CGPoint) {
        self.id = id
        self.location = location
        self.velocity = CGVector(dx: 0.0, dy: 0.0)
        self.active = true
        self.auto = false
    }
    
    static func == (lhs: CanvasInteraction, rhs: CanvasInteraction) -> Bool {
        lhs.id == rhs.id
    }
    
}
