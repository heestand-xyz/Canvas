import SwiftUI
import MultiViews

class CanvasInteractView: MPView {
    
    @Binding var canvasInteractions: [CanvasInteraction]

    init(canvasInteractions: Binding<[CanvasInteraction]>) {
        _canvasInteractions = canvasInteractions
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = UUID()
            let location: CGPoint = touch.location(in: self)
            let canvasInteraction = CanvasInteraction(id: id,
                                                      location: location,
                                                      velocity: CGVector(dx: 0.0, dy: 0.0),
                                                      active: true,
                                                      touch: touch)
            canvasInteractions.append(canvasInteraction)
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let index: Int = canvasInteractions.firstIndex(where: { canvasInteraction in
                canvasInteraction.touch == touch
            }) else { continue }
            let lastLocation: CGPoint = canvasInteractions[index].location
            let location: CGPoint = touch.location(in: self)
            canvasInteractions[index].location = location
            let velocity: CGVector = CGVector(dx: location.x - lastLocation.x,
                                              dy: location.y - lastLocation.y)
            canvasInteractions[index].velocity = velocity
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let index: Int = canvasInteractions.firstIndex(where: { canvasInteraction in
                canvasInteraction.touch == touch
            }) else { continue }
            canvasInteractions[index].active = false
        }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let index: Int = canvasInteractions.firstIndex(where: { canvasInteraction in
                canvasInteraction.touch == touch
            }) else { continue }
            canvasInteractions[index].active = false
        }
    }
    #endif
    
}
