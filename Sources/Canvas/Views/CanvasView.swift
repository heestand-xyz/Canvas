import SwiftUI

public struct CanvasView: View {
    
    @ObservedObject var canvas: Canvas
    
    public init(canvas: Canvas) {
        self.canvas = canvas
    }
    
    public var body: some View {
        
        ZStack(alignment: .topLeading) {
            
            // Touches
//            #if DEBUG
//            ForEach(canvasInteractions) { interaction in
//                Circle()
//                    .foregroundColor((interaction == canvasPanInteraction) ? .blue :
//                                        (interaction == canvasPinchInteraction?.0 ||
//                                            interaction == canvasPinchInteraction?.1) ? .purple :
//                                        canvasDragInteractions.contains(where: { $0.value == interaction }) ? .orange : .primary)
//                    .opacity(interaction.active ? 1.0 : 0.25)
//                    .frame(width: 50, height: 50)
//                    .offset(x: interaction.location.x - 25,
//                            y: interaction.location.y - 25)
//            }
//            #endif
            
            // Interact
            CanvasInteractViewRepresentable(canvas: canvas)
            
        }
        
    }
    
}
