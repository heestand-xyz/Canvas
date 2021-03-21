import SwiftUI

public struct CanvasView: View {
    
    @ObservedObject var canvas: Canvas
    
    public init(canvas: Canvas) {
        self.canvas = canvas
    }
    
    public var body: some View {
        
        ZStack(alignment: .topLeading) {
            
            // Touches
            #if DEBUG
            ForEach(Array(canvas.interactions)) { interaction in
                Circle()
                    .foregroundColor((interaction == canvas.panInteraction) ? .blue :
                                        (interaction == canvas.pinchInteraction?.0 ||
                                            interaction == canvas.pinchInteraction?.1) ? .purple :
                                        canvas.dragInteractions.contains(where: { $0.interaction == interaction }) ? .orange : .primary)
                    .opacity(interaction.active ? 1.0 : 0.25)
                    .frame(width: 50, height: 50)
                    .offset(x: interaction.location.x - 25,
                            y: interaction.location.y - 25)
            }
            #endif
            
            // Interact
            CanvasInteractViewRepresentable(canvas: canvas)
            
        }
        
    }
    
}
