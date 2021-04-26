import Foundation
import CoreGraphics
#if os(iOS)
import UIKit
#endif
import SwiftUI

class CanvasInteraction: Identifiable {
    
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
    
    var predictedEndLocation: CGPoint?
    
    /// absolute content space
    var contentCenterOffset: CGVector?
    
    var initialRotation: Angle = .zero
    var initialRotationThresholdReached: Bool = false

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
    
}

extension CanvasInteraction: Equatable {
    static func == (lhs: CanvasInteraction, rhs: CanvasInteraction) -> Bool {
        lhs.id == rhs.id
    }
}

extension CanvasInteraction: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
