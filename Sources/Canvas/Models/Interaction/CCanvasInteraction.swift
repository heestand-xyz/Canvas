import Foundation
import CoreGraphics
#if !os(macOS)
import UIKit
#endif
import SwiftUI
import MultiViews

public struct CCanvasInteractionInfo {
    public let view: MPView
    #if os(macOS)
    public let event: NSEvent
    public enum MouseButton {
        case left
        case right
        case middle
    }
    public let mouseButton: MouseButton
    #endif
}

public class CCanvasInteraction: Identifiable {
    
    public let id: UUID
    
    let startTime: Date
    var duration: TimeInterval {
        startTime.distance(to: Date())
    }
    
    let startLocation: CGPoint
    var location: CGPoint {
        didSet {
            refreshTimeout()
        }
    }
    var lastLocation: CGPoint {
        CGPoint(x: location.x - velocity.dx,
                y: location.y - velocity.dy)
    }
    var distance: CGFloat {
        sqrt(pow(location.x - startLocation.x, 2.0) + pow(location.y - startLocation.y, 2.0))
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

    #if !os(macOS)
    var touch: UITouch?
    #endif
    
    let info: CCanvasInteractionInfo
    
    private static let timeoutDuration: Double = 10.0
    var timeout: Bool = false
    private var timeoutTimer: Timer?
    
    var velocityDampening: CGFloat?
    
//    var pickedUpByOther: Bool = false
    
    init(id: UUID,
         location: CGPoint,
         info: CCanvasInteractionInfo) {
        self.id = id
        startTime = Date()
        self.startLocation = location
        self.location = location
        self.velocity = CGVector(dx: 0.0, dy: 0.0)
        self.active = true
        self.auto = false
        self.info = info
        refreshTimeout()
    }
    
    private func refreshTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer(timeInterval: CCanvasInteraction.timeoutDuration, repeats: false, block: { [weak self] _ in
            self?.timeout = true
            self?.timeoutTimer = nil
        })
        RunLoop.current.add(timeoutTimer!, forMode: .common)
    }
    
}

extension CCanvasInteraction: Equatable {
    public static func == (lhs: CCanvasInteraction, rhs: CCanvasInteraction) -> Bool {
        lhs.id == rhs.id
    }
}

extension CCanvasInteraction: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
