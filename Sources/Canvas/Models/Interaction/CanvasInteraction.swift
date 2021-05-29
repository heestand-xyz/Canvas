import Foundation
import CoreGraphics
#if os(iOS)
import UIKit
#endif
import SwiftUI
import MultiViews

public struct CanvasInteractionInfo {
    public let view: MPView
    #if os(macOS)
    public let event: NSEvent
    /// Right mouse click.
    public let isAlternative: Bool
    #else
    public let isAlternative: Bool = false
    #endif
}

class CanvasInteraction: Identifiable {
    
    let id: UUID
    
    var location: CGPoint {
        didSet {
            refreshTimeout()
        }
    }
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
    
    let info: CanvasInteractionInfo
    
    private static let timeoutDuration: Double = 10.0
    var timeout: Bool = false
    private var timeoutTimer: Timer?
    
    var velocityDampening: CGFloat?
    
//    var pickedUpByOther: Bool = false
    
    init(id: UUID,
         location: CGPoint,
         info: CanvasInteractionInfo) {
        self.id = id
        self.location = location
        self.velocity = CGVector(dx: 0.0, dy: 0.0)
        self.active = true
        self.auto = false
        self.info = info
        refreshTimeout()
    }
    
    private func refreshTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer(timeInterval: CanvasInteraction.timeoutDuration, repeats: false, block: { [weak self] _ in
            self?.timeout = true
            self?.timeoutTimer = nil
        })
        RunLoop.current.add(timeoutTimer!, forMode: .common)
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
