import Foundation
import CoreGraphics

public struct CanvasDrag: Hashable, Equatable {
    
    public let id: UUID
    
    public enum Physics: Hashable {
        case inactive
        public enum Force: Hashable {
            case standard
            case heavy
            var velocityDampening: CGFloat {
                switch self {
                case .standard:
                    return 0.98
                case .heavy:
                    return 0.95
                }
            }
        }
        case active(Force)
        var hasForce: Bool {
            switch self {
            case .active:
                return true
            default:
                return false
            }
        }
    }
    let physics: Physics
    
    let snapGrid: CanvasSnapGrid?
    
    public init(id: UUID, physics: Physics, snapGrid: CanvasSnapGrid?) {
        self.id = id
        self.physics = physics
        self.snapGrid = snapGrid
    }
    
    public static func == (lhs: CanvasDrag, rhs: CanvasDrag) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(physics)
        hasher.combine(snapGrid)
    }
}

class CanvasDragInteraction {
    let drag: CanvasDrag
    let interaction: CanvasInteraction
    init(drag: CanvasDrag, interaction: CanvasInteraction) {
        self.drag = drag
        self.interaction = interaction
        if case .active(let force) = drag.physics {
            interaction.velocityDampening = force.velocityDampening
        }
    }
}

extension CanvasDragInteraction: Equatable {
    static func == (lhs: CanvasDragInteraction, rhs: CanvasDragInteraction) -> Bool {
        lhs.drag.id == rhs.drag.id && lhs.interaction.id == rhs.interaction.id
    }
}

extension CanvasDragInteraction: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(drag.id)
        hasher.combine(interaction.id)
    }
}
