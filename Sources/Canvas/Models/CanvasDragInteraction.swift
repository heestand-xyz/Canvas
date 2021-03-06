import Foundation

public struct CanvasDrag {
    public let id: UUID
    let physics: Bool
    let snapGrid: CanvasSnapGrid?
    public init(id: UUID, physics: Bool, snapGrid: CanvasSnapGrid?) {
        self.id = id
        self.physics = physics
        self.snapGrid = snapGrid
    }
}

class CanvasDragInteraction {
    let drag: CanvasDrag
    let interaction: CanvasInteraction
    init(drag: CanvasDrag, interaction: CanvasInteraction) {
        self.drag = drag
        self.interaction = interaction
    }
}

extension CanvasDragInteraction: Equatable {
    static func == (lhs: CanvasDragInteraction, rhs: CanvasDragInteraction) -> Bool {
        lhs.drag.id == rhs.drag.id
    }
}

extension CanvasDragInteraction: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(drag.id)
        hasher.combine(interaction.id)
    }
}
