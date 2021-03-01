import Foundation
import CoreGraphics
#if os(iOS)
import UIKit
#endif

class CanvasInteraction: Identifiable, Equatable {
    
    let id: UUID
    
    var location: CGPoint
    var velocity: CGVector
    var velocityRadius: CGFloat {
        sqrt(pow(velocity.dx, 2.0) + pow(velocity.dy, 2.0))
    }

    var active: Bool
    
    #if os(iOS)
    var touch: UITouch?
    #endif
    
    init(id: UUID,
         location: CGPoint) {
        self.id = id
        self.location = location
        self.velocity = CGVector(dx: 0.0, dy: 0.0)
        self.active = true
    }
    
    static func == (lhs: CanvasInteraction, rhs: CanvasInteraction) -> Bool {
        lhs.id == rhs.id
    }
    
}
