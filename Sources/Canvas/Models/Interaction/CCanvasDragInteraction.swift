import Foundation
import CoreGraphics

public struct CCanvasDrag: Hashable, Equatable {
    
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
                    return 0.96
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
    
    let snapGrid: CCanvasSnapGrid?
    
    public init(id: UUID, physics: Physics, snapGrid: CCanvasSnapGrid?) {
        self.id = id
        self.physics = physics
        self.snapGrid = snapGrid
    }
    
    public static func == (lhs: CCanvasDrag, rhs: CCanvasDrag) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(physics)
        hasher.combine(snapGrid)
    }
}

class CCanvasDragInteraction {
    let drag: CCanvasDrag
    let interaction: CCanvasInteraction
    init(drag: CCanvasDrag, interaction: CCanvasInteraction) {
        self.drag = drag
        self.interaction = interaction
        if case .active(let force) = drag.physics {
            interaction.velocityDampening = force.velocityDampening
        }
    }
}

extension CCanvasDragInteraction: Equatable {
    static func == (lhs: CCanvasDragInteraction, rhs: CCanvasDragInteraction) -> Bool {
        lhs.drag.id == rhs.drag.id && lhs.interaction.id == rhs.interaction.id
    }
}

extension CCanvasDragInteraction: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(drag.id)
        hasher.combine(interaction.id)
    }
}
